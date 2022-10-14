from typing import Optional

import typer

from . import build, inspect, manifest, run

cli = typer.Typer()


@cli.callback()
def main(
    ctx: typer.Context,
    osbuild_repo: str = typer.Option(
        "https://github.com/osbuild/osbuild",
        help="Repository to get `osbuild` sources from.",
    ),
    osbuild_ref: Optional[str] = typer.Option(
        None, help="Reference to checkout from the `osbuild` repository."
    ),
    osbuild_composer_repo: str = typer.Option(
        "https://github.com/osbuild/osbuild-composer",
        help="Repository to get `osbuild-composer` sources from.",
    ),
    osbuild_composer_ref: Optional[str] = typer.Option(
        None,
        help="Reference to checkout from the `osbuild-composer` repository.",
    ),
    weldr_client_repo: str = typer.Option(
        "https://github.com/osbuild/weldr-client",
        help="Repository to get `weldr-client` sources from.",
    ),
    weldr_client_ref: Optional[str] = typer.Option(
        None,
        help="Reference to checkout from the `weldr-client` repository.",
    ),
):
    """`osbuild-crew` is a small Python command line utility to run and build
    things from the `osbuild` ecosystem."""


cli.add_typer(build.cli, name="build")
cli.add_typer(run.cli, name="run")
cli.add_typer(inspect.cli, name="inspect")
cli.add_typer(manifest.cli, name="manifest")
