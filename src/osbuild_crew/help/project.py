import hashlib
from functools import cache

info = {
    "osbuild": None,
    "osbuild_composer": None,
    "weldr_client": None,
}


def normalize(project: str) -> str:
    """Normalize all `-` to `_`."""
    return project.replace("-", "_")


@cache
def key(project: str, repository: str, ref: str) -> str:
    """The `project_key` is a short name for a project source, it's used to
    name resources and to cache outputs."""

    return hashlib.sha256(
        f"{project}{repository}{ref}".encode("utf8")
    ).hexdigest()[:8]
