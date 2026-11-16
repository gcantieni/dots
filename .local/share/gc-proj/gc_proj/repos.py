"""Projects whose source is a git repo, cloned into dir when dir is missing."""
from __future__ import annotations

import os
import re
import sys

from .ui import Fail, tilde
from .util import call


def is_url(s: str) -> bool:
    return "://" in s or s.endswith(".git") or re.match(r"^[\w.-]+@[\w.-]+:", s) is not None


def default_dir(cfg, url: str) -> str:
    """<repos>/<name>, the name taken from the url's last component."""
    name = re.sub(r"\.git$", "", re.split(r"[/:]", url.rstrip("/"))[-1])
    if not name:
        raise Fail(f"can't name a dir for {url}")
    root = cfg.path("repos")
    if root is None:
        raise Fail("set repos in the config, or give a dir")
    return str(root / name)


def ensure(url: str, path: str) -> bool:
    """Clone url into path unless path exists. True if it cloned."""
    if os.path.exists(path):
        return False
    os.makedirs(os.path.dirname(path), exist_ok=True)
    print(f"cloning {url} into {tilde(path)}", file=sys.stderr)
    if call(["git", "clone", url, path]) != 0:
        raise Fail(f"couldn't clone {url}")
    return True


def ensure_project(project) -> bool:
    url = project.get("repo")
    d = project.get("dir")
    if not url or not d:
        return False
    return ensure(url, d)
