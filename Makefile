.PHONY: help
help:
	@echo "make [TARGETS...]"
	@echo
	@echo "This is the makefile of osbuild-getting-started. The following"
	@echo "targets are available:"
	@echo
	@echo "  service-containers:      Build all needed containers from source to be able to run the service"
	@echo "  run-service:             Run all containers needed for the 'service'"
	@echo "                           This is running in foreground. Use CTRL-C to stop the containers."
	@echo "  run-service-no-frontend: Run all containers except for the frontend"
	@echo "  stop-service:            Usually the containers get stopped by CTRL-C. So 'stop-service'"
	@echo "                           is only needed if something strange happened and not all are stopped."
	@echo "  prune-service:           Remove the containers, including the test-data!"
	@echo "                           If you want empty databases"
	@echo "  clean:                   Clean all subprojects to assure a rebuild"

# source where the other repos are locally
# has to end with a trailing slash
SRC_DEPS_EXTERNAL_CHECKOUT_DIR ?= ../

# either "docker" or "sudo podman"
# podman needs to build as root as it also needs to run as root afterwards
CONTAINER_EXECUTABLE ?= docker
CONTAINER_COMPOSE_EXECUTABLE := $(CONTAINER_EXECUTABLE) compose

MAKE_SUB_CALL := make CONTAINER_EXECUTABLE="$(CONTAINER_EXECUTABLE)"

# osbuild is indirectly used by osbuild-composer
# but we'll mention it here too for better error messages and usability
COMMON_SRC_DEPS_NAMES := osbuild osbuild-composer pulp-client community-gateway
COMMON_SRC_DEPS_ORIGIN := $(addprefix $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR),$(COMMON_SRC_DEPS_NAMES))

ONPREM_SRC_DEPS_NAMES := weldr-client
ONPREM_SRC_DEPS_ORIGIN := $(addprefix $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR),$(ONPREM_SRC_DEPS_NAMES))

SERVICE_SRC_DEPS_NAMES := image-builder image-builder-frontend
SERVICE_SRC_DEPS_ORIGIN := $(addprefix $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR),$(SERVICE_SRC_DEPS_NAMES))

# should be set if we are already sudo - otherwise we set to "whoami"
SUDO_USER ?= $(shell whoami)

$(COMMON_SRC_DEPS_ORIGIN) $(SERVICE_SRC_DEPS_ORIGIN) $(ONPREM_SRC_DEPS_ORIGIN):
	@for DIR in $@; do if ! [ -d $$DIR ]; then echo "Please checkout $$DIR so it is available at $$DIR"; exit 1; fi; done

COMPARE_TO_BRANCH ?= origin/main

SCRATCH_DIR := /scratch/
COMMON_DIR := podman/image-builder-config
CLI_DIRS := podman/weldr podman/cloudapi podman/dnf-json
DATA_DIR := data/s3
ALL_SCRATCH_DIRS := $(addprefix $(SCRATCH_DIR),$(COMMON_DIR) $(CLI_DIRS) $(DATA_DIR))

# internal rule for sub-calls
# NOTE: This chowns all directories back - as we expect to run partly as root
# also we "git fetch origin" to get the current state!
.PHONY: common_sub_makes
common_sub_makes:
	@echo "We need to build everything as root, as the target also needs to run as root."
	@echo "At least for podman the password as already needed now"

	# creating container image from osbuild as a basis for worker
	$(MAKE_SUB_CALL) -C $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)osbuild-composer container_worker container_composer

.PHONY: service_sub_makes
service_sub_makes:
	# building the backend
	$(MAKE_SUB_CALL) -C $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)image-builder container
	# building the frontend
	$(MAKE_SUB_CALL) -C $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)image-builder-frontend container
	@for DIR in $(COMMON_SRC_DEPS_ORIGIN) $(SERVICE_SRC_DEPS_ORIGIN); do echo "Giving directory permissions in '$$DIR' back to '$(SUDO_USER)'"; sudo chown -R $(SUDO_USER): $$DIR; done
	@echo "Your current versions are (comparing to origin/main):"
	./git_stack.sh

.PHONY: onprem_sub_makes
onprem_sub_makes:
	# building the cli
	$(MAKE_SUB_CALL) -C $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)weldr-client container
	@for DIR in $(COMMON_SRC_DEPS_ORIGIN) $(ONPREM_SRC_DEPS_ORIGIN); do echo "Giving directory permissions in '$$DIR' back to '$(SUDO_USER)'"; sudo chown -R $(SUDO_USER): $$DIR; done
	@echo "Your current versions are (comparing to origin/main):"
	./git_stack.sh

