.PHONY: help
help:
	@echo "make [TARGETS...]"
	@echo
	@echo "This is the makefile of osbuild-getting-started. The following"
	@echo "targets are available:"
	@echo
	@echo "  service_containers:      Build all needed containers from source to be able to run the service"
	@echo "  run_service:             Run all containers needed for the 'service'"
	@echo "                           This is running in foreground. Use CTRL-C to stop the containers."
	@echo "  run_service_no_frontend: Run all containers except for the frontend"
	@echo "  stop_service:            Usually the containers get stopped by CTRL-C. So 'stop-service'"
	@echo "                           is only needed if something strange happened and not all are stopped."
	@echo "  prune_service:           Remove the containers, including the test-data!"
	@echo "                           If you want empty databases"
	@echo "  clean:                   Clean all subprojects to assure a rebuild"

MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
GETTING_STARTED_DIR := $(patsubst %/,%,$(dir $(MAKEFILE_PATH)))

# source where the other repos are locally
# has to end with a trailing slash
export SRC_DEPS_EXTERNAL_CHECKOUT_DIR ?= $(GETTING_STARTED_DIR)/..

# either "docker" or "sudo podman"
# podman needs to build as root as it also needs to run as root afterwards
export CONTAINER_EXECUTABLE ?= docker
export CONTAINER_COMPOSE_EXECUTABLE ?= $(CONTAINER_EXECUTABLE) compose

MAKE_SUB_CALL := make CONTAINER_EXECUTABLE="$(CONTAINER_EXECUTABLE)"

# osbuild is indirectly used by osbuild-composer
# but we'll mention it here too for better error messages and usability
COMMON_SRC_DEPS_NAMES := osbuild osbuild-composer pulp-client community-gateway
COMMON_SRC_DEPS_ORIGIN := $(addprefix $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)/,$(COMMON_SRC_DEPS_NAMES))

ONPREM_SRC_DEPS_NAMES := weldr-client
ONPREM_SRC_DEPS_ORIGIN := $(addprefix $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)/,$(ONPREM_SRC_DEPS_NAMES))

SERVICE_SRC_DEPS_NAMES := image-builder-crc image-builder-frontend
SERVICE_SRC_DEPS_ORIGIN := $(addprefix $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)/,$(SERVICE_SRC_DEPS_NAMES))

# should be set if we are already sudo - otherwise we set to "whoami"
SUDO_USER ?= $(shell whoami)

ALL_REQUIRED_DIRS := $(COMMON_SRC_DEPS_ORIGIN) $(SERVICE_SRC_DEPS_ORIGIN) $(ONPREM_SRC_DEPS_ORIGIN)

$(ALL_REQUIRED_DIRS):
	@if ! [ -d $@ ]; then \
		echo "Please checkout '$$(basename $@)' so it is available at $$(readlink -f $@)"; \
		echo "I expect a structure like this:"; \
		echo "  $$(readlink -f $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR))"; \
		TOTAL=$$(echo $(ALL_REQUIRED_DIRS) | wc -w); \
		COUNT=1; \
		for REPO in $(ALL_REQUIRED_DIRS); do \
			if [ $$COUNT -eq $$TOTAL ]; then \
				PREFIX="  └──"; \
			else \
				PREFIX="  ├──"; \
			fi; \
			echo "$$PREFIX $$(basename $$REPO)"; \
			COUNT=$$((COUNT + 1)); \
		done; \
		exit 1; \
	fi;

COMPARE_TO_BRANCH ?= origin/main

SCRATCH_DIR := $(HOME)/.cache/osbuild-getting-started/scratch
export SCRATCH_DIR
COMMON_DIR := image-builder-config
CLI_DIRS := weldr cloudapi dnf-json
DATA_DIR := data/s3/service
ALL_SCRATCH_DIRS := $(addprefix $(SCRATCH_DIR)/,$(COMMON_DIR) $(CLI_DIRS) $(DATA_DIR))

OSBUILD_DIR ?= $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)/osbuild
OSBUILD_COMPOSER_DIR ?= $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)/osbuild-composer
IMAGE_BUILDER_CRC_DIR ?= $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)/image-builder-crc
IMAGE_BUILDER_FRONTEND_DIR ?= $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)/image-builder-frontend

.PHONY: service_containers
service_containers: service_sub_make_backend
	make -C $(OSBUILD_DIR) -f $(GETTING_STARTED_DIR)/repos/osbuild/Makefile.getting-started container.dev
	make -C $(OSBUILD_COMPOSER_DIR) -f $(GETTING_STARTED_DIR)/repos/osbuild-composer/Makefile.getting-started container.dev

