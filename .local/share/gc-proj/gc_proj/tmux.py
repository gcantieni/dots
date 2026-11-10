from __future__ import annotations

import os
from typing import Optional

from .util import ok, out, run


def inside() -> bool:
    return bool(os.environ.get("TMUX"))


def session_name(project_name: str) -> str:
    return project_name.replace(".", "_")


def has_session(name: str) -> bool:
    return ok(["tmux", "has-session", f"-t={name}"])


def current_session() -> str:
    return out(["tmux", "display-message", "-p", "#S"])


def session_proj() -> Optional[str]:
    """PROJ in the environment of the session holding this pane."""
    if not inside():
        return None
    args = ["tmux", "show-environment"]
    if os.environ.get("TMUX_PANE"):
        args += ["-t", os.environ["TMUX_PANE"]]
    line = out(args + ["PROJ"])
    if line.startswith("PROJ=") and len(line) > 5:
        return line[5:]
    return None


def session_activity() -> dict[str, int]:
    activity = {}
    for line in out(["tmux", "list-sessions", "-F", "#{session_name} #{session_activity}"]).splitlines():
        name, _, t = line.rpartition(" ")
        if name:
            activity[name] = int(t) if t.isdigit() else 0
    return activity


def origin_pane() -> str:
    """The pane a popup was opened from, else the current pane."""
    return (os.environ.get("GC_PROJ_PANE") or os.environ.get("TMUX_PANE")
            or out(["tmux", "display-message", "-p", "#{pane_id}"]))


def pane_path(pane: str) -> str:
    return out(["tmux", "display-message", "-p", "-t", pane, "#{pane_current_path}"])


def panes() -> list[tuple[str, str, str, str]]:
    """Every pane as (id, session:window.pane, command, path)."""
    fmt = "#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_command}\t#{pane_current_path}"
    result = []
    for line in out(["tmux", "list-panes", "-a", "-F", fmt]).splitlines():
        parts = line.split("\t")
        if len(parts) == 4:
            result.append(tuple(parts))
    return result


def pane_pid(pane: str) -> int:
    pid = out(["tmux", "display-message", "-p", "-t", pane, "#{pane_pid}"])
    return int(pid) if pid.isdigit() else 0


def set_session_dir(path: str, session: str = "") -> None:
    """Make path the default dir for new windows in session (default the current one)."""
    if not inside():
        return
    session = session or current_session()
    socket = os.environ["TMUX"].split(",", 1)[0]
    env = {k: v for k, v in os.environ.items() if k != "TMUX"}
    run(["tmux", "-S", socket, "attach-session", "-t", session, "-c", path, ";", "detach-client"], env=env)


def switch_away_from(session: str) -> None:
    """Move this client to the most recently attached other session."""
    best, best_t = "", -1
    for line in out(["tmux", "list-sessions", "-F", "#{session_last_attached} #{session_name}"]).splitlines():
        t, _, name = line.partition(" ")
        if name != session and t.isdigit() and int(t) > best_t:
            best, best_t = name, int(t)
    if best:
        run(["tmux", "switch-client", "-t", best])


def open_session(name: str, start_dir: str, proj: str) -> int:
    """Switch to session name, making it in start_dir with PROJ=proj if needed."""
    if not has_session(name):
        r = run(["tmux", "new-session", "-ds", name, "-c", start_dir, "-e", f"PROJ={proj}"], quiet=False)
        if r.returncode != 0:
            return r.returncode
    if inside() and ok(["tmux", "switch-client", "-t", f"={name}"]):
        return 0
    os.execvp("tmux", ["tmux", "attach-session", "-t", f"={name}"])
