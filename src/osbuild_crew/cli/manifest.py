import json
import os
import secrets
import subprocess
import tempfile

import rich
import typer
from rich.tree import Tree

from ..rich import con

cli = typer.Typer()


def recurse_as_tree(tree: Tree, data, name: str) -> Tree:
    if tree is None:
        tree = Tree("")

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


def recurse_as_html(_html, data, name: str):
    if _html is None:
        _html = "<ul>"

    if isinstance(data, (int, str)):
        _html += '<li class="type-str">'
        _html += '<div class="name">{}</div>'.format(name)
        _html += '<div class="data">{}</div>'.format(data)
        _html += "</li>"
    elif isinstance(data, dict):
        _html += '<li class="type-dict">'
        _html += '<div class="name">{}</div>'.format(name)
        _html += '<div class="data">'

        for key, value in data.items():
            _html += recurse_as_html(None, value, key)

        _html += "</div>"
        _html += "</li>"
    elif isinstance(data, list):
        _html += '<li class="type-list">'
        _html += '<div class="name">{}</div>'.format(name)
        _html += '<div class="data">'

        for key, value in enumerate(data):
            _html += recurse_as_html(None, value, key)

        _html += "</div>"
        _html += "</li>"
    else:
        raise ValueError(
            f"manifest_as_tree does not know how to deal with {type(data)}"
        )

    _html += "</ul>"

    return _html


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
    formatter,
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

    return formatter(None, data, f"{path}")


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
        manifest_to_tree(
            manifest,
            ignore_stage,
            resolve_sources,
            skip_sources,
            recurse_as_tree,
        )
    )

    return 0


@cli.command(name="html")
def pretty_html(
    manifest: str,
    ignore_stage: list[str] = typer.Option([]),
    resolve_sources: bool = typer.Option(
        True, help="Resolve content hashes of sources to their names."
    ),
    skip_sources: bool = typer.Option(
        True, help="Skips display of the sources in the manifest."
    ),
) -> int:
    """Pretty print an `osbuild` manifest file as html."""

    tree = manifest_to_tree(
        manifest, ignore_stage, resolve_sources, skip_sources, recurse_as_html
    )

    # XXX lol
    print(
        """\
<html>
    <head>
        <title>%s</title>
        <style type="text/css">
            html {
              background: #fefefe; }

            main ul {
              font-family: monospace;
              font-size: .75rem;
              list-style: none;
              padding-left: .5rem; }

            main > ul {
              margin: 1rem;
              color: #333; }

            li {
              display: table;
              position: relative;
              padding-left: .25rem; }
              li:before {
                position: absolute;
                display: block;
                width: .5rem;
                left: -.5rem;
                height: 1px;
                top: .5rem;
                content: "";
                background: #eee; }
              li.hover > div.name {
                color: red; }
                li.hover > div.name:before {
                  background: red; }
              li.hover > div.name:before {
                background: red; }
              li.hover > div.data > ul > li:before {
                background: red; }
              li > div {
                display: table-cell; }
                li > div.name {
                  white-space: nowrap;
                  padding-right: .35rem;
                  position: relative; }
                  li > div.name:before {
                    position: absolute;
                    display: block;
                    width: 1px;
                    right: 0;
                    top: .5rem;
                    bottom: .5rem;
                    content: "";
                    background: #eee; }
        </style>
    </head>
    <body>
        <main>
            <h2>%s</h2>
            %s
        </main>
        <script type="text/javascript">
            window.addEventListener("DOMContentLoaded", (event) => {
                console.log("hello");

                for(let element of document.querySelectorAll("div.name")) {
                    element.addEventListener("mouseover", (event) => {
                        event.stopPropagation();
                        event.target.parentElement.classList.add("hover");
                    });

                    element.addEventListener("mouseout", (event) => {
                        event.stopPropagation();
                        event.target.parentElement.classList.remove("hover");
                    });
                }
            });
        </script>
    </body>
"""
        % (manifest, manifest, tree)
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
                manifest,
                ignore_stage,
                resolve_sources,
                skip_sources,
                recurse_as_tree,
            )

            path = f"{temporary}/{os.path.basename(manifest)}-{secrets.token_hex(2)}"

            with open(path, "w") as f:
                rich.print(tree, file=f)

            paths.append(path)

        subprocess.run(["vimdiff"] + paths)

    return 0
