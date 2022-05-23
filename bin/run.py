#!/usr/bin/env python3

"""This file is part of the `osbuild-getting-started` project and is an ad-hoc
implementation of docker-compose, but without the docker-compose."""

import os
import tempfile
import subprocess
import asyncio
import logging

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


async def magic():
    """Run all the containers required, in the correct order, with the
    appropriate amount of magical incantations."""

    log.debug("magic: starting up")

    path_config = Path.cwd() / "build/config"

    with tempfile.TemporaryDirectory() as path_tmp:
        os.mkdir(f"{path_tmp}/weldr")
        os.mkdir(f"{path_tmp}/dnf-json")

        proc = await asyncio.create_subprocess_exec(
            "podman",
            "run",
            "--volume", f"{path_config}:/etc/osbuild-composer:ro,Z",
            "--volume", f"{path_tmp}/weldr:/run/weldr:rw,Z",
            "--volume", f"{path_tmp}/dnf-json:/run/osbuild-dnf-json:rw,Z",
            "ogsc/run/composer:v53",
            "--dnf-json",
            "--weldr-api",
            "--remote-worker-api",
            "--composer-api",
            "--composer-api-port", "8000"
        )
        await proc.wait()

    return 0


def main():
    logging.basicConfig(level=logging.DEBUG)

    log.debug("main: starting up")

    if not ensure():
        log.critical(
            "main: missing required files, did you run `make quick` yet?")

        return 1

    return asyncio.run(magic())


if __name__ == "__main__":
    raise SystemExit(main())
