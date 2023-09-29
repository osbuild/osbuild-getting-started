# Getting started with `osbuild`

The `osbuild` system is a group of applications, APIs, specifications, and
implementations to build images of Linux operating systems in an isolated
and reliable way. Ready to be deployed to your favorite cloud provider,
private hypervisor, or disk-media.

## Ecosystem

Tasks are split out across a multitude of tools, here's a quick rundown
of what each of them does.

### osbuild

At the core of the project is the [osbuild](https://github.com/osbuild/osbuild)
project. This provides the build pipelines.

### osbuild-composer

[osbuild-composer](https://github.com/osbuild/osbuild-composer) is the higher
level translation layer between front end tools and `osbuild`. It provides APIs
that can be used by web-frontends, cli-tools, and provides `osbuild` workers
that perform the build pipelines.

### composer-cli

The [composer-cli](https://github.com/osbuild/weldr-client) (called
`weldr-client` for historical reasons). Is one of the clients for
`osbuild-composer`. It provides a command line interface to the exposed APIs.

### image-builder

This is the console.redhat.com HTTP API that speaks to `osbuild-composer` and
translates it for the `image-builder-frontend`.

### image-builder-frontend

The frontend for console.redhat.com, it gets data from `image-builder`.

## Products

The above section explains some of the individual components that are used by
the two products the `image-builder` team ships:
  - an [on-premise](https://www.osbuild.org/guides/image-builder-on-premises/image-builder-on-premises.html) solution.
  - our hosted [service](https://www.osbuild.org/guides/image-builder-service/architecture.html)

These products make use of the individual components in slightly different configurations. Our [guides](https://www.osbuild.org/guides)
provide more in-depth explainations of these products, their architecture and how they are configured.

## Getting started

For further instructions on how to run containerized versions of the CLI and service locally:
- the [on-premise README](./on-prem/README.md) offers explainations on how to run the on-premise CLI tool.
- the [service README](./service/README.md) provides instructions on how to get started with a stack of the hosted service.
