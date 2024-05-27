# This is the makefile for the `osbuild-getting-started` project, abbreviated
# as `ogsc`.
#
# It provides a quick (containerized) setup of the `osbuild` ecosystem.

PREFIX=ogsc
PREFIX_BUILD=$(PREFIX)/build
PREFIX_RUN=$(PREFIX)/run
PREFIX_GENERATE=$(PREFIX)/generate

osbuild_version=$(shell git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' https://github.com/osbuild/osbuild | tail -n1 | cut -d/ -f3 | cut -d^ -f1)
osbuild_composer_version=$(shell git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' https://github.com/osbuild/osbuild-composer | tail -n1 | cut -d/ -f3 | cut -d^ -f1)
weldr_client_version=$(shell git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' https://github.com/osbuild/weldr-client | tail -n1 | cut -d/ -f3 | cut -d^ -f1)

osbuild_version_x=$(shell echo $(osbuild_version) | sed -e s/v//g)
osbuild_composer_version_x=$(shell echo $(osbuild_composer_version) | sed -e s/v//g)
weldr_client_version_x=$(shell echo $(weldr_client_version) | sed -e s/v//g)

.PHONY: setup-host
setup-host: ## Install all necessary packages on the host system
	./bin/setup-host.py container

.PHONY: build/osbuild
build/osbuild: ## Build the container for building osbuild rpms
	@echo "Makefile: build/osbuild: creating $(PREFIX_BUILD)/osbuild:$(osbuild_version)"
	podman build \
		--build-arg osbuild_version=$(osbuild_version) \
		-t $(PREFIX_BUILD)/osbuild:$(osbuild_version) \
		src/ogsc/build/osbuild

.PHONY: rpms/osbuild
rpms/osbuild: build/osbuild ## Build the rpms for osbuild
	@echo "Makefile: rpms/osbuild: creating rpms for osbuild ${osbuild_version}"
	ls $(shell pwd)/build/rpms/osbuild-$(osbuild_version_x)-*.rpm > /dev/null || podman run \
		--rm \
		--volume $(shell pwd)/build/rpms/:/build/osbuild/rpmbuild/RPMS/noarch/:rw,Z \
		$(PREFIX_BUILD)/osbuild:$(osbuild_version) \
		make rpm

.PHONY: build/osbuild-composer
build/osbuild-composer: ## Build the container for building osbuild-composer rpms
	@echo "Makefile: build/osbuild-composer: creating $(PREFIX_BUILD)/osbuild-composer:$(osbuild_composer_version)"
	podman build \
		--build-arg osbuild_composer_version=$(osbuild_composer_version) \
		-t $(PREFIX_BUILD)/osbuild-composer:$(osbuild_composer_version) \
		src/ogsc/build/osbuild-composer

.PHONY: rpms/osbuild-composer
rpms/osbuild-composer: build/osbuild-composer ## Build the rpms for osbuild-composer
	@echo "Makefile: rpms/osbuild-composer: creating rpms for osbuild-composer ${osbuild_composer_version}"
	ls $(shell pwd)/build/rpms/osbuild-composer-$(osbuild_composer_version_x)-* > /dev/null || podman run \
		--rm \
		--volume $(shell pwd)/build/rpms/:/build/osbuild-composer/rpmbuild/RPMS/x86_64/:rw,Z \
		$(PREFIX_BUILD)/osbuild-composer:$(osbuild_composer_version) \
		make scratch

.PHONY: config/osbuild-composer
config/osbuild-composer: build/osbuild-composer ## Configure the osbuild-composer container (include test data, generate certs etc)
	podman run \
		--rm \
		--volume $(shell pwd)/build/rpms/:/build/osbuild-composer/rpmbuild/RPMS/x86_64/:rw,Z \
		--volume $(shell pwd)/build/config/:/build/config/:rw,Z \
		$(PREFIX_BUILD)/osbuild-composer:$(osbuild_composer_version) \
		bash -c './tools/gen-certs.sh ./test/data/x509/openssl.cnf /build/config /build/config/ca 2>&1 > /dev/null && \
		        cp ./test/data/composer/osbuild-composer*.toml /build/config && \
		        cp ./test/data/worker/osbuild-worker*.toml /build/config && \
		        cp -r ./repositories /build/config && \
		        cp /build/config/osbuild-composer-tls.toml /build/config/osbuild-composer.toml'

.PHONY: build/weldr-client
build/weldr-client: ## Build the container for building the weldr-client rpms
	@echo "Makefile: build/weldr-client: creating $(PREFIX_BUILD)/weldr-client:$(weldr_client_version)"
	podman build \
		--build-arg weldr_client_version=$(weldr_client_version) \
		-t $(PREFIX_BUILD)/weldr-client:$(weldr_client_version) \
		src/ogsc/build/weldr-client

.PHONY: rpms/weldr-client
rpms/weldr-client: build/weldr-client ## Build the rpms for weldr-client
	@echo "Makefile: rpms/weldr-client: creating rpms for weldr-client $(weldr_client_version)"
	ls $(shell pwd)/build/rpms/weldr-client-$(weldr_client_version_x)-* > /dev/null || podman run \
		--rm \
		--volume $(shell pwd)/build/rpms/:/build/weldr-client/rpmbuild/RPMS/x86_64/:rw,Z \
		$(PREFIX_BUILD)/weldr-client:$(weldr_client_version) \
		make scratch-rpm

.PHONY: run/composer
run/composer: # Launch the osbuild-composer container
	@echo "Makefile: run/composer: creating $(PREFIX_RUN)/composer:$(osbuild_composer_version)"
	podman build \
		--volume $(shell pwd)/build/rpms:/rpms:ro,Z \
		--build-arg osbuild_composer_version=${osbuild_composer_version_x} \
		--build-arg osbuild_version=${osbuild_version_x} \
		-t $(PREFIX_RUN)/composer:$(osbuild_composer_version) \
		src/ogsc/run/composer

.PHONY: run/worker
run/worker: ## Launch the worker container
	@echo "Makefile: run/worker: creating $(PREFIX_RUN)/worker:$(osbuild_composer_version)_$(osbuild_version)"
	podman build \
		--volume $(shell pwd)/build/rpms:/rpms:ro,Z \
		--build-arg osbuild_composer_version=${osbuild_composer_version_x} \
		--build-arg osbuild_version=${osbuild_version_x} \
		-t $(PREFIX_RUN)/worker:$(osbuild_composer_version)_$(osbuild_version) \
		src/ogsc/run/worker

.PHONY: run/cli
run/cli: ## Launch the weldr-client container
	@echo "Makefile: run/cli: creating $(PREFIX_RUN)/cli:$(weldr_client_version)"
	podman build \
		--volume $(shell pwd)/build/rpms:/rpms:ro,Z \
		--build-arg weldr_client_version=${weldr_client_version_x} \
		-t $(PREFIX_RUN)/cli:$(weldr_client_version) \
		src/ogsc/run/cli

.PHONY: quick
quick: rpms/osbuild rpms/osbuild-composer rpms/weldr-client config/osbuild-composer run/composer run/worker run/cli ## Like 'run', but quick!

.PHONY: run
run: config/osbuild-composer quick ## Launch the whole stack
	./bin/run.py ${osbuild_version} ${osbuild_composer_version} ${weldr_client_version}

.PHONY: clean
clean: ## Remove containers and rpms
	podman image ls "ogsc/build/osbuild" && podman image rm -f $(shell podman image ls "ogsc/build/osbuild" -q)
	podman image ls "ogsc/build/osbuild-composer" && podman image rm -f $(shell podman image ls "ogsc/build/osbuild-composer" -q)
	podman image ls "ogsc/build/weldr-client" && podman image rm -f $(shell podman image ls "ogsc/build/weldr-client" -q)
	podman image ls "ogsc/run/composer" && podman image rm -f $(shell podman image ls "ogsc/run/composer" -q)
	podman image ls "ogsc/run/worker" && podman image rm -f $(shell podman image ls "ogsc/run/worker" -q)
	podman image ls "ogsc/run/cli" && podman image rm -f $(shell podman image ls "ogsc/run/cli" -q)
	rm -f $(shell pwd)/build/rpms/*.rpm

.PHONY: help
help:
	@echo 'Usage:'
	@echo '  make <target>'
	@echo ''
	@echo 'Targets:'
	@awk 'match($$0, /^([a-zA-Z_\/-]+):.*?## (.*)$$/, m) {printf "  \033[36m%-30s\033[0m %s\n", m[1], m[2]}' $(MAKEFILE_LIST) | sort | grep -v "/"
	@awk 'match($$0, /^([a-zA-Z_\/-]+):.*?## (.*)$$/, m) {printf "  \033[36m%-30s\033[0m %s\n", m[1], m[2]}' $(MAKEFILE_LIST) | sort | grep "/"
