# devtools

Development Tools for Image Builder

## Setup

To start local development, first clone the image builder stack:

```bash
git clone git@github.com:osbuild/osbuild-composer.git
git clone git@github.com:osbuild/image-builder.git
git clone git@github.com:osbuild/osbuild-getting-started.git
```

The folder structure should look like:

```
.
├── image-builder
├── osbuild-getting-started
└── osbuild-composer
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

Upload targets need to be configued for the Image Builder backend to upload successfully.
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
Run the following from **this directory**.
- stop the containers and remove volumes

```bash
docker compose down -v
```

- rebuild the config container

```bash
docker compose build config
```

- start the containers again

```bash
docker compose up
```

## Run the backend

To build the containers run the following command from **this directory**:

```bash
docker compose build
```

To run the containers:

```bash
docker compose up
```

## Run the frontend

The frontend has been removed as a container in favour of running it separately in order to leverage hot-reloading
capabilities. In order to run the frontend with the backend you can run the following command:

```bash
npm run devel
```

Access the service through the GUI:
[https://stage.foo.redhat.com:1337/beta/insights/image-builder](https://stage.foo.redhat.com:1337/beta/insights/image-builder), or
directly through the API:
[https://stage.foo.redhat.com:1337/docs/api/image-builder](https://stage.foo.redhat.com:1337/docs/api/image-builder).
