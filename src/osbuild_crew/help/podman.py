from ..rich import con
from . import cmd


def create(name: str, context: str):
    con.print("Podman container build is starting.")

    cmd.run(
        ["podman", "build", "-t", name, context],
    )


def run(name: str, p_args: list[str], c_args: list[str]):
    con.print(f"Running command {c_args!r} in {name!r}")

    cmd.run(
        ["podman", "run"] + p_args + [name] + c_args,
    )
