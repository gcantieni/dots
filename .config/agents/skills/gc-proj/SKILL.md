---
name: gc-proj
description: How this user's projects are organized with gc-proj: ~/proj, .proj.json, areas, $PROJ, the proj dir added to a session, notes.md, and planning files. Use when a task touches a proj dir, .proj.json, $PROJ, gc-proj commands, or the shell launchers that start agent sessions in a project, or when deciding where per-project notes or context should live.
---

# gc-proj

If `references/local.md` exists, read it first. It adds this machine's setup,
and where it conflicts with this file, it wins.

gc-proj is the user's project manager: one directory and one tmux session per
project. Per-project context for agents lives in these proj dirs. The source is
`~/.local/share/gc-proj`, linked from `~/repos/gc-proj`, and its README is the
reference. `gc-proj help` lists the commands. Settings are in
`~/.config/gc-proj/config.toml` and `config.local.toml`, with plugins in
`~/.config/gc-proj/plugins/*.py`.

Don't run gc-proj commands that change state yourself. They open and switch
tmux sessions. Ask the user to run `gc-proj new <name>` or `gc-proj break` and
restart the session there. Reading is fine: `gc-proj dir [project]` and
`gc-proj get [key]`.

## Layout

- The root is `~/proj`. It is a git repo committed by `~/bin/proj-commit` when
  a session ends, so don't run git in it. Only top-level `*.md`, `*.json`, and
  `*.txt` in each project are tracked.
- Each project is `~/proj/<name>/` with a `.proj.json`. `dir` points at the
  project's source, and other keys track state, area, branch, issue, and so on.
  `gc-proj keys` describes them.
- A project with `repo` (a git url) has its source cloned into `dir` by
  `gc-proj open` or `gc-proj clone [-a]` when `dir` is missing. Source repos
  live in `~/repos`, never under `~/proj`.
- Areas (`"kind": "area"`) are long-lived projects that group others.
- Finished projects move to `~/proj/archive/`.

## What goes in a proj dir

- `notes.md`: the user's running notes, with one date heading per day. "Take a
  note" means edit this file.
- `spec.md`, `features.json`, `progress.txt`, and `claims/`: multi-session
  planning state, made by the `proj` skill where it is installed.
- Anything else the user wants kept outside the code repo, such as handoffs and
  scratch designs.

Personal notes and private planning state go here, never in the code repo.

## How a session finds its proj dir

The shell launchers find the current proj from `$PROJ`, or from the tmux
session's `PROJ`, which wins. They pass it to the agent with `--add-dir`, so the
session sees it as an additional working directory that holds a `.proj.json`.