.PHONY: service-containers
service-containers: $(COMMON_SRC_DEPS_ORIGIN) $(SERVICE_SRC_DEPS_ORIGIN) common_sub_makes service_sub_makes service_images_built.info

on-prem-containers: $(COMMON_SRC_DEPS_ORIGIN) $(ONPREM_SRC_DEPS_ORIGIN) common_sub_makes onprem_sub_makes onprem_images_built.info

service_images_built.info: service/config/Dockerfile-config service/config/composer/osbuild-composer.toml $(ALL_SCRATCH_DIRS)
	# building remaining containers (config, fauxauth)
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose.yml build --build-arg CONFIG_BUILD_DATE=$(shell date -r $(SCRATCH_DIR)$(COMMON_DIR) +%Y%m%d_%H%M%S)
	echo "Images last built on" > $@
	date >> $@

onprem_images_built.info: service/config/Dockerfile-config-onprem service/config/composer/osbuild-composer-onprem.toml $(ALL_SCRATCH_DIRS)
	# building remaining containers (config)
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose-onprem.yml build --build-arg CONFIG_BUILD_DATE=$(shell date -r $(SCRATCH_DIR)$(COMMON_DIR) +%Y%m%d_%H%M%S)
	echo "Images last built on" > $@
	date >> $@

$(ALL_SCRATCH_DIRS):
	@echo "Creating directory: $@"
	mkdir -p $@

.PHONY: wipe-config
wipe-config:
	rm -rf $(SCRATCH_DIR)$(COMMON_DIR)
	rm -f $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)image-builder-frontend/node_modules/.cache/webpack-dev-server/server.pem

.PHONY: clean
clean: $(COMMON_SRC_DEPS_ORIGIN) $(SERVICE_SRC_DEPS_ORIGIN) $(ONPREM_SRC_DEPS_ORIGIN) wipe-config
	rm -f service_images_built.info
	rm -f onprem_images_built.info
	rm -f vm_image_built.info
	rm -f vm_defined.info
	for DIR in $*; do $(MAKE_SUB_CALL) -C $$DIR clean; done
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose.yml rm
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose-onprem.yml rm

# for compatibility of relative volume mount paths
# between docker and podman we have to change to the directory
.PHONY: run-service
.ONESHELL:
run-service: $(addprefix $(SCRATCH_DIR),$(COMMON_DIRS)) service-containers
	pushd service
	$(CONTAINER_COMPOSE_EXECUTABLE) up
	popd

# only for strange crashes - should shut down properly in normal operation
.PHONY: stop-service
.ONESHELL:
stop-service:
	pushd service
	$(CONTAINER_COMPOSE_EXECUTABLE) stop
	popd

.PHONY: prune-service
.ONESHELL:
prune-service:
	pushd service
	$(CONTAINER_COMPOSE_EXECUTABLE) down
	popd

# if you want to run the frontend yourself - outside the docker environment
.PHONY: run-service
run-service-no-frontend: service-containers
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose.yml up backend fauxauth worker composer minio postgres_backend postgres_composer

# for compatibility of relative volume mount paths
# between docker and podman we have to change to the directory
.PHONY: run-onprem
.ONESHELL:
run-onprem: $(addprefix $(SCRATCH_DIR),$(COMMON_DIRS) $(CLI_DIRS)) on-prem-containers
	pushd service
	rm -f $(addprefix $(SCRATCH_DIR), weldr/api.socket cloudapi/api.socket dnf-json/api.sock)
	$(CONTAINER_COMPOSE_EXECUTABLE) -f docker-compose-onprem.yml up -d
	@echo "------ Welcome to osbuild! You can now use 'composer-cli' to build images"
	@echo "       … and 'exit' afterwards"
	@echo "       You might also be interested to open up a second terminal and"
	@echo "       run 'docker compose logs --follow' to see possible problems"

	$(CONTAINER_COMPOSE_EXECUTABLE) -f docker-compose-onprem.yml run --entrypoint /bin/bash -ti cli
	$(CONTAINER_COMPOSE_EXECUTABLE) -f docker-compose-onprem.yml stop
	popd

docs/src_compile.svg: docs/src_compile.dot
	dot -T svg $< > $@

.PHONY: docs
docs: docs/src_compile.svg

.PHONY: overview
overview:
	@echo "Fetching all repos for better overview if rebase will be necessary:"
