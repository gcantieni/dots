"""Project files: .proj.json, a flat JSON object of strings.

Older projects have .proj, bash-sourceable key=value lines (or a single line
holding just the dir). Those are still read, and the first write replaces them
with .proj.json.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path

from .util import write_atomic

FILE = ".proj.json"
LEGACY_FILE = ".proj"


def has_file(projdir: Path) -> bool:
    return (projdir / FILE).is_file() or (projdir / LEGACY_FILE).is_file()


def read(projdir: Path) -> dict[str, str]:
    """The project's keys; {} if it has no project file."""
    path = projdir / FILE
    if path.is_file():
        try:
            data = json.loads(path.read_text())
        except (OSError, ValueError):
            return {}
        if not isinstance(data, dict):
            return {}
        return {str(k): "" if v is None else str(v) for k, v in data.items()}
    legacy = projdir / LEGACY_FILE
    if legacy.is_file():
        return read_shell(legacy)
    return {}


def write(projdir: Path, updates: dict[str, str]) -> None:
    """Set keys of the project; an empty value removes the key."""
    data = read(projdir)
    for key, value in updates.items():
        if value == "":
            data.pop(key, None)
        else:
            data[key] = value
    write_atomic(projdir / FILE, json.dumps(data, indent=2) + "\n")
    legacy = projdir / LEGACY_FILE
    if legacy.is_file():
        legacy.unlink()


def migrate(projdir: Path) -> bool:
    """Convert a legacy .proj; True if there was one."""
    if (projdir / FILE).is_file() or not (projdir / LEGACY_FILE).is_file():
        return False
    write(projdir, {})
    return True


_ASSIGN = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
_ANSI_C = {"a": "\a", "b": "\b", "e": "\x1b", "E": "\x1b", "f": "\f", "n": "\n",
           "r": "\r", "t": "\t", "v": "\v", "\\": "\\", "'": "'", '"': '"', "?": "?"}


class _NeedsShell(Exception):
    pass


def read_shell(path: Path) -> dict[str, str]:
    """Keys of a bash-sourceable key=value file."""
    try:
        text = path.read_text(errors="replace")
    except OSError:
        return {}
    lines = [line for line in text.splitlines() if line.strip()]
    if len(lines) == 1 and "=" not in lines[0]:
        return {"dir": lines[0].strip()}
    try:
        return _parse_lines(lines)
    except _NeedsShell:
        return _read_with_bash(path, lines)


def _parse_lines(lines: list[str]) -> dict[str, str]:
    values = {}
    for line in lines:
        if line.lstrip().startswith("#"):
            continue
        m = _ASSIGN.match(line)
        if not m:
            raise _NeedsShell
        values[m.group(1)] = _shell_word(m.group(2))
    return values


def _shell_word(s: str) -> str:
    """The value of a simple shell word, or _NeedsShell if it takes a shell to evaluate."""
    out = []
    i, n = 0, len(s)
    if s.startswith("~"):
        if n == 1 or s[1] == "/":
            out.append(os.path.expanduser("~"))
            i = 1
        else:
            raise _NeedsShell
    while i < n:
        c = s[i]
        if c in " \t":
            rest = s[i:].strip()
            if rest and not rest.startswith("#"):
                raise _NeedsShell
            break
        if c == "'":
            j = s.find("'", i + 1)
            if j < 0:
                raise _NeedsShell
            out.append(s[i + 1:j])
            i = j + 1
        elif c == '"':
            i += 1
            while True:
                if i >= n:
                    raise _NeedsShell
                c = s[i]
                if c == '"':
                    i += 1
                    break
                if c in "$`":
                    raise _NeedsShell
                if c == "\\" and i + 1 < n and s[i + 1] in '$`"\\':
                    out.append(s[i + 1])
                    i += 2
                    continue
                out.append(c)
                i += 1
        elif s.startswith("$'", i):
            i = _ansi_c(s, i + 2, out)
        elif c == "\\":
            if i + 1 >= n:
                raise _NeedsShell
            out.append(s[i + 1])
            i += 2
        elif c in "$`;&|<>()":
            raise _NeedsShell
        else:
            out.append(c)
            i += 1
    return "".join(out)


def _ansi_c(s: str, i: int, out: list) -> int:
    """Append the $'...' string starting at s[i] to out; return the index past it."""
    n = len(s)
    while i < n:
        c = s[i]
        if c == "'":
            return i + 1
        if c != "\\":
            out.append(c)
            i += 1
            continue
        if i + 1 >= n:
            raise _NeedsShell
        e = s[i + 1]
        if e in _ANSI_C:
            out.append(_ANSI_C[e])
            i += 2
        elif e == "x":
            m = re.match(r"[0-9a-fA-F]{1,2}", s[i + 2:])
            if not m:
                raise _NeedsShell
            out.append(chr(int(m.group(0), 16)))
            i += 2 + len(m.group(0))
        elif e in "01234567":
            m = re.match(r"[0-7]{1,3}", s[i + 1:])
            out.append(chr(int(m.group(0), 8)))
            i += 1 + len(m.group(0))
        else:
            raise _NeedsShell
    raise _NeedsShell


def _read_with_bash(path: Path, lines: list[str]) -> dict[str, str]:
    names = sorted({m.group(1) for line in lines if (m := _ASSIGN.match(line))})
    if not names:
        return {}
    script = ('source "$1" >/dev/null 2>&1; shift; '
              'for k; do if [[ -v $k ]]; then printf "%s\\0%s\\0" "$k" "${!k}"; fi; done')
    env = {k: v for k, v in os.environ.items() if k not in names}
    try:
        r = subprocess.run(["bash", "--noprofile", "--norc", "-c", script, "_", str(path), *names],
                           env=env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL, timeout=10)
    except (OSError, subprocess.TimeoutExpired):
        return {}
    fields = r.stdout.decode(errors="replace").split("\0")
    return dict(zip(fields[0:-1:2], fields[1::2]))
