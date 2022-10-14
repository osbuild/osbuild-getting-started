from typing import Optional

import typer

from . import build, inspect, manifest, run

cli = typer.Typer()


@cli.callback()
def main(
    ctx: typer.Context,
):
    """`osbuild-crew` is a small Python command line utility to run and build
    things from the `osbuild` ecosystem."""


cli.add_typer(build.cli, name="build")
cli.add_typer(run.cli, name="run")
cli.add_typer(inspect.cli, name="inspect")
cli.add_typer(manifest.cli, name="manifest")
