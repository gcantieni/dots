"""Finishing projects: done walks one through its cleanup, prune archives old ones."""
from __future__ import annotations

import datetime
import os
import subprocess

from . import links, plugins, services, tmux, trees, ui, worktrees
from .project import Project, all_projects, default_state, find_current, require_current
from .ui import BOLD, CYAN, DIM, GREEN, RESET, YELLOW, Fail


def append_note(cfg, name: str, note: str) -> None:
    today = datetime.date.today().isoformat()
    with open(cfg.notes_file, "a") as f:
        f.write(f"\n## {name} — closing note ({today})\n")
        if note:
            f.write(note + "\n")


def archive(cfg, p: Project) -> str:
    dest_dir = cfg.archive_root / str(datetime.date.today().year)
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / p.name
    if dest.exists():
        raise Fail(f"{dest} already exists")
    os.rename(p.path, dest)
    return str(dest)


def done_box(name: str, dest: str) -> str:
    shown = ui.tilde(dest)
    label_done, label_name, label_arch = "project done", "  name  ", "archived"
    width = max(len(shown) + len(label_arch) + 6, 40)
    line = "─" * width
    bar = f"{DIM}│{RESET}"
    return "\n".join([
        "",
        f"  {DIM}╭{line}╮{RESET}",
        f"  {bar}  {BOLD}{GREEN}{label_done}{RESET}{' ' * (width - len(label_done) - 2)}{bar}",
        f"  {bar}{' ' * width}{bar}",
        f"  {bar}  {DIM}{label_name}{RESET}  {BOLD}{name}{RESET}"
        f"{' ' * (width - len(label_name) - len(name) - 4)}{bar}",
        f"  {bar}  {DIM}{label_arch}{RESET}  {CYAN}{shown}{RESET}"
        f"{' ' * (width - len(label_arch) - len(shown) - 4)}{bar}",
        f"  {DIM}╰{line}╯{RESET}",
        "",
    ])


def cmd_done(cfg, a):
    p = require_current(cfg)
    name = p.name
    if name == "archive" or not name:
        raise Fail(f"refusing to archive '{name}'")
    if not p.path.is_dir():
        raise Fail(f"{p.path} is not a directory")
    if p.is_area:
        raise Fail(f"{name} is an area; gc-proj set kind= first if it really is finished")

    state = p.get("state")
    branch, tree, key = p.get("branch"), p.get("tree"), p.jira_key

    ui.phase("check-in")
    submitted = False
    status = plugins.first("checkin_status", cfg, p)
    if status:
        submitted, line = status
        print(line)
    elif state == "done":
        submitted = True
        print("state is done")
    else:
        print(f"state is {state or default_state(cfg)}")
    if not submitted and not ui.confirm("not checked in; clean up anyway?", False):
        return 1

    ui.phase("closing note")
    note = ui.prompt("closing note (enter to skip, e for $EDITOR): ")
    if note == "e":
        append_note(cfg, name, "")
        with open(cfg.notes_file, "a") as f:
            f.write("\n")
        editor = os.environ.get("EDITOR") or "vim"
        subprocess.call(["bash", "-c", f'{editor} + "$1"', "_", str(cfg.notes_file)])
    elif note:
        append_note(cfg, name, note)
    else:
        print("no closing note")

    if services.jira_enabled(cfg):
        ui.phase("Jira")
        if key:
            if ui.confirm(f"open {key} to close it?", True):
                print(ui.open_url(services.jira_browse(cfg, key)))
        else:
            print("no Jira key; set one with gc-proj set jira=KEY")

    proj_branch = links.project_branch(cfg, p)
    if services.rb_enabled(cfg) or services.gitlab_enabled(cfg):
        ui.phase("review")
    if services.rb_enabled(cfg):
        info = plugins.project_info(cfg, p, plugins.collect(cfg, [p]), proj_branch)
        review = links.find_review(p, services.pending_reviews(cfg), info.changes)
        if review:
            if ui.confirm(f"open r/{review} to close it?", True):
                print(ui.open_url(services.rb_review_url(cfg, review)))
        else:
            print("no pending review found; set one with gc-proj set review=N")
    if services.gitlab_enabled(cfg):
        mr = links.find_mr(p, services.pending_mrs(cfg), proj_branch)
        if mr and ui.confirm(f"open merge request !{mr[0]} to close it?", True):
            print(ui.open_url(mr[1]))

    tree_branch = tree_url = ""
    tree_repo = p.get("tree_repo")
    if tree and trees.enabled(cfg) and os.path.exists(os.path.join(trees.path(cfg, tree, tree_repo), ".git")):
        tree_branch = trees.branch(cfg, tree, tree_repo)
        tree_url = trees.remote_url(cfg, tree, tree_repo)

    plugins.call("cleanup", cfg, p, proj_branch)

    if tree and trees.enabled(cfg):
        ui.phase("tree")
        if not trees.cleanup(cfg, tree, tree_repo):
            raise Fail(f"tree {tree} not dropped; fix that and rerun gc-proj done")

    ui.phase("branch")
    if tree_branch and tree_url:
        if not trees.cleanup_remote_branch(tree_url, tree_branch, submitted):
            ui.err(f"couldn't delete remote branch {tree_branch}")
    elif branch and worktrees.enabled(cfg):
        worktrees.cleanup_branch(cfg, branch)
    else:
        print("no branch")

    ui.phase("archive")
    dest = archive(cfg, p)
    print(done_box(name, dest))

    session = p.session
    if tmux.has_session(session) and ui.confirm(f"kill tmux session '{session}'?", True):
        if tmux.inside() and tmux.current_session() == session:
            tmux.switch_away_from(session)
        subprocess.call(["tmux", "kill-session", "-t", f"={session}"])
    return 0


