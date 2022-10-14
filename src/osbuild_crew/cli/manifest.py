import json

import typer
from rich.tree import Tree

cli = typer.Typer()

from ..rich import con


def recurse(tree: Tree, data, name: str) -> Tree:
    if isinstance(data, (int, str)):
        subtree = tree.add(f"{name}: [bold]{data}[/bold]")
    elif isinstance(data, dict):
        subtree = tree.add(str(name))
        for key, val in data.items():
            recurse(subtree, val, key)
    elif isinstance(data, list):
        subtree = tree.add(name)
        for index, item in enumerate(data):
            recurse(subtree, item, index)
    return subtree


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
def main(manifest: str) -> int:
    """Manifest-related subcommands."""

    return 0


@cli.command()
def pretty_print(
    ctx: typer.Context,
    resolve_sources: bool = typer.Option(
        True, help="Resolve content hashes of sources to their names."
    ),
    skip_sources: bool = typer.Option(
        True, help="Skips display of the sources in the manifest."
    ),
) -> int:
    """Pretty print an `osbuild` manifest file."""

    root = ctx.parent
    path = root.params["manifest"]

    try:
        with open(path) as f:
            data = json.load(f)
    except FileNotFoundError:
        con.print(f"[bold][red]Could not open file {path!r}[/red][/bold]")
        return 1

    if resolve_sources and "sources" in data:
        resolve(data)

    if skip_sources and "sources" in data:
        del data["sources"]

    tree = recurse(Tree(""), data, f"[bold]{path}[/bold]")
    con.print(tree)

    return 0
