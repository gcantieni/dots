# ~/bin

Each script's header comment or `help` is its reference. This list is for
finding the right one.

## Projects and sessions

- `tmux-sessionizer`: fzf over `~/proj/*`, or a dir given as an argument.
  Creates or switches to the project's tmux session at `gc-proj dir`, named
  after the project with dots as underscores, and sets `PROJ` on it.
- `tm`: fzf attach to an existing session.
- `gc-proj`: link to `~/.local/share/gc-proj`. See the `gc-proj` skill.
- `proj-commit`: commits `~/proj` on SessionEnd.

## Agents

- `claude-agents`: agent state, the overview popup, and notifications. See
  [tmux.md](tmux.md).
- `tmux-cname`: short window name from a Claude pane's title, used by tmux's
  `automatic-rename-format`.
- `tmux-copy-code`: copy a blockquote or inline code span from a Claude pane as
  markdown.
- `review-worktree`: diffview of a worktree's uncommitted changes in a popup,
  with comments sent to the Claude pane underneath. Takes a bare repo such as
  `~/.dots` to review dotfiles.
- `review-reply`: open the last Claude reply in nvim. Edits become comments
  pasted back into the pane unsubmitted.
- `tmux-resurrect-save`: post-save hook for tmux-resurrect. See the `gc-ai`
  skill.

## Dotfiles

- `dots-bootstrap`, `dots-init`, `dots-pull`: see the `dots` skill.

## Editors and terminals

- `tmux-open-error`: open each compiler error in the pane in nvim at its line,
  using the last `Entering directory` line as the base.
- `nvr-edit`: open a file from an nvim `:terminal` in that nvim.
- `idea`: IntelliJ with an isolated config.

## Input

- `gc-type-char`: type a character into the focused X11 window.
- `esc-switch`, `esc-caps-install`, `esc-caps-ensure`,
  `com.gus.esc-caps-swap.plist`: swap Caps Lock and Esc on macOS with `hidutil`.
  `esc-caps-RECOVERY.md` undoes it.
