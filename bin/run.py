#!/usr/bin/env python3

"""This file is part of the `osbuild-getting-started` project and is an ad-hoc
implementation of docker-compose, but without the docker-compose."""

import sys
import os
import tempfile
import subprocess
import asyncio
import logging
import secrets

from pathlib import Path


log = logging.getLogger(__name__)


def ensure():
    """Ensure all prerequisites for running the containers exist."""

    log.debug("ensure: testing file paths")

    # TODO: add all required file paths
    return all([
        Path("./build/rpms").exists(),
        Path("./build/config").exists(),
    ])


async def stop(process, timeout=5.0):
    try:
        await asyncio.wait_for(process.wait(), timeout=timeout)
    except asyncio.TimeoutError:
        process.kill()


async def magic(
    osbuild_version,
    osbuild_composer_version,
    weldr_client_version
):
    """Run all the containers required, in the correct order, with the
    appropriate amount of magical incantations."""

    log.debug("magic: starting up")

    prefix = secrets.token_hex(2)

    path_config = Path.cwd() / "build/config"

    with tempfile.TemporaryDirectory() as path_tmp:
        os.mkdir(f"{path_tmp}/weldr")
        os.mkdir(f"{path_tmp}/dnf-json")

        composer = await asyncio.create_subprocess_exec(
            "podman",
            "run",
            "--rm",
            "--volume", f"{path_config}:/etc/osbuild-composer:ro,Z",
            "--volume", f"{path_tmp}/weldr:/run/weldr:rw,Z",
            "--volume", f"{path_tmp}/dnf-json:/run/osbuild-dnf-json:rw,Z",
            "--network", "podman",
            "--name", f"{prefix}-composer",
            f"ogsc/run/composer:{osbuild_composer_version}",
            "--dnf-json",
            "--weldr-api",
            "--remote-worker-api",
            "--composer-api",
            "--composer-api-port", "8000",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        # XXX: silly stuff :)
        await asyncio.sleep(5)

        composer_inspect = await asyncio.create_subprocess_exec(
            "podman",
            "inspect",
            f"{prefix}-composer",
            "-f", "{{ .NetworkSettings.IPAddress }}",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        composer_ip = (await composer_inspect.stdout.readline()).decode().strip()
        await composer_inspect.wait()

        worker = await asyncio.create_subprocess_exec(
            "podman",
            "run",
            "--rm",
            "--volume", f"{path_config}:/etc/osbuild-composer:ro,Z",
            "--volume", f"{path_tmp}/weldr:/run/weldr:rw,Z",
            "--volume", f"{path_tmp}/dnf-json:/run/osbuild-dnf-json:rw,Z",
            "--network", "podman",
            "--add-host", f"composer:{composer_ip}",
            "--name", f"{prefix}-worker",
            "--env", "CACHE_DIRECTORY=/var/cache/osbuild-worker",
            f"ogsc/run/worker:{osbuild_composer_version}",
            "/usr/libexec/osbuild-composer/osbuild-worker",
            f"composer:8700",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await asyncio.sleep(5)

        cli = await asyncio.create_subprocess_exec(
            "podman",
            "run",
            "--rm",
            "--volume", f"{path_config}:/etc/osbuild-composer:ro,Z",
            "--volume", f"{path_tmp}/weldr:/run/weldr:rw,Z",
            "--volume", f"{path_tmp}/dnf-json:/run/osbuild-dnf-json:rw,Z",
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
    logging.basicConfig(level=logging.DEBUG)

    log.debug("main: starting up")

    try:
        osbuild_version, osbuild_composer_version, weldr_client_version = sys.argv[1:]
    except:
        usage()
        return 1

    if not ensure():
        log.critical(
            "main: missing required files, did you run `make quick` yet?")

        return 1

    return asyncio.run(magic(osbuild_version, osbuild_composer_version, weldr_client_version))


if __name__ == "__main__":
    raise SystemExit(main())
