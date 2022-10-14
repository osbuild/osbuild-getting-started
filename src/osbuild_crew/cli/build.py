from typing import Optional

import typer

from .. import build
from ..help import git, project
from ..rich import con

cli = typer.Typer()


@cli.callback()
def main(
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
) -> int:
    """Build-related subcommands."""

    return 0


@cli.command()
def rpms(
    ctx: typer.Context,
    projects: list[str],
    output_path: str = typer.Option(..., "--output-path", "-o", help="Foo"),
) -> int:
    """Build RPMs for `osbuild` projects."""
    root = ctx.parent

    projects = [project.normalize(p) for p in projects]
    builds = []

    for p in projects:
        if p not in project.info:
            con.print(
                f"[bold][red]Invalid project[/red][/bold], available projects are [bold]{', '.join(project.info.keys())} [/bold]"
            )
            return 1

        ref = root.params[f"{p}_ref"]
        rep = root.params[f"{p}_repo"]

        refs = git.refs_for_repository(rep)

        if ref is None:
            ref = git.tags_for_repository(rep)[-1]

        if ref not in refs:
            con.print(
                f"[bold][red]Invalid ref[/red][/bold], available refs for [bold]{p}[/bold] are [bold]{', '.join(refs)} [/bold]"
            )
            return 1

        builds += [(p, rep, ref)]

    con.print("[bold][green]Starting RPM build(s)[/green][/bold]")

    for (p, rep, ref) in builds:
        with con.status(
            f"[bold]Building build container for {p}@{ref}...[/bold]"
        ):
            con.print(
                f"[bold]Starting build container build for {p}@{ref}[/bold]"
            )
            build.build_container(p, rep, ref)
            con.print(f"[italic]Done with build container {p}@{ref}[/italic]")

        with con.status(f"[bold]Building rpms for {p}@{ref}...[/bold]"):
            con.print(f"[bold]Starting RPM build for {p}@{ref}[/bold]")
            build.rpms(p, rep, ref, output_path)
            con.print(f"[italic]Done with RPM build for {p}@{ref}[/italic]")

    con.print(
        f"[bold][green]RPMs built succesfully[/green][/bold], available in: [bold]{output_path}[/bold]"
    )

    return 0
