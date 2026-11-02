"""A pool of built git worktrees ("slots") of one repo, shared by branch= projects."""
from __future__ import annotations

import os
import subprocess
import tempfile
from functools import lru_cache
from typing import Optional

from . import plugins, ui
from .util import call, ok, out, run


def enabled(cfg) -> bool:
    return bool(cfg["worktrees.repo"])


def repo(cfg) -> str:
    return str(cfg.path("worktrees.repo"))


def main_branch(cfg) -> str:
    return cfg.text("worktrees.main_branch")


def upstream(cfg) -> str:
    return cfg.text("worktrees.upstream") or main_branch(cfg)


def git(path: str, *args: str, **kw):
    return run(["git", "-C", path, *args], **kw)


def git_out(path: str, *args: str, **kw) -> str:
    return out(["git", "-C", path, *args], **kw)


@lru_cache(maxsize=None)
def _worktrees(repo_path: str) -> tuple[tuple[str, str], ...]:
    result = []
    wt = None
    for line in git_out(repo_path, "worktree", "list", "--porcelain").splitlines():
        if line.startswith("worktree "):
            wt = line[len("worktree "):]
            result.append((wt, ""))
        elif line.startswith("branch refs/heads/") and wt is not None:
            result[-1] = (wt, line[len("branch refs/heads/"):])
    return tuple(result)


def worktrees(cfg) -> tuple[tuple[str, str], ...]:
    """(path, branch) for each worktree; branch is "" when detached."""
    return _worktrees(repo(cfg))


def forget() -> None:
    """Drop what's known about the worktrees after checking out branches."""
    _worktrees.cache_clear()


def branch_slot(cfg, branch: str) -> str:
    for path, b in worktrees(cfg):
        if b == branch:
            return path
    return ""


@lru_cache(maxsize=None)
def _common_dir(path: str) -> str:
    return git_out(path, "rev-parse", "--path-format=absolute", "--git-common-dir")


def in_pool(cfg, path: str) -> bool:
    """True if path is inside one of the slots."""
    if not enabled(cfg) or not path:
        return False
    common = _common_dir(path)
    return bool(common) and common == _common_dir(repo(cfg))


def valid_branch_name(name: str) -> bool:
    return ok(["git", "check-ref-format", "--branch", name])


def branch_exists(cfg, branch: str) -> bool:
    return git(repo(cfg), "show-ref", "--verify", "-q", f"refs/heads/{branch}").returncode == 0


def is_dirty(path: str) -> bool:
    return bool(git_out(path, "status", "--porcelain", "--untracked-files=no"))


def head_branch(path: str) -> str:
    return git_out(path, "symbolic-ref", "-q", "--short", "HEAD")


def base(cfg, path: str, rev: str) -> str:
    """The upstream commit rev is based on."""
    return git_out(path, "merge-base", rev, upstream(cfg))


def rev(cfg, name: str) -> str:
    return git_out(repo(cfg), "rev-parse", name)


def pick_clean_slot(cfg, exclude: str) -> str:
    """A slot with no uncommitted changes other than exclude; asks if several."""
    clean = []
    for path, branch in worktrees(cfg):
        if path == exclude or is_dirty(path):
            continue
        clean.append(f"{path}  {branch or '(detached)'}")
    if not clean:
        other = "other " if exclude else ""
        raise ui.Fail(f"no {other}slot without uncommitted changes; commit or stash in one first")
    if len(clean) == 1:
        pick = clean[0]
    else:
        pick = ui.fzf(clean, "--prompt", "slot> ")
        if not pick:
            raise ui.Cancelled()
    return pick.split("  ", 1)[0]


def rebase_for_slot(cfg, slot: str, branch: str) -> bool:
    """Rebase branch onto main first if slot is built on main and branch is
    older, so checking it out rewrites only the files the branches touch.
    False if the user declines to check out a branch that conflicts with main."""
    r = repo(cfg)
    main = main_branch(cfg)
    main_rev = rev(cfg, main)
    if base(cfg, slot, "HEAD") != main_rev:
        return True
    b = base(cfg, r, branch)
    if b == main_rev or not git(r, "merge-base", "--is-ancestor", b, main).returncode == 0:
        return True
    reason = plugins.first("skip_rebase", cfg, r, branch)
    if reason:
        print(f"not rebasing {branch} onto {main} ({reason})")
        return True
    print(f"rebasing {branch} onto {main}")
    if call(["git", "-C", r, "replay", "--ref-action=update", "--onto", main, f"{b}..{branch}"]) == 0:
        print(f"rebased {branch}; the previous tip is {branch}@{{1}}")
        return True
    if ui.confirm(f"{branch} conflicts with {main}; resolve in a scratch worktree?", True):
        if rebase_in_scratch(cfg, branch, b):
            return True
    return ui.confirm(f"check out {branch} on its old base anyway (slow rebuild)?", False)


