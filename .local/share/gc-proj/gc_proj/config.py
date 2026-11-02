"""Settings: built-in defaults, then config.toml and config.local.toml, then
GC_PROJ_<SECTION>_<KEY> environment variables.

Everything site-specific is off until configured, so the core (projects,
areas, states, the board, tmux sessions) works anywhere.
"""
from __future__ import annotations

import getpass
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

DEFAULTS: dict[str, Any] = {
    "root": "~/proj",
    # Glob of sandboxes to pick from when a new project has no dir.
    "sandboxes": "",
    "sandbox_subdir": "",
    "branch_prefix": getpass.getuser() + "/",
    "new_tree": False,
    "area_stale_days": 21,
    # A git repo whose worktrees ("slots") hold the branches of branch= projects.
    "worktrees.repo": "",
    "worktrees.subdir": "",
    "worktrees.main_branch": "main",
    # Ref holding submitted work, if not the main branch.
    "worktrees.upstream": "",
    # Commands that make and drop tree= projects' trees; see trees.py.
    "trees.new": "",
    "trees.drop": "",
    "trees.path": "",
    "trees.exists": "",
    "jira.url": "",
    "jira.project": "",
    "jira.type": "Task",
    "jira.user": "",
    "reviewboard.url": "",
    "reviewboard.user": getpass.getuser(),
    "gitlab.url": "",
}

LEGACY_ENV = {"MAIN_GIT_REPO": "worktrees.repo"}


def env_name(key: str) -> str:
    return "GC_PROJ_" + key.replace(".", "_").upper()


def config_dir() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME") or "~/.config").expanduser() / "gc-proj"


def config_files() -> list[Path]:
    return [config_dir() / "config.toml", config_dir() / "config.local.toml"]


class Config:
    def __init__(self, values: dict[str, Any], sources: dict[str, str]):
        self._values = values
        self.sources = sources

    def __getitem__(self, key: str) -> Any:
        return self._values[key]

    def text(self, key: str) -> str:
        return str(self._values[key])

    def path(self, key: str) -> Path | None:
        v = self._values[key]
        if not v:
            return None
        return Path(os.path.expandvars(os.path.expanduser(str(v))))

    def items(self):
        return self._values.items()

    @property
    def root(self) -> Path:
        return self.path("root")

    @property
    def notes_file(self) -> Path:
        return self.root / "notes.md"

    @property
    def archive_root(self) -> Path:
        return self.root / "archive"

    @property
    def cache_dir(self) -> Path:
        return Path(os.environ.get("XDG_CACHE_HOME") or "~/.cache").expanduser() / "gc-proj"


def _convert(key: str, value: Any) -> Any:
    default = DEFAULTS[key]
    if isinstance(default, bool):
        if isinstance(value, str):
            return value.strip().lower() not in ("", "0", "no", "false", "off")
        return bool(value)
    if isinstance(default, int):
        try:
            return int(value)
        except (TypeError, ValueError):
            return default
    return str(value)


def _flatten(data: dict, prefix: str = "") -> dict[str, Any]:
    flat = {}
    for k, v in data.items():
        if isinstance(v, dict):
            flat.update(_flatten(v, f"{prefix}{k}."))
        else:
            flat[prefix + k] = v
    return flat


def _parse_toml(text: str) -> dict:
    try:
        import tomllib
    except ImportError:
        return _parse_simple_toml(text)
    return tomllib.loads(text)


def _parse_simple_toml(text: str) -> dict:
    """The TOML subset of [sections] and key = string, number or boolean."""
    data: dict = {}
    table = data
    for n, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = re.fullmatch(r"\[([A-Za-z0-9_.-]+)\]", line)
        if m:
            table = data.setdefault(m.group(1), {})
            continue
        m = re.fullmatch(r"([A-Za-z0-9_-]+)\s*=\s*(.+?)(\s+#.*)?", line)
        if not m:
            raise ValueError(f"line {n}: can't parse {line!r}")
        raw = m.group(2)
        if raw.startswith("'") and raw.endswith("'"):
            table[m.group(1)] = raw[1:-1]
        else:
            table[m.group(1)] = json.loads(raw)
    return data


def load() -> Config:
    values = dict(DEFAULTS)
    sources = {k: "default" for k in DEFAULTS}
    for f in config_files():
        if not f.is_file():
            continue
        try:
            data = _flatten(_parse_toml(f.read_text()))
        except (OSError, ValueError) as e:
            print(f"warning: ignoring {f}: {e}", file=sys.stderr)
            continue
        for k, v in data.items():
            if k not in DEFAULTS:
                print(f"warning: {f}: unknown setting {k}", file=sys.stderr)
                continue
            values[k] = _convert(k, v)
            sources[k] = str(f)
    for env, key in LEGACY_ENV.items():
        if env in os.environ:
            values[key] = _convert(key, os.environ[env])
            sources[key] = "$" + env
    for key in DEFAULTS:
        env = env_name(key)
        if env in os.environ:
            values[key] = _convert(key, os.environ[env])
            sources[key] = "$" + env
    return Config(values, sources)