# internal rule for sub-calls
# NOTE: This chowns all directories back - as we expect to run partly as root
# also we "git fetch origin" to get the current state!
.PHONY: common_sub_makes
common_sub_makes:
	@echo "We need to build everything as root, as the target also needs to run as root."
	@echo "At least for podman the password as already needed now"

	# creating container image from osbuild as a basis for worker
	make -C $(OSBUILD_COMPOSER_DIR) -f $(GETTING_STARTED_DIR)/repos/osbuild-composer/Makefile.getting-started container.dev

.PHONY: service_sub_make_backend
service_sub_make_backend:
	make -C $(OSBUILD_DIR) -f $(GETTING_STARTED_DIR)/repos/osbuild/Makefile.getting-started container.dev
	make -C $(OSBUILD_COMPOSER_DIR) -f $(GETTING_STARTED_DIR)/repos/osbuild-composer/Makefile.getting-started container.dev
	make -C $(IMAGE_BUILDER_CRC_DIR) -f $(GETTING_STARTED_DIR)/repos/image-builder-crc/Makefile.getting-started container.dev

.PHONY: service_sub_make_frontend
service_sub_make_frontend:
	make -C $(IMAGE_BUILDER_CRC_DIR) -f $(GETTING_STARTED_DIR)/repos/image-builder-frontend/Makefile.getting-started container.dev

.PHONY: service_sub_make_cleanup
service_sub_make_cleanup:
	@for DIR in $(COMMON_SRC_DEPS_ORIGIN) $(SERVICE_SRC_DEPS_ORIGIN); do echo "Giving directory permissions in '$$DIR' back to '$(SUDO_USER)'"; chown -R $(SUDO_USER): $$DIR || sudo chown -R $(SUDO_USER): $$DIR; done
	@echo "Your current versions are (comparing to origin/main):"
	bash -c './tools/git_stack.sh'

.PHONY: service_sub_makes_no_frontend
service_sub_makes_no_frontend: service_sub_make_backend service_sub_make_cleanup

.PHONY: service_sub_makes
service_sub_makes: service_sub_make_backend service_sub_make_frontend service_sub_make_cleanup

.PHONY: onprem_sub_makes
onprem_sub_makes:
	# building the cli
	$(MAKE_SUB_CALL) -C $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)/weldr-client container.dev
	@for DIR in $(COMMON_SRC_DEPS_ORIGIN) $(ONPREM_SRC_DEPS_ORIGIN); do echo "Giving directory permissions in '$$DIR' back to '$(SUDO_USER)'"; chown -R $(SUDO_USER): $$DIR || sudo chown -R $(SUDO_USER): $$DIR; done
	@echo "Your current versions are (comparing to origin/main):"
	bash -c './tools/git_stack.sh'

.PHONY: service_containers_old
service_containers_old: $(COMMON_SRC_DEPS_ORIGIN) $(SERVICE_SRC_DEPS_ORIGIN) common_sub_makes service_sub_makes service_images_built.info

.PHONY: service_containers_no_frontend
service_containers_no_frontend: $(COMMON_SRC_DEPS_ORIGIN) $(SERVICE_SRC_DEPS_ORIGIN) common_sub_makes service_sub_makes_no_frontend service_images_built.info

onprem_containers: $(COMMON_SRC_DEPS_ORIGIN) $(ONPREM_SRC_DEPS_ORIGIN) common_sub_makes onprem_sub_makes onprem_images_built.info

service_images_built.info: service/config/Dockerfile-config service/config/composer/osbuild-composer.toml $(ALL_SCRATCH_DIRS)
	# building remaining containers (config, fauxauth)
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose.yml build --build-arg CONFIG_BUILD_DATE=$(shell date -r $(SCRATCH_DIR)/$(COMMON_DIR) +%Y%m%d_%H%M%S)
	echo "Images last built on" > $@
	date >> $@

onprem_images_built.info: service/config/Dockerfile-config-onprem service/config/composer/osbuild-composer-onprem.toml $(ALL_SCRATCH_DIRS)
	# building remaining containers (config)
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose-onprem.yml build --build-arg CONFIG_BUILD_DATE=$(shell date -r $(SCRATCH_DIR)/$(COMMON_DIR) +%Y%m%d_%H%M%S)
	echo "Images last built on" > $@
	date >> $@

