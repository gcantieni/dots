"""Matching a project to its branch, changes, review request and merge request."""
from __future__ import annotations

from typing import Optional

from . import trees, worktrees
from .project import Project
from .services import MergeRequest, Review
from .util import out


def project_branch(cfg, p: Project) -> str:
    """branch=, its tree's branch, or the branch checked out in its dir."""
    b = p.get("branch")
    tree = p.get("tree")
    if not b and tree and trees.enabled(cfg):
        b = trees.branch(cfg, tree, p.get("tree_repo"))
    if not b:
        d = p.working_dir()
        # A slot's branch belongs to whichever project activated it.
        if d and d != str(p.path) and not worktrees.in_pool(cfg, d):
            b = out(["git", "-C", d, "symbolic-ref", "-q", "--short", "HEAD"])
    if b in ("main", "master", "trunk", cfg.text("worktrees.main_branch")):
        return ""
    return b


def find_review(p: Project, reviews: list[Review], changes: list[str]) -> str:
    """review=, else my pending review posted from one of the project's
    changes (ids from plugins), else one whose summary starts with its Jira key."""
    review = p.get("review")
    if review:
        return review[2:] if review.startswith("r/") else review
    mine = set(changes)
    key = p.jira_key
    by_key = ""
    for r in reviews:
        if r.change in mine:
            return r.id
        if not by_key and key and r.summary.startswith(key):
            by_key = r.id
    return by_key


def find_mr(p: Project, mrs: list[MergeRequest], branch: str) -> Optional[tuple[str, str]]:
    """(iid, url) from mr=, else my open merge request from the project's
    branch or with its Jira key in the title."""
    mr = p.get("mr")
    if mr:
        return mr.rstrip("/").rsplit("/", 1)[-1], mr
    key = p.jira_key
    for m in mrs:
        if (branch and m.source_branch == branch) or (key and key in m.title):
            return m.iid, m.url
    return None