def show_card(cfg, p: Project, ts: int, idx: int, total: int) -> None:
    age_days = (int(datetime.datetime.now().timestamp()) - ts) // 86400
    print()
    print(f"{DIM}── [{idx}/{total}] {RESET}{BOLD}{p.name}{RESET} {DIM}──{RESET}")
    day = datetime.date.fromtimestamp(ts).isoformat()
    print(f"  {DIM}last touched{RESET}  {day} ({age_days} days ago)")
    d = p.working_dir()
    if d:
        print(f"  {DIM}dir{RESET}           {d}")
    files = sorted(f for f in os.listdir(p.path) if f not in (".proj", ".proj.json"))
    print(f"  {DIM}files{RESET}         {' '.join(files)}")
    for lines in plugins.call("prune_details", cfg, p):
        for line in lines:
            print(line)
    nf = p.notes_file()
    if nf:
        print(f"  {DIM}tail of {nf.name}{RESET}")
        lines = [line for line in nf.read_text(errors="replace").splitlines() if line.strip()]
        for line in lines[-12:]:
            print(f"    {line[:120]}")


def cmd_prune(cfg, a):
    current = find_current(cfg)
    current_path = current.path if current else None
    entries = []
    for p in all_projects(cfg):
        if p.path == current_path or p.is_area:
            continue
        entries.append((p.last_touched(), p))
    entries.sort(key=lambda e: e[0])
    if not entries:
        print("no projects to review")
        return 0

    notes: dict[str, str] = {}
    i = 0
    try:
        while i < len(entries):
            ts, p = entries[i]
            show_card(cfg, p, ts, i + 1, len(entries))
            if p.name in notes:
                print(f"  {YELLOW}currently marked for archive{RESET}")
            print()
            key = ui.getch("  [a]rchive  [k]eep (enter)  [v]iew notes  [b]ack  [q] finish  [x] cancel > ")
            print()
            k = key.lower()
            if k == "a":
                notes[p.name] = ui.prompt("  closing note (optional): ")
                i += 1
            elif k in ("k", "\n", "\r", ""):
                notes.pop(p.name, None)
                i += 1
            elif k == "v":
                nf = p.notes_file()
                if nf:
                    pager = os.environ.get("PAGER") or "less"
                    subprocess.call(["bash", "-c", f'{pager} +G "$1"', "_", str(nf)])
                else:
                    print("  (no notes file)")
            elif k == "b":
                i = max(i - 1, 0)
            elif k == "q":
                break
            elif k == "x":
                print("cancelled; nothing archived")
                return 0
            else:
                print(f"  unknown key '{key}'")
    except (KeyboardInterrupt, ui.Cancelled):
        print()
        ui.err("cancelled; nothing archived")
        return 130

    picked = [p for _, p in entries if p.name in notes]
    print()
    if not picked:
        print("nothing marked for archive")
        return 0
    print(f"{BOLD}to archive:{RESET}")
    for p in picked:
        note = notes[p.name]
        print(f"  {p.name}  {DIM}— {note}{RESET}" if note else f"  {p.name}")
    print()
    if not ui.confirm(f"archive {len(picked)} project(s)?", False):
        print("cancelled; nothing archived")
        return 0

    sessions = []
    for p in picked:
        try:
            dest = archive(cfg, p)
        except (Fail, OSError) as e:
            ui.err(f"error: {e}; skipping {p.name}")
            continue
        if notes[p.name]:
            append_note(cfg, p.name, notes[p.name])
        print(f"  {GREEN}archived{RESET} {p.name} {DIM}→ {ui.tilde(dest)}{RESET}")
        if tmux.has_session(p.session):
            sessions.append(p.session)

    if sessions:
        print()
        if ui.confirm(f"kill tmux sessions ({' '.join(sessions)})?", True):
            for s in sessions:
                subprocess.call(["tmux", "kill-session", f"-t={s}"])
    return 0
