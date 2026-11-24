---
name: gc-home
description: Map of this user's machine and personal tooling, covering where scripts, configs, dotfiles, projects, and agent config live, how each is tracked, and which skill or reference covers it. Use when a task touches the user's own setup rather than product source, such as ~/bin scripts, files under ~/.config, shell rc files, tmux, nvim, Claude Code hooks or status line, or the project and agent-monitoring workflow, and you need to know where something lives or what it connects to.
---

# Home map

If `references/local.md` exists, read it first. It adds this machine's setup,
and where it conflicts with this file, it wins.

This is an index. Before changing an area, load the skill or reference named
for it. Keep each entry here to one line, and put details in a reference or in
the skill that owns the area.

## Where things live

| What | Where | Read next |
|---|---|---|
| Dotfile tracking | bare repo `~/.dots`, work tree `~` | `dots` skill |
| Personal scripts | `~/bin` | [scripts.md](references/scripts.md) |
| Installed tools (uv, pip, AppImages) | `~/.local/bin`, untracked | |
| Helper code for a script | `~/.local/share/<tool>` | |
| Shell | `~/.bashrc` | |
| tmux | `~/.tmux.conf`, plugins via tpm | [tmux.md](references/tmux.md) |
| nvim | `~/.config/nvim` | [nvim.md](references/nvim.md) |
| ripgrep ignores (shell and nvim) | `~/.config/ripgrep/` | [nvim.md](references/nvim.md) |
| Other app config | `~/.config/<app>` | `dots` skill, to see if it's tracked |
| Agent instructions and skills | `~/.config/agents` | `gc-ai` skill |
| Claude Code settings and hooks | `~/.claude/settings.json` | `gc-ai` skill |
| Agent state per tmux pane | `~/.claude/status/pane-*.json` | [tmux.md](references/tmux.md) |
| Projects, `$PROJ`, notes | `~/proj/<name>` | `gc-proj` skill |
| Source repos | `~/repos/<name>`, each its own git repo | |

Only files a dotfile repo lists are tracked. `~/.gitconfig` is untracked, so
each host keeps its own git identity.

## Machine-specific config

The tracked config works on any machine. Each one also loads these files if
they exist, and machine-specific settings go there rather than in the shared
file:

- `~/.localrc`, sourced early by `.bashrc`, for PATH and env
- machine-local fragments numbered 90+ in `~/.bashrc.d`, sourced last
- `~/.tmux.conf.local`
- extra modules in `~/.config/nvim/lua/core/`, all of which load
- `~/.config/doom/config-work.el`

## How the pieces fit

One tmux session per project. The sessionizer starts a session at a project's
source and sets `PROJ` on it. Most sessions run a Claude agent, and Claude Code
hooks record each pane's state so tmux popups and the status bar show which
agents are busy, waiting, or done. [tmux.md](references/tmux.md) has the
details.
