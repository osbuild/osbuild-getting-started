from . import build as _build
from . import run as _run

build = {
    "osbuild": _build.osbuild,
    "osbuild_composer": _build.osbuild_composer,
    "weldr_client": _build.weldr_client,
}
