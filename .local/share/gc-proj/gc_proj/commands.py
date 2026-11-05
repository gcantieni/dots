from __future__ import annotations

import glob
import json
import os
import subprocess

from . import config, projfile, trees, services, tmux, ui, worktrees
from .project import (Project, all_projects, area_dir, check_area, check_name, check_state, default_state,
                      current_area, jira_key_from_name, open_project, require_current,
                      require_env, resolve, set_keys)
from .ui import Cancelled, Fail
from .util import call, out


def pick_sandbox(cfg) -> str:
    """A sandbox picked from the sandboxes glob, else a typed dir."""
    pattern = cfg.text("sandboxes")
    if not pattern:
        d = os.path.expanduser(ui.prompt("dir> ", os.getcwd()).strip())
        if not d:
            raise Cancelled()
        if not os.path.isdir(d):
            raise Fail(f"{d} is not a directory")
        return os.path.realpath(d)
    candidates = sorted(p for p in glob.glob(os.path.expanduser(pattern)) if os.path.isdir(p))
    if not candidates:
        raise Fail(f"no sandboxes match {pattern}")
    picked = ui.fzf(candidates, "--prompt", "choose sandbox dir> ", "--delimiter", "/", "--with-nth", "-1")
    if not picked:
        raise Cancelled()
    subdir = cfg.text("sandbox_subdir")
    return os.path.join(picked, subdir) if subdir else picked


def cmd_new(cfg, a):
    name = a.name
    check_name(name)
    area = a.area if a.area is not None else current_area(cfg)
    check_area(cfg, area)
    given = a.dir
    tree = a.tree
    if given and (tree or a.no_sandbox):
        raise Fail("give a dir, --tree or --no-sandbox, not more than one")
    if not given and not tree and not a.no_sandbox:
        if area:
            given = area_dir(cfg, area) or os.getcwd()
        elif cfg["new_tree"]:
            tree = True
    if tree and not trees.enabled(cfg):
        raise Fail("--tree needs trees.new and trees.path in the config")

    tree_repo = ""
    if tree and trees.uses_repo(cfg):
        tree_repo = trees.area_repo(area_dir(cfg, area) if area else "")
        if not tree_repo:
            raise Fail("--tree makes the tree in the area's repo; give an --area whose dir is a git repo")

    projdir = cfg.root / name
    if projdir.exists():
        raise Fail(f"{projdir} already exists")
    sandbox = ""
    if given:
        if not os.path.isdir(given):
            raise Fail(f"{given} is not a directory")
        sandbox = os.path.realpath(given)

    cfg.root.mkdir(parents=True, exist_ok=True)
    projdir.mkdir()
    try:
        if a.no_sandbox:
            sandbox = str(projdir)
        elif tree:
            sandbox = trees.new_tree(cfg, name, cfg.text("branch_prefix") + name, tree_repo)
        elif not sandbox:
            sandbox = pick_sandbox(cfg)
    except BaseException:
        projdir.rmdir()
        raise

    keys = {"dir": sandbox}
    if tree:
        keys["tree"] = name
        if tree_repo:
            keys["tree_repo"] = tree_repo
    if area:
        keys["area"] = area
    if a.jira and jira_key_from_name(name) != a.jira.upper():
        keys["jira"] = a.jira.upper()
    p = Project(projdir, cfg)
    p.update(keys)

    if worktrees.in_pool(cfg, sandbox) and worktrees.valid_branch_name(name):
        main = worktrees.main_branch(cfg)
        exists = worktrees.branch_exists(cfg, name)
        question = f"use existing branch {name}?" if exists else f"create branch {name} from {main}?"
        if ui.confirm(question, True):
            if not exists and call(["git", "-C", worktrees.repo(cfg), "branch", name, main]) != 0:
                raise Fail(f"couldn't create branch {name}")
            p.update({"branch": name})
            print(f"branch: {name} (run gc-proj activate to check it out)")

    if a.no_open:
        print(p.path)
        return 0
    return open_project(p)


