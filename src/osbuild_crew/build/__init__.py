import os
import shutil
import tempfile

from ..data import build_commands, container_files
from ..help import git, podman, project
from ..rich import con


def build_container(p: str, repository: str, ref: str) -> None:
    with tempfile.TemporaryDirectory() as context:
        con.print(f"Setting up build container context in {context!r}.")

        con.print("Checking out repository.")
        git.clone_at_ref(repository, ref, f"{context}/repo")

        con.print("Creating Containerfile.")
        with open(f"{context}/Containerfile", "w") as container_file:
            container_file.write(container_files.build[p])

        name = f"{p}-{project.key(p, repository, ref)}"

        con.print(f"Started building build container as {name!r}.")

        podman.create(name, context)


def rpms(p: str, repository: str, ref: str, output_path: str) -> None:
    with tempfile.TemporaryDirectory() as context:
        con.print(f"Setting up RPM context in {context!r}.")

        name = f"{p}-{project.key(p, repository, ref)}"

        con.print(f"Using build container {name!r} for RPM build.")
        con.print("Starting RPM build.")

        podman.run(
            name,
            ["--volume", f"{context}:/build/rpmbuild/RPMS/noarch/:rw,Z"],
            build_commands[p],
        )

        full_path = f"{output_path}/{name}"

        con.print(f"RPM build complete copying results to {full_path!r}.")

        # Now copy out all the RPMs
        if os.path.exists(full_path):
            con.print(
                f"[yellow]Found existing {full_path!r}, removing.[/yellow]"
            )
            shutil.rmtree(full_path)

        shutil.copytree(context, full_path)

        con.print(f"RPMs created: {os.listdir(context)!r}")
