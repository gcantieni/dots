# tmux + nvim + Claude workflow

Reference for future agents working in this environment. Describes how the tmux
session/project/agent workflow fits together and where the pieces live.

> **Scope:** these dotfiles are shared across several machines: a Linux work box
> (paired with a Windows VM over SSH), a macOS home MacBook, and more to come. This
> README only covers what is shared between them. Machine-specific setup lives in
> untracked or site-only files (see "Site-specific config" below) and in `docs/`,
> where each doc says which machine it applies to. Check `uname` before assuming
> Linux-only tools like `xclip`, `parec` or GNOME settings exist.
> General coding conventions live in `~/AGENTS.md`.

## Version control

Dotfiles (including this README) live in a **bare git repo** at `~/.dots`, worked
against `$HOME`. The `dots` alias (in `~/.bashrc` and `fish/config.fish`) wraps git for it:

```sh
alias dots='/usr/bin/git --git-dir "$HOME/.dots/" --work-tree "$HOME"'
```

Use it like normal git, e.g. `dots status`, `dots add ~/.config/README.md`,
`dots commit`, `dots push`. Remote is `git@github.com:gcantieni/dots.git` (branch
`master`). The bare-repo pattern means there's no `.git` dir in `$HOME` — you must go
through `dots` (or `git --git-dir=$HOME/.dots ...`) rather than plain `git`.
`status.showUntrackedFiles` is off, so a new file is invisible to `dots status` until
it is added.

**Site-specific config lives in a second bare repo**, `~/.dots-work`, driven the same
way through the `dotsw` alias, with a remote that never leaves that site. Everything
in it is optional: the public config checks for it and works without it. The hooks
are `~/.localrc` (sourced early by `.bashrc`, for PATH/env), `~/.bashrc.work`
(sourced last), `~/.tmux.conf.local`, extra `lua/core/*.lua` modules in nvim, and
`config-work.el` in doom. Each site file is also listed in `~/.dots/info/exclude`
so it can't be added to the public repo by accident. When the work repo is present,
`~/.config/README-work.md` documents its half.

## The mental model

One tmux **session per project**. A "project" is a directory under `~/proj/` that
carries a `.proj.json` file pointing at the real source tree. You navigate between
projects with a fuzzy **sessionizer**, and — because most sessions run a Claude
agent — you monitor and jump between agents with tmux popups backed by Claude Code
hooks.

```
~/proj/<name>/.proj.json ──read by──▶  sessionizer
      │                                      │
      │ dir=/path/to/source                  │ creates/attaches tmux session
      ▼                                      ▼
   source tree                        tmux session "<name>"  (window(s): nvim, shell, claude)
                                             │
                              Claude hooks ──┴──▶ ~/.claude/status/*.json ──▶ claude-status popup + status bar
```

## Scripts (`~/bin`)

### Projects & sessions
- **`tmux-sessionizer`** — the core navigator. With no arg, `fzf` over `~/proj/*`;
  with an arg, targets that dir. Asks `gc-proj dir` for the project's working
  directory, then creates or switches to a tmux session named after the project
  (dots → underscores). Exports `PROJ=<proj dir>` into the session. Bound to
  **prefix+f** and **prefix+Space**.
- **`gc-proj`** — project lifecycle: `new`, `open`, `cd`, `set`, `status`/`board`,
  `done`, `prune` and more (`gc-proj help`). The code lives in `~/.local/share/gc-proj`,
  whose README covers its settings and plugins, and `~/bin/gc-proj` links to its
  launcher. The `gc-proj` shell function in `.bashrc` makes `gc-proj cd` move the
  current shell too, and has `gc-proj done` leave the project's tree first.
  Per-machine settings (board states, worktree layout) go in the untracked
  `~/.config/gc-proj/config.local.toml`, so the states differ between machines. The
  fish wrapper is `~/.config/fish/functions/gc-proj.fish`.
- **`tm`** — `fzf` attach to an existing session (simple alternative to the sessionizer).

### The project file
`~/proj/<name>/.proj.json`, a flat JSON object of strings written by `gc-proj`:
```json
{
  "dir": "/path/to/source",
  "build": "cd \"$dir/module\" && make"
}
```
Read it with `gc-proj dir` or `gc-proj get <key>` rather than parsing it.
`$PROJ` points at the `~/proj/<name>` dir. `$dir` (in `gc-proj run` commands) and the
resolved cwd point at the source tree.