def cmd_break(cfg, a):
    if not tmux.inside():
        raise Fail("not in tmux")
    name = a.name or ui.prompt("project name> ")
    name = name.strip().replace(" ", "-")
    if not name:
        raise Cancelled()
    check_name(name)
    area = a.area if a.area is not None else current_area(cfg)
    check_area(cfg, area)

    projdir = cfg.root / name
    session = tmux.session_name(name)
    if projdir.exists():
        raise Fail(f"{projdir} already exists")
    if tmux.has_session(session):
        raise Fail(f"tmux session {session} already exists")
    pane = tmux.origin_pane()
    path = tmux.pane_path(pane)
    if not pane or not path:
        raise Fail("can't find the pane to move")

    projdir.mkdir(parents=True)
    keys = {"dir": path}
    if area:
        keys["area"] = area
    Project(projdir, cfg).update(keys)

    # Switch before moving the pane: if it was the last one in its session, that
    # session goes away, and the client with it if it were still attached there.
    placeholder = out(["tmux", "new-session", "-d", "-P", "-F", "#{window_id}", "-s", session,
                       "-c", path, "-e", f"PROJ={projdir}"], quiet=False)
    if not placeholder:
        raise Fail(f"couldn't make tmux session {session}")
    return call(["tmux", "switch-client", "-t", f"={session}", ";",
                    "break-pane", "-s", pane, "-t", f"={session}:", ";",
                    "kill-window", "-t", placeholder, ";",
                    "move-window", "-r", "-t", f"={session}"])


def cmd_open(cfg, a):
    if a.project:
        p = resolve(cfg, a.project)
    else:
        names = [p.name for p in all_projects(cfg)]
        picked = ui.fzf(names, "--prompt", "project> ")
        if not picked:
            return 0
        p = Project(cfg.root / picked, cfg)
    return open_project(p)


def cmd_cd(cfg, a):
    p = require_env(cfg)
    if a.path == "--no-sandbox" or a.no_sandbox:
        path = str(p.path)
    elif a.path:
        if not os.path.isdir(a.path):
            raise Fail(f"{a.path} is not a directory")
        path = os.path.realpath(a.path)
    else:
        path = pick_sandbox(cfg)
    p.update({"dir": path})
    tmux.set_session_dir(path)


def _require_worktrees(cfg):
    if not worktrees.enabled(cfg):
        raise Fail("set worktrees.repo in the config to use branches")


def cmd_branch(cfg, a):
    p = require_env(cfg)
    _require_worktrees(cfg)
    name = a.name
    if not name:
        refs = worktrees.git_out(worktrees.repo(cfg), "for-each-ref", "--sort=-committerdate",
                                 "--format=%(refname:short)", "refs/heads").splitlines()
        r = subprocess.run(["fzf", "--prompt", "branch> ", "--print-query"], input="\n".join(refs) + "\n",
                           text=True, stdout=subprocess.PIPE)
        lines = r.stdout.rstrip("\n").splitlines()
        name = lines[-1] if lines else ""
    if not name:
        raise Cancelled()
    p.update({"branch": name})
    print(f"branch: {name} (run gc-proj activate to check it out)")


def cmd_activate(cfg, a):
    p = require_env(cfg)
    _require_worktrees(cfg)
    branch = p.get("branch")
    if not branch:
        raise Fail(f"no branch in {p.name}; set one with gc-proj branch")
    subdir = p.get("subdir") or cfg.text("worktrees.subdir")
    d = worktrees.activate(cfg, branch, subdir, a.move)
    if d:
        tmux.set_session_dir(d)


def cmd_run(cfg, a):
    p = require_current(cfg)
    if not p.exists():
        raise Fail(f"no project file in {p.path}")
    cmd = p.get(a.key)
    if not cmd:
        raise Fail(f"no '{a.key}' command in {p.name}; set one with gc-proj set {a.key}='...'")
    env = dict(os.environ)
    env.update({k: v for k, v in p.keys.items() if k.isidentifier()})
    env["PROJ"] = str(p.path)
    env["dir"] = p.working_dir()
    return subprocess.call(["bash", "-c", cmd], env=env)


