# Getting started with `osbuild` on-prem containers

## Quickstart

`osbuild-getting-started` tries to make it as easy as possible to both build
RPMs of anything in the `osbuild` ecosystem as to run it (after you've built it).

You should be all set with the following which drops you into the
`composer-cli` where you can build an image or play around:

```
[root@desktopa osbuild-getting-started]# make setup-host
# ...
[root@desktopa osbuild-getting-started]# make run
Makefile: build/osbuild-composer: creating ogsc/build/osbuild-composer:v54
Makefile: build/osbuild: creating ogsc/build/osbuild:v57
Makefile: rpms/osbuild: creating rpms for osbuild v57
Makefile: rpms/osbuild-composer: creating rpms for osbuild-composer v54
Makefile: build/weldr-client: creating ogsc/build/weldr-client:v35.5
Makefile: rpms/weldr-client: creating rpms for weldr-client v35.5
Makefile: run/composer: creating ogsc/run/composer:v54
Makefile: run/worker: creating ogsc/run/worker:v54_v57
Makefile: run/cli: creating ogsc/run/cli:v35.5
run.py: env: starting `composer` container at 'v54'
run.py: env: `composer` container has ip '10.88.0.59'
run.py: env: starting `worker` container at 'v54'/'v57'
run.py: env: starting `cli` container at 'v35.5'
[root@665d08e647e1 composer]# composer-cli blueprints push data/blueprint.toml
[root@665d08e647e1 composer]# composer-cli compose start example-image oci
Compose ec2dab95-4ab7-4674-aa2d-27f992a42922 added to the queue
# ...
[root@665d08e647e1 composer]# composer-cli compose status
ec2dab95-4ab7-4674-aa2d-27f992a42922 FINISHED Tue Jun 7 09:59:39 2022 example-image   0.0.1 oci              2147483648
```

To run a different version you can provide the version information as follows:

```
make run osbuild_version=v114 osbuild_composer_version=v104 weldr_client_version=v35.11
```

NOTE: always run as root as we need many permissions to build an image

## Build

Docker is used to build the RPMs, to get started make sure your host system
has Docker on it (you can set this up through ``sudo make setup-host``).

When the host system is set up it is time to build some RPMs, the steps are
two-fold where a build container is created which we then later use to perform
the build in. This allows you to inspect the build environment (but you don't
*have* to).

By default `osbuild-getting-started` gets the latest tags from the upstream
repositories but these can be overridden:


```
make build/osbuild osbuild_version=v55
make rpms/osbuild osbuild_version=v55
```

The first incantation will check out the `v55` tag for `osbuild` and create a
container with all build requirements satisfied. The second command will build
the RPMs, these are available in `./build/rpms` afterwards. Note that the first
is a dependency of the second.

```
€ ls ./build/rpms/
osbuild-55-1.20220505git090f768.fc36.noarch.rpm
python3-osbuild-55-1.20220505git090f768.fc36.noarch.rpm
```

Building for different versions is done by passing a different version to the
Makefile. If you want to build the `main` branch you can leave out the version
argument.

To build other things from the ecosystem the format is the same:

```
make rpms/osbuild-composer osbuild_composer_version=v51
make rpms/weldr-client weldr_client_version=v35
```

## Run

If you've built at least `osbuild` and `osbuild-composer` and their RPMs it's time
to get things up and running.