$(ALL_SCRATCH_DIRS):
	@echo "Creating directory: $@"
	mkdir -p $@ || ( echo "Trying as root" ; sudo mkdir -p $@ )

.PHONY: wipe_config
wipe_config:
	sudo rm -rf $(SCRATCH_DIR)/$(COMMON_DIR)
	rm -f $(SRC_DEPS_EXTERNAL_CHECKOUT_DIR)/image-builder-frontend/node_modules/.cache/webpack-dev-server/server.pem

.PHONY: clean
clean: prune_service prune_onprem wipe_config
	rm -f service_images_built.info
	rm -f onprem_images_built.info
	rm -rf $(SCRATCH_DIR) 2>/dev/null || (echo "Trying as root" ;sudo rm -rf $(SCRATCH_DIR))
	make -C $(OSBUILD_DIR) -f $(GETTING_STARTED_DIR)/repos/osbuild/Makefile.getting-started clean.dev
	make -C $(OSBUILD_COMPOSER_DIR) -f $(GETTING_STARTED_DIR)/repos/osbuild-composer/Makefile.getting-started clean.dev
	make -C $(IMAGE_BUILDER_CRC_DIR) -f $(GETTING_STARTED_DIR)/repos/image-builder-crc/Makefile.getting-started clean.dev

	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose.yml down --volumes
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose.yml rm --volumes
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose-onprem.yml down --volumes
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose-onprem.yml rm --volumes	

# for compatibility of relative volume mount paths
# between docker and podman we have to change to the directory
.PHONY: run_service
.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS := -ec -o pipefail

run_service: $(addprefix $(SCRATCH_DIR)/,$(COMMON_DIRS)) service_containers
	export PORTS="$(shell $(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose.yml config|grep -Po '(?<=published: ")[0-9]+')"
	echo "-- Checking if any of our ports are used: $$PORTS"
	sudo netstat -lntp|grep -E "$$(echo "$$PORTS"|tr ' ' ':')"
	echo "-- Check done"
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose.yml up

# if you want to run the frontend yourself - outside the docker environment
.PHONY: run_service_no_frontend
run_service_no_frontend: service_containers_no_frontend
	$(CONTAINER_COMPOSE_EXECUTABLE) -f service/docker-compose.yml up backend fauxauth worker composer minio postgres_image_builder_crc postgres_composer

# only for strange crashes - should shut down properly in normal operation
.PHONY: stop_service
.ONESHELL:
stop_service:
	cd service
	$(CONTAINER_COMPOSE_EXECUTABLE) stop

.PHONY: prune_service
.ONESHELL:
prune_service:
	cd service
	$(CONTAINER_COMPOSE_EXECUTABLE) down

.PHONY: prune_onprem
.ONESHELL:
prune_onprem:
	cd service
	$(CONTAINER_COMPOSE_EXECUTABLE) -f docker-compose-onprem.yml down

# for compatibility of relative volume mount paths
# between docker and podman we have to change to the directory
.PHONY: run_onprem
.ONESHELL:
run_onprem: $(addprefix $(SCRATCH_DIR)/,$(COMMON_DIRS) $(CLI_DIRS)) onprem_containers
	cd service
	echo "Remove dangling sockets as root"
	sudo rm -f $(addsuffix /api.sock*, $(addprefix $(SCRATCH_DIR)/, $(CLI_DIRS)))
	$(CONTAINER_COMPOSE_EXECUTABLE) -f docker-compose-onprem.yml up -d
	@echo "------ Welcome to osbuild! You can now use 'composer-cli' to build images"
	@echo "       … and 'exit' afterwards"
	@echo "       You might also be interested to open up a second terminal and"
	@echo "       run 'docker compose -f $(shell readlink -f service/docker-compose-onprem.yml) logs --follow' to see possible problems"

	$(CONTAINER_COMPOSE_EXECUTABLE) -f docker-compose-onprem.yml run --entrypoint /bin/bash -ti cli
	$(CONTAINER_COMPOSE_EXECUTABLE) -f docker-compose-onprem.yml stop

%.svg: %.dot
	dot -T svg $< > $@

.PHONY: docs
docs: docs/src_compile_service.svg docs/src_compile_onprem.svg

.PHONY: overview
overview:
	@echo "Fetching all repos for better overview if rebase will be necessary:"
ifeq (${SUDO_USER},$(shell whoami))
	bash -c './tools/git_stack.sh fetch --all'
else
	sudo -u ${SUDO_USER} bash -c './tools/git_stack.sh fetch --all'
endif
	@bash -c './tools/git_stack.sh'

