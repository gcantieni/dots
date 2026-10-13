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
carries a `.proj` file pointing at the real source tree. You navigate between
projects with a fuzzy **sessionizer**, and — because most sessions run a Claude
agent — you monitor and jump between agents with tmux popups backed by Claude Code
hooks.

```
~/proj/<name>/.proj   ──sourced by──▶  sessionizer
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
  with an arg, targets that dir. Reads the selected dir's `.proj` file to resolve the
  working directory (`dir=` key, or legacy single-line path), then creates or
  switches to a tmux session named after the project (dots → underscores). Exports
  `PROJ=<proj dir>` into the session. Bound to **prefix+f** and **prefix+Space**.
  A `.proj` with `branch=` is resolved by `gc-proj dir` when that's installed.
- **`tm`** — `fzf` attach to an existing session (simple alternative to the sessionizer).

### The `.proj` file
Bash-sourceable `key=value` living at `~/proj/<name>/.proj`:
```sh
dir=/path/to/source
build='cd "$dir/module" && make'
test='cd "$dir/module" && make test'
```
Legacy format (a single line containing just the path) is still read as `dir=`.
`$PROJ` points at the `~/proj/<name>` dir; `$dir` (and the resolved cwd) point at the
source tree.

### Claude agent monitoring
- **`claude-status-hook <state>`** — invoked from Claude Code hooks (see
  `~/.claude/settings.json`). Maps hook events → states and writes one JSON record per
  agent to `~/.claude/status/<session_id>.json`, keyed to its `$TMUX_PANE`. States:
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
- **`gc-dictate`** — local speech-to-text via `whisper.cpp` (built at
  `~/src/whisper.cpp`, `small.en` model, CPU-only — the box has no discrete GPU).
  Toggle-driven, because tmux can't see key *release* so push-to-talk isn't
  possible: first press records, second press transcribes and delivers. Audio is
  captured as raw PCM with `parec` (a killed recorder can't leave a truncated WAV
  header) and wrapped by `ffmpeg` before transcription. Silero **VAD** is on by
  default — without it whisper reliably invents filler ("you", "Thank you.") out
  of silence. Delivery modes: default bracketed-pastes into the originating pane
  *without* submitting (same `load-buffer`/`paste-buffer -p` path as
  `claude_send.lua`), `--clip` copies to the clipboard, `--stdout` prints (used
  by the nvim binding), `--xpaste` copies *and* synthesizes Ctrl-V into the
  focused window (the GNOME hotkey below). Pushes `@dictate_status` into the status bar while
  recording, mirroring `claude-status-hook`. Overridable via `GC_WHISPER_MODEL`,
  `GC_WHISPER_THREADS` (default 8 — 16 is only ~5% faster), `GC_DICTATE_SOURCE`
  / `GC_DICTATE_SOURCE_MATCH` (see below), `GC_DICTATE_MAX_SECONDS` (default
  300s, a runaway-recording backstop).
  Roughly 7× realtime: ~1.7s for an 11s clip.

  **Which mic it records from.** Not the PulseAudio default — that follows
  whatever was plugged in last, and with several headsets plus a webcam on this
  box it lands on the wrong device often enough to look like dictation is
  broken. `resolve_source` instead picks the first non-monitor source whose name
  matches `GC_DICTATE_SOURCE_MATCH` (default `Logitech_Inc_Logitech_H570e`),
  falling back to the PulseAudio default when that headset isn't connected.
  `GC_DICTATE_SOURCE` overrides both with an exact device name. Re-point it
  after a headset change with `pactl list short sources`.

**Teaching it jargon.** Two files in `~/.config/gc-dictate/`. Both hold
site-specific tool names, so they live in `~/.dots-work`, not the public repo,
and `gc-dictate` runs fine when they are absent.

- **`vocab.txt`** — one term per line, assembled into whisper's *initial
  prompt*. whisper treats that prompt as text preceding the audio, so listing a
  tool name biases decoding toward that spelling. It's a nudge, not a rule.
- **`fixups.txt`** — `<extended-regex><TAB><replacement>`, applied
  case-insensitively to the finished transcript. Use this when a term must
  *always* come out right: prompt biasing is probabilistic, these rules aren't.
  A rule like `\bwidget\s*d(\s*d)*\b → widgetd` is what collapses a daemon name
  that whisper keeps hearing as two words with a stray trailing letter.

Tune either one against real audio without speaking again:

```sh
gc-dictate --redo    # re-transcribe the last recording through current lists
```

Two gotchas, both measured rather than assumed:
- **The prompt carries style, not just vocabulary.** A bare comma-separated list
  makes whisper emit the whole transcript with no capitalization or punctuation
  (`and so my fellow americans ask not…`). Wrapping the terms in a real
  sentence ending in a period leaves output byte-identical to no-prompt. That's
  why `vocab_prompt` builds a "Glossary for this recording: …" sentence instead
  of just joining the lines.
- whisper keeps only ~224 tokens of initial prompt and **silently drops the
  tail**, so a long `vocab.txt` quietly stops helping. Roughly 100 terms is the
  ceiling; `gc-dictate` warns on stderr past 800 characters.

**Dictating outside tmux (browsers).** `Super+V` is a GNOME custom keybinding
running `gc-dictate --xpaste`, so the toggle works from any window — press once,
speak, press again and the transcript is pasted where the cursor is. Feedback is
a `notify-send` toast rather than the tmux status bar, since there's no tmux to
draw into. gsettings lives outside `dots`, so reproduce it on a new box with:

```sh
BASE=org.gnome.settings-daemon.plugins.media-keys.custom-keybinding
P=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/
# Super+V is toggle-message-tray by default; Super+M keeps that reachable.
gsettings set org.gnome.shell.keybindings toggle-message-tray "['<Super>m']"
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$P']"
gsettings set "$BASE:$P" name 'dictate: toggle record and paste'
gsettings set "$BASE:$P" command '/home/gcantieni/bin/gc-dictate --xpaste'
gsettings set "$BASE:$P" binding '<Super>v'
```

Caveats worth knowing:
- It sends **Ctrl-V**, so it pastes in browsers and GTK/Qt apps but not in a
  terminal, where paste is Ctrl-Shift-V. Use the tmux bindings there.
- The paste goes wherever focus is *when transcription finishes*, ~2s after the
  second press — don't switch windows in between.
- The clipboard is overwritten with the transcript, not restored afterwards.
- Key injection is XTEST via `python3-xlib` (already installed) unless `xdotool`
  is present, in which case that's preferred. Both are X11-only: this breaks
  under Wayland, where no client may synthesize input.
- If nothing pastes, suspect the microphone before the plumbing: a wrong or
  quiet device makes VAD find no speech, so the transcript is empty and the
  paste is a no-op with no error anywhere. Check which device was used and how
  loud it was:
  ```sh
  timeout 3 parec --format=s16le --rate=16000 --channels=1 --raw \
      --device="$(pactl info | sed -n 's/^Default Source: //p')" > /tmp/mic.pcm
  ffmpeg -hide_banner -f s16le -ar 16000 -ac 1 -i /tmp/mic.pcm \
      -af volumedetect -f null /dev/null 2>&1 | grep _volume
  ```
  Speaking normally should give a `max_volume` above roughly −15 dB; a peak down
  near −45 dB is ambient noise and means nothing is reaching the mic.

Rebuilding the engine on a new box (the script is versioned in `dots`, the
~490MB of models and the build tree are not):

```sh
git clone --depth 1 https://github.com/ggml-org/whisper.cpp.git ~/src/whisper.cpp
cd ~/src/whisper.cpp
/usr/bin/cmake -B build -DCMAKE_BUILD_TYPE=Release \
    -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF -DGGML_NATIVE=ON
