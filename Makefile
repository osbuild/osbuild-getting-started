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
setup-host:
	@./bin/setup-host.py container

.PHONY: build/osbuild 
build/osbuild:
	@podman build \
		--build-arg osbuild_version=$(osbuild_version) \
		-t $(PREFIX_BUILD)/osbuild:$(osbuild_version) \
		src/ogsc/build/osbuild 2>&1 > /dev/null

.PHONY: rpms/osbuild 
rpms/osbuild: build/osbuild
	@ls $(shell pwd)/build/rpms/osbuild-$(osbuild_version_x)-*.rpm > /dev/null || podman run \
		--rm \
		--volume $(shell pwd)/build/rpms/:/build/osbuild/rpmbuild/RPMS/noarch/:rw,Z \
		$(PREFIX_BUILD)/osbuild:$(osbuild_version) \
		make rpm 2>&1 > /dev/null

.PHONY: build/osbuild-composer
build/osbuild-composer:
	@podman build \
		--build-arg osbuild_composer_version=$(osbuild_composer_version) \
		-t $(PREFIX_BUILD)/osbuild-composer:$(osbuild_composer_version) \
		src/ogsc/build/osbuild-composer 2>&1 > /dev/null

.PHONY: rpms/osbuild-composer
rpms/osbuild-composer: build/osbuild-composer
	@ls $(shell pwd)/build/rpms/osbuild-composer-$(osbuild_composer_version_x)-* > /dev/null || podman run \
		--rm \
		--volume $(shell pwd)/build/rpms/:/build/osbuild-composer/rpmbuild/RPMS/x86_64/:rw,Z \
		$(PREFIX_BUILD)/osbuild-composer:$(osbuild_composer_version) \
		make scratch 2>&1 > /dev/null

.PHONY: config/osbuild-composer
config/osbuild-composer: build/osbuild-composer
	@podman run \
		--rm \
		--volume $(shell pwd)/build/rpms/:/build/osbuild-composer/rpmbuild/RPMS/x86_64/:rw,Z \
		--volume $(shell pwd)/build/config/:/build/config/:rw,Z \
		$(PREFIX_BUILD)/osbuild-composer:$(osbuild_composer_version) \
		bash -c './tools/gen-certs.sh ./test/data/x509/openssl.cnf /build/config /build/config/ca 2>&1 > /dev/null && cp ./test/data/composer/osbuild-composer.toml /build/config && cp ./test/data/worker/osbuild-worker.toml /build/config && cp -r ./repositories /build/config' 2>&1 > /dev/null

.PHONY: build/weldr-client
build/weldr-client:
	@podman build \
		--build-arg weldr_client_version=$(weldr_client_version) \
		-t $(PREFIX_BUILD)/weldr-client:$(weldr_client_version) \
		src/ogsc/build/weldr-client 2>&1 > /dev/null

.PHONY: rpms/weldr-client
rpms/weldr-client: build/weldr-client
	@ls $(shell pwd)/build/rpms/weldr-client-$(weldr_client_version_x)-* > /dev/null || podman run \
		--rm \
		--volume $(shell pwd)/build/rpms/:/build/weldr-client/rpmbuild/RPMS/x86_64/:rw,Z \
		$(PREFIX_BUILD)/weldr-client:$(weldr_client_version) \
		make scratch-rpm 2>&1 > /dev/null

.PHONY: run/composer
run/composer:
	@podman build \
		--volume $(shell pwd)/build/rpms:/rpms:ro,Z \
		--build-arg osbuild_composer_version=${osbuild_composer_version_x} \
		-t $(PREFIX_RUN)/composer:$(osbuild_composer_version) \
		src/ogsc/run/composer 2>&1 > /dev/null

.PHONY: run/worker
run/worker:
	@podman build \
		--volume $(shell pwd)/build/rpms:/rpms:ro,Z \
		--build-arg osbuild_composer_version=${osbuild_composer_version_x} \
		--build-arg osbuild_version=${osbuild_version_x} \
		-t $(PREFIX_RUN)/worker:$(osbuild_composer_version) \
		src/ogsc/run/worker 2>&1 > /dev/null

.PHONY: run/cli
run/cli:
	@podman build \
		--volume $(shell pwd)/build/rpms:/rpms:ro,Z \
		--build-arg weldr_client_version=${weldr_client_version_x} \
		-t $(PREFIX_RUN)/cli:$(weldr_client_version) \
		src/ogsc/run/cli 2>&1 > /dev/null

.PHONY: quick
quick: rpms/osbuild rpms/osbuild-composer rpms/weldr-client config/osbuild-composer run/composer run/worker run/cli

.PHONY: run
run: config/osbuild-composer quick
	@./bin/run.py ${osbuild_version} ${osbuild_composer_version} ${weldr_client_version}

.PHONY: clean
clean:
	podman image ls "ogsc/build/osbuild" || podman image rm -f $(shell podman image ls "ogsc/build/osbuild" -q)
	podman image ls "ogsc/build/osbuild-composer" || podman image rm -f $(shell podman image ls "ogsc/build/osbuild-composer" -q)
	podman image ls "ogsc/build/weldr-client" || podman image rm -f $(shell podman image ls "ogsc/build/weldr-client" -q)
	podman image ls "ogsc/run/composer" || podman image rm -f $(shell podman image ls "ogsc/run/composer" -q)
	podman image ls "ogsc/run/worker" || podman image rm -f $(shell podman image ls "ogsc/run/worker" -q)
	podman image ls "ogsc/run/cli" || podman image rm -f $(shell podman image ls "ogsc/run/cli" -q)
	rm $(shell pwd)/build/rpms/*.rpm