ifeq (${SUDO_USER},$(shell whoami))
	./git_stack.sh fetch --all
else
	sudo -u ${SUDO_USER} ./git_stack.sh fetch --all
endif
	@./git_stack.sh


BLUEPRINT = osbuild-getting-started-fedora39.toml
# patch the BLUEPRINT with the current user ID
# we need this because the user in the VM directly writes to
# the mapped source directory
$(BLUEPRINT): $(BLUEPRINT:.toml=.toml.template)
	cp $< $@
	sed -i -E "s|(uid *= *)(.+)|\1$$(id -u)|g" $@
	sed -i -E "s|(gid *= *)(.+)|\1$$(id -g)|g" $@

.ONESHELL:
.SILENT:
vm_image_built.info: $(BLUEPRINT) osbuild-getting-started-fedora39.xml.template
	echo "Pushing blueprint '$(BLUEPRINT)' to composer to create a virtual machine for development"
	composer-cli blueprints push $(BLUEPRINT)
	# start building
	export COMPOSE_ID="$$(composer-cli compose start osbuild-getting-started-fedora-39 qcow2|awk 'NR==1 {print $$2}')"

	echo "Compose id: $${COMPOSE_ID} started"
	echo "Waiting for osbuild to create our virtual machine"
	sleep 2
	while true; do \
	    export STATUS="$$(composer-cli compose info $${COMPOSE_ID}| awk 'NR==1 {print $$2}')" ; \
	    if [[ "$$STATUS" != "RUNNING" && "$$STATUS" != "WAITING" ]]; then echo " $$STATUS"; break; fi; \
		echo -n "."; sleep 1; \
	done ;

	echo "Getting qcow2 image"
	composer-cli compose image "$${COMPOSE_ID}"

	echo "$${COMPOSE_ID}" > $@

VM_XML = osbuild-getting-started-fedora39.xml
$(VM_XML): $(VM_XML:.xml=.xml.template) vm_image_built.info
	cp $< $@
	sed -i -E "s|REPLACEME_QCOW2|$$(pwd)/$$(cat vm_image_built.info)-disk.qcow2|" osbuild-getting-started-fedora39.xml
	sed -i -E "s|REPLACEME_HOST_DATA|$$(readlink -f ..)|" osbuild-getting-started-fedora39.xml
	sed -i -E "s|REPLACEME_HOST_GO_CACHE|$$(readlink -f $${GOPATH:-$$HOME/go})|" osbuild-getting-started-fedora39.xml

.ONESHELL:
.SILENT:
vm_defined.info: $(VM_XML)
	echo "Using 'virsh' as root to define the virtual machine"
	-sudo virsh destroy osbuild-getting-started-fedora39
	-sudo virsh undefine osbuild-getting-started-fedora39
	sudo virsh define osbuild-getting-started-fedora39.xml

	echo "VM last defined on" > $@
	date >> $@

.PHONY: start-vm
.ONESHELL:
start-vm: vm_defined.info
	@echo "Starting the virtual machine"
	sudo virsh start osbuild-getting-started-fedora39
	export MAC=$$(awk -F '"' '/mac address/{print $$2}' osbuild-getting-started-fedora39.xml)
	export IP="$$(sudo virsh net-dhcp-leases default | awk "/$$MAC/ {split(\$$5, a, \"/\"); print a[1]}")"
	@echo -e "\nYou can now login with:"
	@echo "ssh -o \"UserKnownHostsFile=/dev/null\" -o \"StrictHostKeyChecking=no\" -o \"LogLevel=ERROR\" osbuild@$$IP"

.PHONY: stop-vm
.ONESHELL:
stop-vm:
	sudo virsh destroy osbuild-getting-started-fedora39

.PHONY: recompile
.ONESHELL:
recompile:
	export MAC=$$(awk -F '"' '/mac address/{print $$2}' osbuild-getting-started-fedora39.xml)
	export IP="$$(sudo virsh net-dhcp-leases default | awk "/$$MAC/ {split(\$$5, a, \"/\"); print a[1]}")"
	export CMD="ssh -o \"UserKnownHostsFile=/dev/null\" -o \"StrictHostKeyChecking=no\" -o \"LogLevel=ERROR\" osbuild@$$IP"
	echo "Installing osbuild"
	bash -c "$$CMD 'cd /workspaces/osbuild ; make rpm-devel'"
	bash -c "$$CMD 'sudo rpm -i /workspaces/osbuild/rpmbuild/RPMS/*.rpm' || echo 'OK, already installed'"
