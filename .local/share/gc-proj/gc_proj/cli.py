from __future__ import annotations

import argparse
import os
import sys

from . import board, cleanup, commands, config, tmux
from .ui import Cancelled, Fail

USAGE = """\
usage: gc-proj <command> [args]

A project is a directory under the projects root (~/proj by default) with a
.proj.json file, and gets a tmux session of its own. $PROJ is the current
project; inside tmux the session's PROJ wins over the shell's, so a pane that
moved to another project's session acts on that project.

projects
  new <name> [dir] [--tree | --no-sandbox] [--area=AREA] [--jira=KEY] [--no-open]
                       make a project and open its session. Without a dir it works in its
                       area's dir (or the current dir if the area has none), else in a picked
                       sandbox (sandboxes) or a typed dir. --tree makes a tree (trees.new) on a
                       new branch <branch_prefix><name>; --no-sandbox works in the project dir.
                       It joins the current project's area unless --area says otherwise.
  break [name] [--area=AREA]
                       make a project of the current tmux pane, which moves, running and all,
                       into the project's new session
  open [project]       switch to a project's session (pick one if none given)
  cd [path | --no-sandbox]
                       point the current project at path (pick one if none given) and make it
                       the session's default dir
  dir [project]        print the project's working dir, resolving branch= to its worktree
  get [key] [-p project]  print a key of the project, or all of them as JSON
  set key=value ...    set keys of the current project; key= removes one
  state [state]        print or set the state (the states setting; by default active, review,
                       checkin or done)
  rename [project] <new-name>
                       rename a project and its tmux session, and an area's name in its projects
  run <key>            run the shell command in key <key>, with $dir and $PROJ set
  build, test          run build, test
  edit                 open the project file in $EDITOR
  status [-a]          board of projects with tmux sessions (-a: all) by state, with areas below;
                       a project with no state shows in review while it has an open review or MR
  board                interactive status board (press keys as its help line says)
  done                 clean the current project up step by step and archive it
  prune                review projects oldest-first and archive the ones you pick
  migrate              convert every project's legacy .proj to .proj.json

branches (worktrees.repo)
  branch [name]        tie the current project to a branch (pick one if no name)
  activate [-m]        go to the worktree with the project's branch, or check it out in a clean
                       one (rebased onto main first if that one is on main); -m moves it even if
                       it's checked out already

integrations
  jira-new <summary>   create a Jira issue assigned to you and print its key
  config               print the settings and where each comes from

project keys
  dir      the source tree to work in
  branch   worktree branch; overrides dir with the worktree holding it (subdir= within it)
  tree     tree made by new --tree; done offers to drop it
  tree_repo  the area's repo the tree was made in, when the trees commands use {repo}
  state    one of the states setting (default active, review, checkin, done)
  kind     "area" for a long-lived area of responsibility: it gets a panel on the board
           and done and prune leave it alone
  area     the area the project belongs to
  jira     Jira key, if the name doesn't start with one (cs12345-...)
  review   review request, if it can't be found by cl or the Jira key
  mr       merge request url, if it can't be found by branch or the Jira key
  build, test, ...  shell commands for run
  Plugins (~/.config/gc-proj/plugins/*.py) may use more keys.
"""


def parser_for(name: str) -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog=f"gc-proj {name}")
    if name == "new":
        ap.add_argument("name")
        ap.add_argument("dir", nargs="?")
        ap.add_argument("--tree", action="store_true")
        ap.add_argument("--no-sandbox", action="store_true")
        ap.add_argument("--area")
        ap.add_argument("--jira")
        ap.add_argument("--no-open", action="store_true", help="don't open its tmux session")
    elif name == "break":
        ap.add_argument("name", nargs="?")
        ap.add_argument("--area")
    elif name == "open":
        ap.add_argument("project", nargs="?")
    elif name == "cd":
        ap.add_argument("path", nargs="?")
        ap.add_argument("--no-sandbox", action="store_true")
    elif name == "dir":
        ap.add_argument("project", nargs="?")
    elif name == "get":
        ap.add_argument("key", nargs="?")
        ap.add_argument("-p", "--project")
    elif name == "set":
        ap.add_argument("pairs", nargs="*", metavar="key=value")
    elif name == "state":
        ap.add_argument("state", nargs="?")
    elif name == "rename":
        ap.add_argument("old", metavar="project | new-name")
        ap.add_argument("new", nargs="?", metavar="new-name")
    elif name == "run":
        ap.add_argument("key")
    elif name == "status":
        ap.add_argument("-a", "--all", action="store_true")
    elif name == "branch":
        ap.add_argument("name", nargs="?")
    elif name == "activate":
        ap.add_argument("-m", "--move", action="store_true")
    elif name == "jira-new":
        ap.add_argument("summary", nargs="+")
    return ap


COMMANDS = {
    "new": commands.cmd_new,
    "break": commands.cmd_break,
    "open": commands.cmd_open,
    "cd": commands.cmd_cd,
    "dir": commands.cmd_dir,
    "get": commands.cmd_get,
    "set": commands.cmd_set,
    "state": commands.cmd_state,
    "rename": commands.cmd_rename,
    "run": commands.cmd_run,
    "build": commands.cmd_run,
    "test": commands.cmd_run,
    "edit": commands.cmd_edit,
    "status": board.cmd_status,
    "board": board.cmd_board,
    "done": cleanup.cmd_done,
    "prune": cleanup.cmd_prune,
    "migrate": commands.cmd_migrate,
    "branch": commands.cmd_branch,
    "activate": commands.cmd_activate,
    "jira-new": commands.cmd_jira_new,
    "config": commands.cmd_config,
}


def main(argv=None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if not argv or argv[0] in ("-h", "--help", "help"):
        sys.stdout.write(USAGE)
        return 0
    name, rest = argv[0], argv[1:]
    if name not in COMMANDS:
        print(f"error: unknown command '{name}'", file=sys.stderr)
        sys.stderr.write(USAGE)
        return 1
    args = parser_for(name).parse_args(rest)
    if name in ("build", "test"):
        args.key = name

    # GC_PROJ_FIXED keeps an explicit PROJ=... for one invocation.
    if not os.environ.get("GC_PROJ_FIXED"):
        session_proj = tmux.session_proj()
        if session_proj:
            os.environ["PROJ"] = session_proj

    cfg = config.load()
    try:
        return COMMANDS[name](cfg, args) or 0
    except Cancelled as e:
        print(e, file=sys.stderr)
        return 1
    except Fail as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print(file=sys.stderr)
        return 130
