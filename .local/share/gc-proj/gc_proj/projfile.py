"""Project files: .proj.json, a flat JSON object of strings."""
from __future__ import annotations

import json
import os
from pathlib import Path

from .ui import tilde
from .util import write_atomic

FILE = ".proj.json"
# Stored as ~/... when under $HOME, so a synced project file works on every host.
PATH_KEYS = ("dir",)


def has_file(projdir: Path) -> bool:
    return (projdir / FILE).is_file()


def read(projdir: Path) -> dict[str, str]:
    """The project's keys; {} if it has no project file."""
    try:
        data = json.loads((projdir / FILE).read_text())
    except (OSError, ValueError):
        return {}
    if not isinstance(data, dict):
        return {}
    keys = {str(k): "" if v is None else str(v) for k, v in data.items()}
    for key in PATH_KEYS:
        if keys.get(key):
            keys[key] = os.path.expanduser(keys[key])
    return keys


def write(projdir: Path, updates: dict[str, str]) -> None:
    """Set keys of the project; an empty value removes the key."""
    data = read(projdir)
    for key, value in updates.items():
        if value == "":
            data.pop(key, None)
        else:
            data[key] = value
    for key in PATH_KEYS:
        if data.get(key):
            data[key] = tilde(data[key])
    write_atomic(projdir / FILE, json.dumps(data, indent=2) + "\n")