def rebase_in_scratch(cfg, branch: str, b: str) -> bool:
    """Rebase branch onto main in a temporary worktree that checks out only
    the files the branch touches since b, so no built slot is disturbed.
    Drops into a shell there to resolve conflicts."""
    r = repo(cfg)
    main = main_branch(cfg)
    wt = tempfile.mkdtemp(prefix=f"rebase-{branch.replace('/', '-')}.")
    if call(["git", "-C", r, "worktree", "add", "-q", "--no-checkout", wt, branch]) != 0:
        os.rmdir(wt)
        return False
    try:
        files = git_out(r, "diff", "--name-only", "--no-renames", b, branch).splitlines()
        sparse = "".join(f"/{f}\n" for f in files)
        if (git(wt, "sparse-checkout", "set", "--no-cone", "--stdin", input=sparse).returncode != 0
                or call(["git", "-C", wt, "checkout", "-q"]) != 0):
            return False
        if call(["git", "-C", wt, "rebase", "-q", main]) != 0:
            print()
            print(f"resolve the conflicts in {wt}, then run git rebase --continue.")
            print("exit the shell when the rebase is done; exiting mid-rebase aborts it.")
            with open("/dev/tty") as tty_in:
                subprocess.call([os.environ.get("SHELL", "bash"), "-i"], cwd=wt, stdin=tty_in)
            merge_dir = git_out(wt, "rev-parse", "--path-format=absolute", "--git-path", "rebase-merge")
            if merge_dir and os.path.isdir(merge_dir):
                call(["git", "-C", wt, "rebase", "--abort"])
                print(f"rebase aborted; {branch} is unchanged")
    finally:
        call(["git", "-C", r, "worktree", "remove", "--force", wt])
    if git(r, "merge-base", "--is-ancestor", main, branch).returncode != 0:
        return False
    print(f"rebased {branch}; the previous tip is {branch}@{{1}}")
    return True


def activate(cfg, branch: str, subdir: str, move: bool) -> Optional[str]:
    """Check branch out in a clean slot, or find the one it's in; returns the dir to work in."""
    main = main_branch(cfg)
    src = branch_slot(cfg, branch)
    name = os.path.basename

    def workdir(slot):
        return os.path.join(slot, subdir) if subdir else slot

    if src and not move:
        print(f"{name(src)} is already on {branch}")
        if base(cfg, src, "HEAD") != rev(cfg, main):
            print(f"hint: {name(src)} isn't on {main}; gc-proj activate --move puts {branch} in another slot")
        return workdir(src)

    reason = plugins.first("worktrees_busy", cfg, repo(cfg))
    if reason:
        raise ui.Fail(reason)
    if src and is_dirty(src):
        raise ui.Fail(f"{branch} has uncommitted changes in {name(src)}; commit or stash them first")
    slot = pick_clean_slot(cfg, src)

    current = head_branch(slot) or "(detached)"
    if branch_exists(cfg, branch):
        if src:
            if call(["git", "-C", src, "checkout", "-q", "--detach"]) != 0:
                raise ui.Fail(f"couldn't detach {name(src)}")
            print(f"{name(src)}: detached from {branch}")
        if not rebase_for_slot(cfg, slot, branch) or call(["git", "-C", slot, "checkout", "-q", branch]) != 0:
            if src and call(["git", "-C", src, "checkout", "-q", branch]) == 0:
                print(f"{name(src)}: back on {branch}")
            raise ui.Cancelled()
    else:
        if not ui.confirm(f"branch {branch} doesn't exist; create it from {main}?", False):
            raise ui.Cancelled()
        if call(["git", "-C", slot, "checkout", "-q", "-b", branch, main]) != 0:
            raise ui.Fail(f"couldn't create {branch}")
    forget()
    print(f"{name(slot)}: {current} -> {branch}")
    return workdir(slot)


def cleanup_branch(cfg, branch: str) -> None:
    """Offer to delete branch, detaching any slot that has it checked out."""
    r = repo(cfg)
    if not branch_exists(cfg, branch):
        print(f"branch {branch} no longer exists")
        return
    unsubmitted = []
    for line in git_out(r, "cherry", "-v", upstream(cfg), branch).splitlines():
        if line.startswith("+ "):
            unsubmitted.append(line.split(" ", 2)[2] if line.count(" ") >= 2 else line)
    if unsubmitted:
        print(f"branch {branch} has commits not in {upstream(cfg)}:")
        for s in unsubmitted:
            print(f"  {s}")
        yes = ui.confirm(f"delete branch {branch} anyway?", False)
    else:
        yes = ui.confirm(f"delete branch {branch}?", True)
    if not yes:
        return
    slot = branch_slot(cfg, branch)
    if slot:
        if is_dirty(slot):
            ui.err(f"error: {os.path.basename(slot)} has uncommitted changes on {branch}; not deleting it")
            return
        if call(["git", "-C", slot, "checkout", "-q", "--detach", main_branch(cfg)]) != 0:
            return
        print(f"{os.path.basename(slot)}: detached at {main_branch(cfg)}")
    call(["git", "-C", r, "branch", "-D", branch])
    forget()
