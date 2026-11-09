"""Plugins: Python files in ~/.config/gc-proj/plugins, each defining any of these hooks.

  collect(cfg, projects) -> ctx
      Once per board refresh, in a worker thread. ctx goes to project_info.
  project_info(cfg, project, ctx, branch) -> Info
      What the plugin adds to a project's card, and the ids of its changes
      (matched against review requests). links maps a key to (label, url) for
      the board's o.
  checkin_status(cfg, project) -> (submitted, line) or None
      For done: whether the project's work is in, and a line saying how it knows.
  cleanup(cfg, project, branch)
      A step of done, after the review step, for the plugin's own leftovers.
  worktrees_busy(cfg, repo) -> reason or ""
      Why branches can't be checked out in the worktrees right now.
  skip_rebase(cfg, repo, branch) -> reason or ""
      Why activate shouldn't rebase branch onto the main branch.
  prune_details(cfg, project) -> lines
      Extra lines for the project's card in prune.

A plugin that reads project keys of its own lists them in KEYS, a dict of key to
description, for gc-proj keys and help.
"""
from __future__ import annotations

import importlib.util
import sys
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Any, Optional

from . import config


@dataclass
class Info:
    changes: list[str] = field(default_factory=list)
    detail: list[str] = field(default_factory=list)
    state: Optional[str] = None
    color: Optional[str] = None
    links: dict[str, tuple[str, str]] = field(default_factory=dict)


@lru_cache(maxsize=None)
def loaded() -> tuple:
    mods = []
    plugin_dir = config.config_dir() / "plugins"
    if not plugin_dir.is_dir():
        return ()
    for path in sorted(plugin_dir.glob("*.py")):
        name = f"gc_proj_plugin_{path.stem}"
        try:
            spec = importlib.util.spec_from_file_location(name, path)
            mod = importlib.util.module_from_spec(spec)
            sys.modules[name] = mod
            spec.loader.exec_module(mod)
        except Exception as e:
            print(f"warning: skipping plugin {path}: {e}", file=sys.stderr)
            continue
        mods.append(mod)
    return tuple(mods)


def with_hook(hook: str) -> list:
    return [m for m in loaded() if hasattr(m, hook)]


def call(hook: str, *args) -> list[Any]:
    """The results of hook from each plugin that has it."""
    return [getattr(m, hook)(*args) for m in with_hook(hook)]


def first(hook: str, *args) -> Any:
    """The first result of hook that isn't empty."""
    for m in with_hook(hook):
        r = getattr(m, hook)(*args)
        if r:
            return r
    return None


def merge(infos: list[Info]) -> Info:
    merged = Info()
    for i in infos:
        if i is None:
            continue
        merged.changes += i.changes
        merged.detail += i.detail
        merged.links.update(i.links)
        if i.state is not None:
            merged.state = i.state
        if i.color is not None:
            merged.color = i.color
    return merged


def collect(cfg, projects) -> list:
    return [(m, m.collect(cfg, projects) if hasattr(m, "collect") else None)
            for m in with_hook("project_info")]


def project_info(cfg, project, ctxs: list, branch: str) -> Info:
    """What the plugins know about project; ctxs is from collect."""
    return merge([m.project_info(cfg, project, ctx, branch) for m, ctx in ctxs])
