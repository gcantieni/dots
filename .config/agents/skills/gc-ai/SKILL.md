---
name: gc-ai
description: How this user's agent configuration is organized in ~/.config/agents (global AGENTS.md files, personal skills, the install script that links them into place) and where a new skill, rule, hook, or plugin should live. Use before creating, moving, renaming, or editing a skill, plugin, hook, or global instruction file, or when deciding where agent configuration belongs. Use alongside skill-creator, which covers skill format but not where things go here.
---

# Agent configuration

If `references/local.md` exists, read it first. It adds this machine's setup,
and where it conflicts with this file, it wins.

The files here are tracked by the user's dotfile repos. See the `dots` skill
before adding, moving, or deleting one. Proj dirs are covered by the `gc-proj`
skill.

If a change makes this skill wrong, update it in the same task.

## ~/.config/agents

Everything hand-written for agents lives here. Tools read it through links that
`~/.config/agents/install` makes. Edit the files here, not through the links.

```
~/.config/agents/
  AGENTS.md            personal defaults for every tool and project
  AGENTS.local.md      this machine's extra rules, if any
  skills/<name>/       personal skills
  install              makes the links
  codex-sync           writes ~/.codex/AGENTS.md
  install.local        this machine's extra links, if any; sourced by install
  .gitignore           __pycache__
```

`install` links each `skills/<name>` into `~/.claude/skills/` and
`~/.agents/skills/` (Codex), sources `install.local`, and runs `codex-sync`. It
links only what is present, skips real files in the way, removes its own stale links,
and is safe to re-run. It runs from the dotfile init scripts. Re-run it after
adding, renaming, or removing a skill.

`~/.claude/CLAUDE.md` stays a real file containing only
`@~/.config/agents/AGENTS.md`.

## Instruction layering

`~/.claude/CLAUDE.md` imports `AGENTS.md`, which imports `AGENTS.local.md`.
Codex doesn't follow `@` imports, so `codex-sync` writes `~/.codex/AGENTS.md`
with them inlined. It runs from `install` and from the `codex` shell function in
`~/.bashrc`, so an edit reaches Codex at its next launch. Don't edit the
generated file.

Put a new rule in the most general file it is true for: `AGENTS.md` if it holds
on every machine, `AGENTS.local.md` if only on this one, and a repo's own
CLAUDE.md or AGENTS.md if only for that repo. Prefer a skill over an always-on
rule when the rule is needed only for some tasks and has a clear trigger.

## Where a skill goes

`skills/<name>/` with a `SKILL.md`, then run `install`. Keep a skill usable on
every machine: put machine-specific parts in `references/local.md` and have
`SKILL.md` say "If `references/local.md` exists, read it first." `flash` and
this skill are examples.

A skill that should run only when the user asks for it sets
`disable-model-invocation: true` in its frontmatter for Claude, and has an
`agents/openai.yaml` with `policy: { allow_implicit_invocation: false }` for
Codex. `flash` is an example.

`~/.claude/skills-archive/` holds skills not in use now but kept for later. It
isn't loaded. `~/.claude/skills/synced/` is managed by claude.ai. Don't edit it.

## Claude Code hooks

`~/bin/claude-agents hook <state>` runs on session, prompt, tool, stop, and
notification events. It records each tmux pane's agent state for the tmux
status line, a switcher, and notifications. `~/bin/proj-commit` runs on
SessionEnd (see the `gc-proj` skill).

## Agents across a tmux restart

tmux-resurrect and tmux-continuum (`~/.tmux.conf`) save every 15 minutes and
restore when tmux starts. `@resurrect-hook-post-save-layout` runs
`~/bin/tmux-resurrect-save`, which:

- runs `~/bin/vacate snapshot <save>` if vacate is installed. It rewrites each
  pane's saved command so Claude comes back as `claude --resume ID` with its
  other options, nvim as `nvim -S <session>`, and bundlebox as
  `<bundlebox_cmd> --resume ID`. Panes are matched by session, window, and pane
  index, not pane id.
- writes each session's `PROJ` to `~/.local/share/tmux/resurrect/proj-env`,
  since resurrect doesn't save session environments. `~/.bashrc` reads it back
  in a restored pane and sets `PROJ` on the session.

`@resurrect-processes` limits which commands are restarted. Where vacate is
installed, it lists only commands with `--resume`, so a Claude with no
conversation comes back as a plain shell. `claude-agents` records aren't used
for restore.
