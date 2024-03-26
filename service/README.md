# devtools

Development Tools for Image Builder
Here are some tools of "Image Builder" to start up a development environment for the
[hosted deployment](https://osbuild.org/docs/hosted/architecture/).
The reason for all the `sudo` below is that the stack has to perform may operations
with loop devices etc. where root privileges are required. 

## Setup

To start local development, first clone the image builder stack and all it's dependent source.

```bash
git clone git@github.com:osbuild/community-gateway.git
git clone git@github.com:osbuild/image-builder-frontend.git
git clone git@github.com:osbuild/image-builder.git
git clone git@github.com:osbuild/images.git
git clone git@github.com:osbuild/osbuild-composer.git
git clone git@github.com:osbuild/osbuild-getting-started.git
git clone git@github.com:osbuild/osbuild.git
git clone git@github.com:osbuild/pulp-client.git
```

The folder structure should look like this:

```
.
├── community-gateway
├── image-builder
├── image-builder-frontend
├── images
├── osbuild
├── osbuild-composer
├── osbuild-getting-started
└── pulp-client
```

Secondly redirect a stage and prod domains to localhost. If you are outside
the Red Hat VPN, only `prod` is available:

```bash
echo "127.0.0.1 prod.foo.redhat.com" >> /etc/hosts
echo "127.0.0.1 stage.foo.redhat.com" >> /etc/hosts
```

Lastly, you will need to ensure that the folders for the config volume and the local S3 bucket
have been created:

> This can be modified in the volumes
> section of the `docker-compose.yaml`
> file

```bash
sudo mkdir -p /scratch/podman/image-builder-config
```

> The name of the bucket used is `service`,
> you can change this in the `.env` file

```bash
sudo mkdir -p /scratch/data/s3/service
```

## Docker compose notes

As per the [docker compose cli](https://docs.docker.com/compose/reference/) docs, the new syntax for running docker compose changed from
`docker-compose` to `docker compose`. We will use `docker compose` for the rest of this readme file, but you may need to use the former
command.

## Upload Targets

Upload targets need to be configured for the Image Builder backend to upload successfully.
This stack comes pre-configured with a generic S3 bucket which can be accessed at:

`http://localhost:9000`

- username: admin
- password: password42

If you prefer to use another upload target, you will need to configure the worker accordingly.
Using AWS for AMIs for example, you would need to add the config options in the `./config/worker/osbuild-worker.toml`
file, as follows:

```toml
...

[aws]
credentials = "/etc/osbuild-worker/aws-creds"
bucket = "<your bucket name>"

...
```

In addition, you will need to ensure that your AWS credentials are mounted as a volume on the worker container:

```yaml
...

volumes:
  - config:/etc/osbuild-composer
  - config:/etc/osbuild-worker
  - /path/to/aws/credentials:/etc/osbuild-worker/aws-creds:Z

...
```

The config variables for the worker can be found [here](https://github.com/osbuild/osbuild-composer/blob/main/cmd/osbuild-worker/config.go).

*NOTE:* If you change the config files, you will either need to modify the worker config in the `/scratch/podman/image-builder-config` file and restart
the containers. Alternatively, you will need to remove the named volume and rebuild the config container. The steps for this are
as follows:
Run the following from the main **osbuild-getting-started directory** (one level above where this README.md is).

```bash
make help
```
 
- stop the containers and remove volumes

```bash
make prune-service
```

- rebuild containers

```bash
make service-containers
```

- start the containers again

```bash
make run-service
```

## Run the frontend separately

The command above (`make run-service`) also starts the frontend by bind-mounting the source
from your computer, so hot-reload of `npm` should work.
If you want to run the frontend yourself (see the [README.md](https://github.com/osbuild/image-builder-frontend/blob/main/README.md) there)
you can use the make target:

```bash
make run-service-no-fronted
```

You have to have a "staging account" in order to run this setup (although it's local).  
Check if you can log in at https://console.stage.redhat.com/

Access the service through the GUI:
[https://stage.foo.redhat.com:1337/beta/insights/image-builder](https://stage.foo.redhat.com:1337/beta/insights/image-builder), or
directly through the API:
[https://stage.foo.redhat.com:1337/docs/api/image-builder](https://stage.foo.redhat.com:1337/docs/api/image-builder).

## Debugging
When you want to use your IDE (Integrated Development Environment) to debug the go-code you can check out the
`GODEBUG_PORT` variables in [docker-composer.yml](./docker-composer.yml) and enable debugging for the supported
layers.

## Known Problems

If you encounter problems with the certificate when you browse to
[https://stage.foo.redhat.com:1337/preview/insights/image-builder](https://stage.foo.redhat.com:1337/preview/insights/image-builder)
you might need to rebuild the certificates with:
```
make wipe-config
```

