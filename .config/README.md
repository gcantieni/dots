# tmux + nvim + Claude workflow

Reference for future agents working in this environment. Describes how the tmux
session/project/agent workflow fits together and where the pieces live.

> Environment note: this is a Linux host paired with a Windows VM (Cygwin), SSH'd via
> Windows OpenSSH. Claude Code and everything below run on the **Linux** side.
> General coding conventions live in `~/AGENTS.md` (`~/.config/../AGENTS.md`).

## Version control

Dotfiles (including this README) live in a **bare git repo** at `~/.dots`, worked
against `$HOME`. The `dots` alias (in `~/.bashrc`) wraps git for it:

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
                              Claude hooks ──┴──▶ ~/.claude/status/*.json ──▶ claude-agents popup + status bar
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
- **`tm`** — `fzf` attach to an existing session (simple alternative to the sessionizer).

### The project file
`~/proj/<name>/.proj.json`, a flat JSON object of strings written by `gc-proj`:
```json
{
  "dir": "/path/to/source",
  "build": "cd \"$dir/module\" && make"
}
```
Read it with `gc-proj dir` or `gc-proj get <key>` rather than parsing it. An old
bash-sourceable `.proj` is still read, and `gc-proj migrate` converts it.
`$PROJ` points at the `~/proj/<name>` dir. `$dir` (in `gc-proj run` commands) and the
resolved cwd point at the source tree.

### Claude agent monitoring
- **`claude-agents`** — one script for agent state, overview and notifications.
- **`claude-agents hook <state>`** — invoked from Claude Code hooks (see
  `~/.claude/settings.json`). Maps hook events → states and writes one JSON record per
  pane to `~/.claude/status/pane-<pane_id>.json`. States:
  `idle` (SessionStart), `busy` (UserPromptSubmit / PreToolUse), `done` (Stop),
  `waiting` (Notification — but only a *real* permission/elicitation prompt; a plain
  idle_prompt is downgraded to idle/done), `end` (SessionEnd, removes the record). It
  also pushes a summary into the tmux `@claude_status` option and refreshes clients so
  the status bar updates instantly rather than on the poll timer.
- **`claude-agents`** with no arg reads those records (pruning dead panes) as an
  interactive `fzf` switcher with a live pane preview (bound to **prefix+a**);
  `line` = compact counts for the status bar; `list` = plain listing. Glyphs:
  green ● busy, yellow ◆ waiting, blue ✔ done, grey ○ idle. `line` prefixes the
  whole group with a cyan `✻` label so it reads as the Claude segment.
  Rows are ordered by state (waiting → busy → done → idle) and then by the record's
  `ts` newest-first, so the agent you touched last sits at the top of its group.
  A grey age column (`34s`, `18h`, `5d`) shows that recency; `ts` is re-stamped on
  every hook event, so it tracks last activity rather than session start.
  Desktop notifications when an agent finishes or needs input are off until
  **prefix+N** turns them on.

### Misc helpers
- **`tmux-open-error`** — scrape compiler errors from the current pane and open each in
  `nvim` at the error line (uses the last `Entering directory` line as the base dir).
- **`gc-display`** (prefix+y) toggle xrandr mono/dual monitor; **`idea`** launches
  IntelliJ with an isolated config; **`esc-switch`** swaps caps/esc (macOS
  `hidutil`); **`nvr-edit`** opens a file from an nvim `:terminal` in that nvim;
  **`gc-type-char`** types a character into the focused X11 window.

## tmux bindings (see `~/.tmux.conf`)

Prefix is **Ctrl-Space**. Highlights:

| Binding | Action |
|---|---|
| `prefix f` / `prefix Space` | sessionizer (new window running `tmux-sessionizer`) |
| `prefix ,` | fzf popup: jump to another session (with pane preview) |
| `prefix a` | Claude agent overview popup (`claude-agents`) |
| `prefix N` | toggle Claude desktop notifications |
| `prefix ]` | paste the X clipboard (bracketed) — replaces default paste-buffer |
| `prefix C-k` | kill current session |
| `prefix R` | rename window; `prefix E` | move window to the end |
| `prefix \|` / `prefix -` | split horizontal / vertical |
| `prefix y` / `prefix u` | toggle display / send sudo pass |
| `prefix r` | reload `~/.tmux.conf` |

Other config: vi mode-keys, mouse on, status bar on top, base-index 1,
`renumber-windows on`, 75k scrollback, clipboard integration (`set-clipboard on`,
`y` in copy-mode pipes to `xclip`). Status-right shows live Claude agent counts
(`@claude_status`, prefixed cyan `✻`) then the clock. Plugins: `tpm` +
`tmux-resurrect`. Local overrides go in `~/.tmux.conf.local`.

Label glyphs are basic-Unicode (Dingbats `✻` U+273B) and emitted as octal `printf`
escapes, not Nerd Font PUA codepoints — the status-bar font renders those but not
FontAwesome-v5 glyphs, and `$'\u…'` isn't expanded by the shell that draws the bar.
The per-state count glyphs (●◆✔○) are likewise basic Unicode.

## nvim (`~/.config/nvim`)

lazy.nvim setup, kickstart-derived. Leader is **Space**, localleader is **`,`**
(buffer-local mappings in special views). Two things to know before editing:

- **`lua/core/*.lua`** — auto-loaded alphabetically by `init.lua` and *hot-reloadable*
  with **`<leader>R`** (re-`require`s the whole `core.*` namespace in place; does **not**
  reload plugin specs). Splits: `options.lua`, `keymaps.lua`, `autocmds.lua` (each
  augroup is cleared on re-source so handlers don't stack). Since every file there is
  loaded, a site module is just another file in that directory. Custom modules alongside:
  - `claude_send.lua` — send visual selection to a Claude agent in a tmux pane
    (**`<F5>`** / `<leader>as`); discovers agents from the same `~/.claude/status/*.json`
    records `claude-agents` reads.
  - `vscode.lua` — hand the buffer to VS Code for a debug session (`<leader>dv`).
    Its root detection takes extra probes from `M.root_probes`.
  - `ai_term_gf.lua` — `gf` in terminal buffers, resolving paths against the term's cwd.
  - `termcwd.lua`, `trace.lua`, `nvr.lua`, `softwrap.lua`, `formatlist.lua` — helpers.
- **Telescope outside git repos** — a tree that isn't a git repo gives ripgrep no
  `.gitignore` to honour, so it lists every build artifact right next to the sources.
  `plugins/telescope.lua` therefore passes `--ignore-file=~/.config/ripgrep/ignore` in
  both `pickers.find_files.find_command` and `defaults.vimgrep_arguments`. Add
  exclusions to that ignore file, not to the Lua. Hand-edited test expectation files
  (`*.out+`, `*.argv`, …) are deliberately kept. `:TelescopeArtifacts` toggles the
  filter off when you do want the artifacts — a picker's `no_ignore = true` won't work,
  since rg's `--no-ignore` does not undo `--ignore-file`. The same ignore file is wired
  into shell `rg` via `~/.config/ripgrep/ripgreprc` + `RIPGREP_CONFIG_PATH` in
  `.bashrc`; `rg --no-config` opts out there.
- **`lua/plugins/*.lua`** — one file per plugin spec, auto-imported via
  `{ import = 'plugins' }`. Add a plugin by dropping a file here; edit specs need
  `:Lazy sync`/`reload`, not `<leader>R`. Leader-group labels live in the `which-key`
  spec in `init.lua`.

## Claude Code hook wiring (`~/.claude/settings.json`)

Every relevant lifecycle event calls `claude-agents hook`:
`SessionStart→idle`, `UserPromptSubmit→busy`, `PreToolUse→busy`, `Stop→done`,
`Notification→waiting`, `SessionEnd→end`. This is what makes the `prefix a` overview
and the status-bar agent counts work. `effortLevel` is `high`.

## Typical loop

1. `prefix f` → pick a project → lands in a tmux session at the source.
2. Open `nvim` in one window; run a Claude agent in another.
3. Fan out across projects; use `prefix a` to jump to whichever agent needs attention.
