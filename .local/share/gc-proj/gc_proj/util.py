from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Optional, Sequence


def run(args: Sequence[str], *, cwd=None, input: Optional[str] = None, timeout=None,
        env=None, quiet: bool = True) -> subprocess.CompletedProcess:
    """Run args with stdout captured. A missing program or a timeout counts as failure."""
    try:
        return subprocess.run(
            list(args), cwd=cwd, input=input, timeout=timeout, env=env, text=True,
            stdin=None if input is not None else subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL if quiet else None)
    except (OSError, subprocess.TimeoutExpired):
        return subprocess.CompletedProcess(list(args), 127, "", "")


def out(args: Sequence[str], **kw) -> str:
    """stdout of args without its trailing newline, or "" if it failed."""
    r = run(args, **kw)
    if r.returncode != 0:
        return ""
    return r.stdout.rstrip("\n")


def ok(args: Sequence[str], **kw) -> bool:
    return run(args, **kw).returncode == 0


def call(args: Sequence[str], *, cwd=None, env=None) -> int:
    """Run args attached to the terminal and return its exit status."""
    try:
        return subprocess.call(list(args), cwd=cwd, env=env)
    except OSError as e:
        print(f"error: {args[0]}: {e.strerror}", file=sys.stderr)
        return 127


def netrc_entry(host: str) -> tuple[str, str]:
    """(login, password) for host in ~/.netrc, either empty if missing."""
    try:
        tokens = Path("~/.netrc").expanduser().read_text().split()
    except OSError:
        return "", ""
    login = password = ""
    machine = None
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if t == "machine" and i + 1 < len(tokens):
            machine = tokens[i + 1]
            i += 2
        elif t == "default":
            machine = None
            i += 1
        elif machine == host and t in ("login", "password") and i + 1 < len(tokens):
            if t == "login":
                login = tokens[i + 1]
            else:
                password = tokens[i + 1]
            i += 2
        else:
            i += 1
    return login, password


class HttpError(Exception):
    pass


def http_json(url: str, *, headers: dict, method: str = "GET", body=None, timeout: float = 15):
    data = json.dumps(body).encode() if body is not None else None
    hdrs = {"Accept": "application/json", **headers}
    if data is not None:
        hdrs["Content-Type"] = "application/json"
    req = urllib.request.Request(url, method=method, data=data, headers=hdrs)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        raise HttpError(f"{e.code} {e.read().decode(errors='replace')}") from None
    except (urllib.error.URLError, OSError, ValueError) as e:
        raise HttpError(str(getattr(e, "reason", e))) from None


def write_atomic(path: Path, text: str) -> None:
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


def self_command(*args: str) -> list[str]:
    """Command line that runs this program again."""
    return [sys.executable, "-m", "gc_proj", *args]


def self_env(**extra: str) -> dict:
    env = dict(os.environ)
    pkg_parent = str(Path(__file__).resolve().parent.parent)
    env["PYTHONPATH"] = os.pathsep.join(p for p in (pkg_parent, env.get("PYTHONPATH", "")) if p)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env.update(extra)
    return env
