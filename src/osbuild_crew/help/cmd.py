import subprocess


class Process:
    pass


def run(
    args: list[str], stdout: bool = False, stderr: bool = False
) -> subprocess.CompletedProcess:
    return subprocess.run(
        args,
        text=True,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