### Claude agent monitoring
- **`claude-status-hook <state>`** — invoked from Claude Code hooks (see
  `~/.claude/settings.json`). Maps hook events → states and writes one JSON record per
  agent to `~/.claude/status/pane-<pane_id>.json`, keyed to its tmux pane. States:
  `idle` (SessionStart), `busy` (UserPromptSubmit / PreToolUse), `done` (Stop),
  `waiting` (Notification — but only a *real* permission/elicitation prompt; a plain
  idle_prompt is downgraded to idle/done), `end` (SessionEnd, removes the record). It
  also pushes a summary into the tmux `@claude_status` option and refreshes clients so
  the status bar updates instantly rather than on the poll timer.
- **`claude-status`** — reads those records (pruning dead panes). Modes: no arg =
  interactive `fzf` switcher with a live pane preview (bound to **prefix+a**);
  `--line` = compact counts for the status bar; `--list` = plain listing. Glyphs:
  green ● busy, yellow ◆ waiting, blue ✔ done, grey ○ idle. `--line` prefixes the
  whole group with a cyan `✻` label so it reads as the Claude segment.
  Rows are ordered by state (waiting → busy → done → idle) and then by the record's
  `ts` newest-first, so the agent you touched last sits at the top of its group.
  A grey age column (`34s`, `18h`, `5d`) shows that recency; `ts` is re-stamped on
  every hook event, so it tracks last activity rather than session start.

### Misc helpers
- **`tmux-open-error`** — scrape compiler errors from the current pane and open each in
  `nvim` at the error line (uses the last `Entering directory` line as the base dir).
- **`gc-display`** (prefix+y) toggle xrandr mono/dual monitor; **`idea`** launches
  IntelliJ with an isolated config; **`esc-switch`** swaps caps/esc (macOS
  `hidutil`); **`nvr-edit`** opens a file from an nvim `:terminal` in that nvim;
  **`gc-type-char`** types a character into the focused X11 window.

### Dictation
`gc-dictate` (local whisper.cpp speech-to-text, Linux box only) is documented in
[`docs/dictation.md`](docs/dictation.md).

## tmux

I live in tmux: one session per project, usually with nvim, a shell and a Claude
agent in it. Config is `~/.tmux.conf` (prefix **Ctrl-Space**), with per-machine
overrides in `~/.tmux.conf.local`. Read the config for bindings. The non-obvious parts:

- **Sessions come from gc-proj, not tmux.** `tmux-sessionizer` (prefix+f) lists
  `~/proj/*`, asks `gc-proj dir` where that project's source lives, and opens or
  attaches a session named after the project, rooted at the source tree and with
  `$PROJ` pointing back at `~/proj/<name>`. So the session name, its cwd and `$PROJ`
  are three different things.
- **`gc-proj board`** (prefix+s, replacing the default session tree) is the
  overview of all projects grouped by state (e.g. active/waiting/done). From it you
  can jump to a project's session, rename, re-file or finish it. State is set with
  `gc-proj set state=…` and stored in `.proj.json`.
- **prefix+a** is the Claude agent overview (`claude-status`, below).
- Status-bar glyphs are basic Unicode (`✻`, `●◆✔○`) emitted as octal `printf`
  escapes, not Nerd Font codepoints: the bar's font can't render FontAwesome glyphs,
  and the shell drawing the bar doesn't expand `$'\u…'`.

## nvim

See [`nvim/README.md`](nvim/README.md) for the non-obvious parts. The basic
layout (`lua/core` vs `lua/plugins`) is in `~/.config/CLAUDE.md`.

## Claude Code hook wiring (`~/.claude/settings.json`)

`settings.json` is **not** in `dots`, because it holds work-specific settings, so
add these hooks by hand on each new machine (after prompting). Every relevant lifecycle event calls
`claude-status-hook`: `SessionStart→idle`, `UserPromptSubmit→busy`,
`PreToolUse→busy`, `Stop→done`, `Notification→waiting`, `SessionEnd→end`, each as
`$HOME/bin/claude-status-hook <state>`. Without them `~/.claude/status/` stays
empty: the `prefix a` overview, the status-bar counts and nvim's send-to-Claude all
find no agents. After adding them, `claude-status --rescan` registers agents that
are already running.