def cmd_edit(cfg, a):
    p = require_current(cfg)
    f = p.path / projfile.FILE
    if not f.is_file():
        p.update({})
    editor = os.environ.get("EDITOR") or "vim"
    return subprocess.call(["bash", "-c", f'{editor} "$1"', "_", str(f)])


def cmd_dir(cfg, a):
    p = resolve(cfg, a.project) if a.project else require_env(cfg)
    if not p.exists():
        raise Fail(f"no project file in {p.path}")
    print(p.working_dir())


def cmd_get(cfg, a):
    p = resolve(cfg, a.project) if a.project else require_current(cfg)
    if a.key is None:
        print(json.dumps(p.keys, indent=2))
        return 0
    value = p.working_dir() if a.key == "dir" else p.get(a.key)
    print(value)
    return 0 if value else 1


def cmd_state(cfg, a):
    p = require_current(cfg)
    if not a.state:
        print(p.get("state") or default_state(cfg))
        return
    check_state(cfg, a.state)
    p.update({"state": a.state})


def cmd_set(cfg, a):
    set_keys(cfg, require_current(cfg), a.pairs)


def rename(cfg, old: str, new: str) -> None:
    """Rename project old (a name or path) to new, with its tmux session."""
    path = os.path.abspath(os.path.expanduser(old)) if "/" in old else str(cfg.root / old)
    p = Project(path.rstrip("/"), cfg)
    new = new.strip().replace(" ", "-")
    if p.path.parent != cfg.root or not p.exists():
        raise Fail(f"{p.path} is not a project under {ui.tilde(cfg.root)}")
    check_name(new)
    if new == p.name:
        return
    newdir = cfg.root / new
    if newdir.exists():
        raise Fail(f"{newdir} already exists")
    old_session, new_session = p.session, tmux.session_name(new)
    if tmux.has_session(new_session):
        raise Fail(f"tmux session {new_session} already exists")

    key = p.jira_key
    raw_dir = p.get("dir")
    oldname, olddir = p.name, str(p.path)
    os.rename(olddir, newdir)
    print(f"renamed {oldname} to {new}")
    q = Project(newdir, cfg)
    updates = {}
    if key and jira_key_from_name(new) != key and not q.get("jira"):
        updates["jira"] = key
        print(f"jira={key} kept")
    new_dir = ""
    if raw_dir == olddir or raw_dir.startswith(olddir + "/"):
        new_dir = str(newdir) + raw_dir[len(olddir):]
        updates["dir"] = new_dir
    if updates:
        q.update(updates)
    if q.is_area:
        for other in all_projects(cfg):
            if other.get("area") == oldname:
                other.update({"area": new})
                print(f"{other.name}: area={new}")
    if tmux.has_session(old_session):
        if call(["tmux", "rename-session", "-t", f"={old_session}", new_session]) != 0:
            raise Fail(f"couldn't rename tmux session {old_session}")
        call(["tmux", "set-environment", "-t", f"={new_session}", "PROJ", str(newdir)])
        if new_dir:
            tmux.set_session_dir(new_dir, new_session)
        print(f"tmux session {old_session} renamed to {new_session}")


def cmd_rename(cfg, a):
    if a.new is None:
        if not os.environ.get("PROJ"):
            raise Fail("usage: gc-proj rename [project] <new-name>")
        rename(cfg, os.environ["PROJ"], a.old)
    else:
        rename(cfg, a.old, a.new)


def cmd_jira_new(cfg, a):
    print(services.jira_create(cfg, " ".join(a.summary)))


def cmd_migrate(cfg, a):
    n = 0
    for p in all_projects(cfg):
        if projfile.migrate(p.path):
            print(f"{p.name}: {projfile.LEGACY_FILE} -> {projfile.FILE}")
            n += 1
    print(f"{n} project(s) migrated")


def cmd_config(cfg, a):
    width = max(len(k) for k, _ in cfg.items())
    for k, v in cfg.items():
        shown = json.dumps(v) if not isinstance(v, str) else v
        print(f"{k:<{width}}  {shown:<40}  {ui.DIM}{cfg.sources[k]}{ui.RESET}")
    print(f"\n{ui.DIM}files: {' '.join(str(f) for f in config.config_files())}{ui.RESET}")
