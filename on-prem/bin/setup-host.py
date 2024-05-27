#!/usr/bin/env python3

# This script is part of the `osbuild-getting-started` repository and takes care
# of setting up all required dependencies on the host to run osbuild services in
# containers.

import logging
import subprocess
import sys

log = logging.getLogger(__name__)


# The base set of packages necessary.
package_base = {"git"}

package_set = {
    "container": {
        "podman",
    }
}


def package_install(packages):
    subprocess.run(
        [
            "dnf",
            "in",
            "-y",
        ]
        + list(packages)
    )

    return 0


def main():
    if len(sys.argv) != 2:
        log.error("main: lacking argument")
        return 1

    if sys.argv[1] not in package_set:
        log.error("main: invalid argument", file=sys.stderr)
        return 1

    package_install(package_set[sys.argv[1]])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
