"""
Resolve the package version dynamically so it stays in sync with the
parent NodeGoat app's npm version without anyone committing changes
back to this file.

Resolution order:
  1. Installed wheel metadata (importlib.metadata)        — runtime
  2. NPM_PACKAGE_BUILD_VERSION env var (set by CI)        — build time
  3. package.json discovered by walking up from this file — local dev
  4. "0.0.0+dev" — safe PEP 440 fallback
"""
import json
import os
from pathlib import Path

try:
    from importlib.metadata import version as _pkg_version, PackageNotFoundError
except ImportError:  # Python < 3.8
    from importlib_metadata import version as _pkg_version, PackageNotFoundError  # type: ignore


def _resolve_version() -> str:
    try:
        return _pkg_version("node-goat-insights")
    except PackageNotFoundError:
        pass

    env = os.environ.get("NPM_PACKAGE_BUILD_VERSION")
    if env:
        return env

    here = Path(__file__).resolve()
    for parent in here.parents:
        candidate = parent / "package.json"
        if candidate.is_file():
            try:
                return json.loads(candidate.read_text())["version"]
            except (json.JSONDecodeError, KeyError, OSError):
                continue

    return "0.0.0+dev"


__version__ = _resolve_version()
