"""Project files: .proj.json, a flat JSON object of strings."""
from __future__ import annotations

import json
from pathlib import Path

from .util import write_atomic

FILE = ".proj.json"


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
    return {str(k): "" if v is None else str(v) for k, v in data.items()}


def write(projdir: Path, updates: dict[str, str]) -> None:
    """Set keys of the project; an empty value removes the key."""
    data = read(projdir)
    for key, value in updates.items():
        if value == "":
            data.pop(key, None)
        else:
            data[key] = value
    write_atomic(projdir / FILE, json.dumps(data, indent=2) + "\n")
