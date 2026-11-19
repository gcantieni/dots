---
name: dots
description: How this user's dotfiles are tracked with bare git repos whose work tree is $HOME (the dots alias). Use before adding, moving, renaming, or deleting a file under ~ that is or should be version controlled, such as shell, editor, tmux, or agent config, and when committing, pulling, or setting up dotfiles on a machine.
---

# Dotfiles

If `references/local.md` exists, read it first. It adds this machine's repos,
and where it conflicts with this file, it wins.

## dots

`dots` is a shell alias for `git --git-dir ~/.dots --work-tree ~`. Aliases don't
work in scripts or tool calls, so run git directly:

```sh
/usr/bin/git --git-dir "$HOME/.dots" --work-tree "$HOME" <command>
```

It is shared across all the user's machines. Nothing that is specific to one
machine or employer goes in it.

## Rules

- `status.showUntrackedFiles` is `no`, so `status` never shows a new file. Add
  every new file by name. Never `add .` or `add -A`: the work tree is all of `~`.
- Track files, not generated output (`__pycache__`, logs, caches).
- After moving a tracked file, `rm --cached` the old path and `add` the new
  one. Git records it as a rename.
- A post-commit hook pushes every commit, so a commit is published. Stage
  changes and leave the commit to the user unless they ask.
- `~/bin/dots-pull` fast-forwards in the background from interactive shells, at
  most every four hours.
- `~/bin/dots-init` configures the repo on a new machine and runs
  `~/.config/agents/install`.

## New machine

`dots-bootstrap` clones the repo, asks before moving files the checkout would
overwrite to `~/.dots-backup/<timestamp>/`, checks out, and runs `dots-init`.
It needs `git` and `curl`:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/gcantieni/dots/master/bin/dots-bootstrap)" - ssh
```

`ssh` makes `~/.ssh/id_ed25519` if missing and waits until GitHub accepts it.
Without it the clone is over HTTPS and pull-only. `--git-identity`, for either
script, writes the personal author identity to the untracked `~/.gitconfig`.
Re-run `dots-init` on an existing machine after changing it or the agent
links.
