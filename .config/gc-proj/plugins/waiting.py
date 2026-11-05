"""Waiting: what a waiting project is waiting on, and for how long, on its board card.

    gc-proj set state=waiting waiting="landlord reply"

Setting waiting= alone also moves the project to waiting. waiting_since is stamped
the first time the board sees it waiting (from the project file's last write, which
is when the state was set), and both keys are cleared once it leaves waiting.
"""
from __future__ import annotations

import time

from gc_proj import projfile
from gc_proj.plugins import Info

STAMP = "%Y-%m-%d %H:%M"


def _age(since: str) -> str:
    try:
        secs = time.time() - time.mktime(time.strptime(since, STAMP))
    except ValueError:
        return ""
    days = int(secs // 86400)
    if days < 1:
        return "today"
    if days < 14:
        return f"{days}d"
    if days < 60:
        return f"{days // 7}w"
    return f"{days // 30}mo"


def project_info(cfg, project, ctx, branch):
    state = project.get("state")
    what, since = project.get("waiting"), project.get("waiting_since")

    if state != "waiting" and not (what and not since):
        if since or what:
            # It left waiting (on the board or with gc-proj state), so the note is stale.
            project.update({"waiting": "", "waiting_since": ""})
        return None

    updates = {}
    if state != "waiting":
        updates["state"] = "waiting"
    if not since:
        try:
            mtime = (project.path / projfile.FILE).stat().st_mtime
        except OSError:
            mtime = time.time()
        since = updates["waiting_since"] = time.strftime(STAMP, time.localtime(mtime))
    if updates:
        project.update(updates)

    age = _age(since)
    return Info(detail=["⏳ " + " · ".join(x for x in (age, what) if x)], state="waiting")
