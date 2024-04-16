#!/usr/bin/env python3

"""This file is part of the `osbuild-getting-started` project and is an ad-hoc
implementation of docker-compose, but without the docker-compose."""

import sys
import os
import tempfile
import subprocess
import asyncio
import secrets

from pathlib import Path


def ensure():
    """Ensure all prerequisites for running the containers exist."""

    # TODO: add all required file paths
    return all([
        Path("./build/rpms").exists(),
        Path("./build/config").exists(),
    ])


async def stop(process, timeout=5.0):
    try:
        process.terminate()
        await asyncio.wait_for(process.wait(), timeout=timeout)
    except asyncio.TimeoutError:
        process.kill()


async def env(
    osbuild_version,
    osbuild_composer_version,
    weldr_client_version
):
    """Run all the containers required, in the correct order, with the
    appropriate amount of magical incantations."""

    prefix = secrets.token_hex(2)

    path_config = Path.cwd() / "build/config"
    path_run = Path.cwd() / "run"
    path_cache = Path.cwd() / "run"

    with tempfile.TemporaryDirectory() as path_tmp:

        os.mkdir(f"{path_tmp}/logs")

        with open(f"{path_tmp}/logs/composer.stdout.log", 'w') as composer_stdout, \
             open(f"{path_tmp}/logs/composer.stderr.log", 'w') as composer_stderr, \
             open(f"{path_tmp}/logs/worker.stdout.log", 'w') as worker_stdout, \
             open(f"{path_tmp}/logs/worker.stderr.log", 'w') as worker_stderr:

            os.mkdir(f"{path_tmp}/weldr")
            os.mkdir(f"{path_tmp}/cloudapi")
            os.mkdir(f"{path_tmp}/dnf-json")

            print(f"\nrun.py: env: temporary sockets and logs are going to {path_tmp}")
            print(f"run.py: env: starting `composer` container at {osbuild_composer_version!r}")

            composer = await asyncio.create_subprocess_exec(
                "podman",
                "run",
                "--rm",
                "--volume", f"{path_config}:/etc/osbuild-composer:ro,z",
                "--volume", f"{path_tmp}/weldr:/run/weldr:rw,z",
                "--volume", f"{path_tmp}/cloudapi:/run/cloudapi:rw,z",
                "--volume", f"{path_tmp}/dnf-json:/run/osbuild-dnf-json:rw,z",
                "--network", "podman",
                "--name", f"{prefix}-composer",
                f"ogsc/run/composer:{osbuild_composer_version}",
                "--dnf-json",
                "--weldr-api",
                "--remote-worker-api",
                "--composer-api",
                "--composer-api-port", "8000",
                stdout=composer_stdout,
                stderr=composer_stderr,
            )

            # XXX: silly stuff :)
            await asyncio.sleep(5)

            composer_inspect = await asyncio.create_subprocess_exec(
                "podman",
                "inspect",
                f"{prefix}-composer",
                "-f", "{{ .NetworkSettings.Networks.podman.IPAddress }}",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            composer_ip = (await composer_inspect.stdout.readline()).decode().strip()
            await composer_inspect.wait()

            print(f"run.py: env: `composer` container has ip {composer_ip!r}")
            print(f"run.py: env: starting `worker` container at {osbuild_composer_version!r} (using osbuild {osbuild_version!r})")

            worker = await asyncio.create_subprocess_exec(
                "podman",
                "run",
                "--rm",
                "--privileged",
                "--volume", f"{path_config}:/etc/osbuild-composer:ro,z",
                "--volume", f"{path_run}:/run/osbuild:rw,z",
                "--volume", f"{path_cache}:/var/cache/osbuild-worker:rw,z",
                "--volume", f"/dev:/dev,z",
                "--network", "podman",
                "--add-host", f"composer:{composer_ip}",
                "--name", f"{prefix}-worker",
                "--env", "CACHE_DIRECTORY=/var/cache/osbuild-worker",
                f"ogsc/run/worker:{osbuild_composer_version}_{osbuild_version}",
                "composer:8700",
                stdout=worker_stdout,
                stderr=worker_stderr,
            )
            await asyncio.sleep(5)

            print(f"run.py: env: starting `cli` container at {weldr_client_version!r}")
            print(f"\nrun.py: env: Welcome to osbuild! You can now use `composer-cli` to build images")
            print(f"run.py: env: … and `exit` afterwards")

            cli = await asyncio.create_subprocess_exec(
                "podman",
                "run",
                "--rm",
                "--volume", f"{path_config}:/etc/osbuild-composer:ro,z",
                "--volume", f"{path_tmp}/weldr:/run/weldr:rw,z",
                "--volume", f"{path_tmp}/dnf-json:/run/osbuild-dnf-json:rw,z",
                "--network", "podman",
                "--add-host", f"composer:{composer_ip}",
                "--name", f"{prefix}-cli",
                "-it",
                f"ogsc/run/cli:{weldr_client_version}",
                "/bin/bash",
            )

            await cli.wait()

            await asyncio.gather(stop(composer), stop(worker))

    return 0


def usage():
    print("wrong!")


def main():
    try:
        osbuild_version, osbuild_composer_version, weldr_client_version = sys.argv[1:]
    except:
        usage()
        return 1

    if not ensure():
        print("run.py: main: missing required files, did you run `make quick` yet?")

        return 1

    return asyncio.run(env(osbuild_version, osbuild_composer_version, weldr_client_version))


if __name__ == "__main__":
    raise SystemExit(main())