/usr/bin/cmake --build build -j 20
bash models/download-ggml-model.sh small.en     # ~490MB
bash models/download-vad-model.sh silero-v6.2.0 # ~900KB, see VAD note above
```

Gotchas worth remembering:
- Spell `/usr/bin/cmake` explicitly if another cmake comes first on `PATH`; a
  site-provided one may be broken against this distro.
- No BLAS package is needed; ggml's own AVX2 kernels are used via `GGML_NATIVE`.
  That also means the build is tied to the host CPU — rebuild per machine rather
  than copying `build/`.
- The model download is large enough to look finished when it isn't. A truncated
  file fails at load with `not all tensors loaded ... expected 479, got 323`
  rather than anything mentioning the download — check the size (487,614,201
  bytes for `small.en`) before debugging further.
- Accuracy upgrade path: `download-ggml-model.sh medium.en` and point
  `GC_WHISPER_MODEL` at it. ~3× slower, still comfortably faster than realtime.

## tmux bindings (see `~/.tmux.conf`)

Prefix is **Ctrl-Space**. Highlights:

| Binding | Action |
|---|---|
| `prefix f` / `prefix Space` | sessionizer (new window running `tmux-sessionizer`) |
| `prefix ,` | fzf popup: jump to another session (with pane preview) |
| `prefix a` | Claude agent overview popup (`claude-status`) |
| `M-v` (no prefix) | dictate: toggle record → paste transcript into this pane |
| `prefix v` / `prefix V` | same, but prefixed / transcribe to clipboard |
| `prefix C-v` | cancel an in-progress recording, discarding it |
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
    records `claude-status` reads.
  - `dictate.lua` — dictation into the buffer (**`<F6>`** / `<leader>ad`); toggles
    the same `gc-dictate` script in `--stdout` mode and inserts at the cursor.
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

Every relevant lifecycle event calls `claude-status-hook`:
`SessionStart→idle`, `UserPromptSubmit→busy`, `PreToolUse→busy`, `Stop→done`,
`Notification→waiting`, `SessionEnd→end`. This is what makes the `prefix a` overview
and the status-bar agent counts work. `effortLevel` is `high`.

## Typical loop

1. `prefix f` → pick a project → lands in a tmux session at the source.
2. Open `nvim` in one window; run a Claude agent in another.
3. Fan out across projects; use `prefix a` to jump to whichever agent needs attention.
