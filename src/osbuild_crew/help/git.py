from functools import cache

from . import cmd


@cache
def tags_for_repository(repository: str) -> list[str]:
    """Get the tags for a repository location, which is either a URL or a local
    file path. The results of this function are cached."""

    process = cmd.run(
        [
            "git",
            "-c",
            "versionsort.suffix=-",
            "ls-remote",
            "--tags",
            "--sort",
            "v:refname",
            repository,
        ]
    )

    return [
        ref.split("/")[-1]
        for ref in process.stdout.splitlines()
        if "{}" not in ref
    ]


@cache
def branches_for_repository(repository: str) -> list[str]:
    """Get the branches for a repository location, which is either a URL or a
    local file path. The results of this function are cached."""

    process = cmd.run(
        [
            "git",
            "-c",
            "versionsort.suffix=-",
            "ls-remote",
            "--heads",
            "--sort=v:refname",
            repository,
        ],
    )

    return [
        ref.split("/")[-1]
        for ref in process.stdout.splitlines()
        if "{}" not in ref
    ]


@cache
def refs_for_repository(repository: str) -> list[str]:
    """A combination of branches and tags for a repository location."""
    return tags_for_repository(repository) + branches_for_repository(repository)


def clone_at_ref(repository: str, reference: str, target: str) -> None:
    cmd.run(
        ["git", "clone", "-b", reference, "--depth", "1", repository, target]
    )
