"""Throwaway trees for tree= projects, made and dropped by configured commands.

The commands run in bash with {name}, {branch} and {repo} replaced by the
shell-quoted tree name, branch, and the git repo of the project's area (kept in
the project's tree_repo key, so one config makes trees in any area's repo).
trees.new prints the tree's path as its last line of output (else it's trees.path).
"""
from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import tempfile
import time

from . import tmux, ui
from .util import call, ok, out


def enabled(cfg) -> bool:
    return bool(cfg["trees.new"] and cfg["trees.path"])


def uses_repo(cfg) -> bool:
    return any("{repo}" in cfg.text(k) for k in ("trees.new", "trees.drop", "trees.path", "trees.exists"))


def area_repo(d: str) -> str:
    """The top of the git repo holding d, or ""."""
    return out(["git", "-C", d, "rev-parse", "--show-toplevel"]) if d and os.path.isdir(d) else ""


def _command(template: str, name: str, branch: str = "", repo: str = "") -> list[str]:
    cmd = (template.replace("{name}", shlex.quote(name)).replace("{branch}", shlex.quote(branch))
           .replace("{repo}", shlex.quote(repo)))
    return ["bash", "-c", cmd]


def path(cfg, name: str, repo: str = "") -> str:
    return os.path.expanduser(cfg.text("trees.path").replace("{name}", name).replace("{repo}", repo))


def exists(cfg, name: str, repo: str = "") -> bool:
    if cfg["trees.exists"]:
        return ok(_command(cfg.text("trees.exists"), name, repo=repo))
    return os.path.isdir(path(cfg, name, repo))


def new_tree(cfg, name: str, branch: str, repo: str = "") -> str:
    """Make tree name on a new branch and return the dir to work in."""
    if not ok(["git", "check-ref-format", "--branch", branch]):
        raise ui.Fail(f"{branch} is not a valid branch name")
    r = subprocess.run(_command(cfg.text("trees.new"), name, branch, repo), stdin=subprocess.DEVNULL,
                       stdout=subprocess.PIPE, text=True)
    if r.returncode != 0:
        raise ui.Fail(f"couldn't make tree {name}")
    lines = r.stdout.strip().splitlines()
    d = os.path.expanduser(lines[-1].strip()) if lines else path(cfg, name, repo)
    if not os.path.isdir(d):
        raise ui.Fail(f"tree {name} isn't at {d}")
    subdir = cfg.text("sandbox_subdir")
    if subdir and os.path.isdir(os.path.join(d, subdir)):
        d = os.path.join(d, subdir)
    return d


def branch(cfg, name: str, repo: str = "") -> str:
    return out(["git", "-C", path(cfg, name, repo), "symbolic-ref", "-q", "--short", "HEAD"])


def remote_url(cfg, name: str, repo: str = "") -> str:
    return out(["git", "-C", path(cfg, name, repo), "remote", "get-url", "origin"])


def _within(p: str, root: str) -> bool:
    return p == root or p.startswith(root + "/")


def _sessions_running(sids: set[int]) -> bool:
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/stat") as f:
                fields = f.read().rpartition(")")[2].split()
        except OSError:
            continue
        if fields[0] != "Z" and int(fields[3]) in sids:
            return True
    return False


def _wait_for_sessions(sids: set[int], timeout: float = 5.0) -> None:
    """Wait for every process in the sessions led by sids to exit, since
    tmux kill-pane only hangs them up."""
    deadline = time.monotonic() + timeout
    while _sessions_running(sids) and time.monotonic() < deadline:
        time.sleep(0.1)


def cleanup(cfg, name: str, repo: str = "") -> bool:
    """Offer to drop tree name, first closing the tmux panes working in it,
    which would keep it busy."""
    if not exists(cfg, name, repo):
        print(f"tree {name} is already gone")
        return True
    if not cfg["trees.drop"]:
        print(f"no trees.drop command; drop {name} by hand")
        return True
    if not ui.confirm(f"drop tree {name}?", True):
        return True
    root = path(cfg, name, repo)
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
        sids = {tmux.pane_pid(pid) for pid, _, _ in busy} - {0}
        for pid, _, _ in busy:
            call(["tmux", "kill-pane", "-t", pid])
        _wait_for_sessions(sids)

    return call(_command(cfg.text("trees.drop"), name, repo=repo)) == 0


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
