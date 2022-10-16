import json
import secrets
import subprocess
import tempfile
import os

import rich
import typer
from rich.tree import Tree

from ..rich import con

cli = typer.Typer()


def recurse(tree: Tree, data, name: str) -> Tree:
    if isinstance(data, (int, str)):
        subtree = tree.add(f"{name}: [bold]{data}[/bold]")
    elif isinstance(data, dict):
        subtree = tree.add(str(name))
        for key, val in data.items():
            recurse(subtree, val, key)
    elif isinstance(data, list):
        name = f"{name} [italic]({len(data)})[/italic]"
        subtree = tree.add(name)
        for index, item in enumerate(data):
            recurse(subtree, item, index)
    else:
        raise ValueError(f"recurse does not know how to deal with {type(data)}")
    return subtree


def ignore(name: str, data) -> None:
    for pipeline in data["pipelines"]:
        to_pop = []
        for index, stage in enumerate(pipeline["stages"]):
            if stage["type"] == name:
                to_pop.append(index)
        for index in to_pop:
            pipeline["stages"].pop(index)


def manifest_to_tree(
    path: str,
    ignore_stage: list[str],
    resolve_sources: bool,
    skip_sources: bool,
):
    try:
        with open(path) as f:
            data = json.load(f)
    except FileNotFoundError:
        con.print(f"[bold][red]Could not open file {path!r}[/red][/bold]")
        return 1

    # If the manifest comes from composer we extract the manifest part
    if "manifest" in data:
        data = data["manifest"]

    for stage in ignore_stage:
        ignore(stage, data)

    if resolve_sources and "sources" in data:
        resolve(data)

    if skip_sources and "sources" in data:
        del data["sources"]

    return recurse(Tree(""), data, f"[bold]{path}[/bold]")


def resolve(data) -> None:
    # If we're resolving content hashes back to names we adjust the data structure
    # in-place.
    sources = {}

    # We can't handle all source types but some we can
    if "org.osbuild.curl" in data["sources"]:
        for name, source in data["sources"]["org.osbuild.curl"][
            "items"
        ].items():
            sources[name] = source["url"]

    for pipeline in data["pipelines"]:
        for stage in pipeline["stages"]:
            if stage["type"] == "org.osbuild.rpm":
                for index, reference in enumerate(
                    stage["inputs"]["packages"]["references"]
                ):
                    stage["inputs"]["packages"]["references"][index] = sources[
                        reference["id"]
                    ].split("/")[-1]
                    # reference[f"[italic]rpm-name[/italic]"] = sources[reference['id']].split("/")[-1]


@cli.callback()
def main() -> int:
    """Manifest-related subcommands."""

    return 0


@cli.command(name="print")
def pretty_print(
    manifest: str,
    ignore_stage: list[str] = typer.Option([]),
    resolve_sources: bool = typer.Option(
        True, help="Resolve content hashes of sources to their names."
    ),
    skip_sources: bool = typer.Option(
        True, help="Skips display of the sources in the manifest."
    ),
) -> int:
    """Pretty print an `osbuild` manifest file."""

    con.print(
        manifest_to_tree(manifest, ignore_stage, resolve_sources, skip_sources)
    )

    return 0


@cli.command(name="diff")
def pretty_diff(
    manifests: list[str],
    ignore_stage: list[str] = typer.Option([]),
    resolve_sources: bool = typer.Option(
        True, help="Resolve content hashes of sources to their names."
    ),
    skip_sources: bool = typer.Option(
        True, help="Skips display of the sources in the manifest."
    ),
) -> int:
    """Pretty print a diff of `osbuild` manifest files."""

    with tempfile.TemporaryDirectory() as temporary:
        paths = []

        for manifest in manifests:
            tree = manifest_to_tree(
                manifest, ignore_stage, resolve_sources, skip_sources
            )

            path = f"{temporary}/{os.path.basename(manifest)}-{secrets.token_hex(2)}"

            with open(path, "w") as f:
                rich.print(tree, file=f)

            paths.append(path)

        subprocess.run(["vimdiff"] + paths)

    return 0
