"""Throwaway trees for tree= projects, made and dropped by configured commands.

The commands run in bash with {name} and {branch} replaced by the shell-quoted
tree name and branch. trees.new prints the tree's path as its last line of
output (else it's trees.path).
"""
from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import tempfile

from . import tmux, ui
from .util import call, ok, out


def enabled(cfg) -> bool:
    return bool(cfg["trees.new"] and cfg["trees.path"])


def _command(template: str, name: str, branch: str = "") -> list[str]:
    cmd = template.replace("{name}", shlex.quote(name)).replace("{branch}", shlex.quote(branch))
    return ["bash", "-c", cmd]


def path(cfg, name: str) -> str:
    return os.path.expanduser(cfg.text("trees.path").replace("{name}", name))


def exists(cfg, name: str) -> bool:
    if cfg["trees.exists"]:
        return ok(_command(cfg.text("trees.exists"), name))
    return os.path.isdir(path(cfg, name))


def new_tree(cfg, name: str, branch: str) -> str:
    """Make tree name on a new branch and return the dir to work in."""
    if not ok(["git", "check-ref-format", "--branch", branch]):
        raise ui.Fail(f"{branch} is not a valid branch name")
    r = subprocess.run(_command(cfg.text("trees.new"), name, branch), stdin=subprocess.DEVNULL,
                       stdout=subprocess.PIPE, text=True)
    if r.returncode != 0:
        raise ui.Fail(f"couldn't make tree {name}")
    lines = r.stdout.strip().splitlines()
    d = os.path.expanduser(lines[-1].strip()) if lines else path(cfg, name)
    if not os.path.isdir(d):
        raise ui.Fail(f"tree {name} isn't at {d}")
    subdir = cfg.text("sandbox_subdir")
    if subdir and os.path.isdir(os.path.join(d, subdir)):
        d = os.path.join(d, subdir)
    return d


def branch(cfg, name: str) -> str:
    return out(["git", "-C", path(cfg, name), "symbolic-ref", "-q", "--short", "HEAD"])


def remote_url(cfg, name: str) -> str:
    return out(["git", "-C", path(cfg, name), "remote", "get-url", "origin"])


def _within(p: str, root: str) -> bool:
    return p == root or p.startswith(root + "/")


def cleanup(cfg, name: str) -> bool:
    """Offer to drop tree name, first closing the tmux panes working in it,
    which would keep it busy."""
    if not exists(cfg, name):
        print(f"tree {name} is already gone")
        return True
    if not cfg["trees.drop"]:
        print(f"no trees.drop command; drop {name} by hand")
        return True
    if not ui.confirm(f"drop tree {name}?", True):
        return True
    root = path(cfg, name)
    os.chdir("/")
    try:
        parent_cwd = os.readlink(f"/proc/{os.getppid()}/cwd")
    except OSError:
        parent_cwd = ""
    if _within(parent_cwd, root):
        ui.err(f"error: this shell is in {name}; cd out of it (the gc-proj shell function does) and rerun")
        return False

    me = os.environ.get("TMUX_PANE", "")
    busy = [(pid, where, cmd) for pid, where, cmd, p in tmux.panes() if pid != me and _within(p, root)]
    if busy:
        print(f"tmux panes in {name}:")
        for _, where, cmd in busy:
            print(f"  {where}  {cmd}")
        if not ui.confirm("close them?", True):
            print(f"not dropping {name} while panes use it")
            return False
        for pid, _, _ in busy:
            call(["tmux", "kill-pane", "-t", pid])

    return call(_command(cfg.text("trees.drop"), name)) == 0


def cleanup_remote_branch(url: str, branch_name: str, default: bool) -> bool:
    """Offer to delete branch_name from remote url. Works from a scratch repo,
    so it works after the tree that pushed it is gone."""
    if not ok(["git", "ls-remote", "--exit-code", "--heads", url, branch_name]):
        print(f"remote branch {branch_name} is already gone")
        return True
    if not ui.confirm(f"delete remote branch {branch_name}?", default):
        return True
    scratch = tempfile.mkdtemp()
    try:
        return (call(["git", "-C", scratch, "init", "-q"]) == 0
                and call(["git", "-C", scratch, "push", "-q", url, "--delete", branch_name]) == 0)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
