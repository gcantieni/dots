# tmux and agent monitoring

`~/.tmux.conf` is the source of truth for bindings, and each binding there has a
comment. `~/.tmux.conf.local` adds to it. Prefix is Ctrl-Space. The status bar
is on top. Plugins are tpm, tmux-resurrect, and tmux-continuum. Restoring agents
after a tmux restart is in the `gc-ai` skill.

## Bindings for the workflow

| Binding | Action |
|---|---|
| `prefix f`, `prefix Space` | `tmux-sessionizer` in a new window |
| `prefix ,` | jump to another session, with preview |
| `prefix s` | `gc-proj board` |
| `prefix a` | `claude-agents` overview |
| `prefix N` | toggle desktop notifications from agents |
| `prefix g` | `review-worktree` |
| `prefix e` | `review-reply` |
| `` prefix ` `` | `tmux-copy-code` |
| `prefix /` | search back, or Claude's own transcript search in a Claude pane |
| `prefix k` | kill session, after a confirm |
| `prefix r` | reload `~/.tmux.conf` |

## claude-agents

`claude-agents hook <state>` runs from the Claude Code hooks in
`~/.claude/settings.json`:

| Event | State |
|---|---|
| SessionStart | idle |
| UserPromptSubmit, PreToolUse | busy |
| Stop | done |
| Notification | waiting, only for a real permission or elicitation prompt; an idle prompt stays idle or done |
| SessionEnd | removes the record |

Each pane gets one record, `~/.claude/status/pane-<pane_id>.json`, with a `ts`
updated on every event. The hook also sets the tmux `@claude_status` option and
refreshes clients, so the status bar updates at once.

With no argument it is an fzf switcher with a live pane preview. Rows are
grouped waiting, busy, done, idle, and then newest first. `line` prints the
status-bar segment and `list` prints a plain listing. nvim's `claude_send.lua`
finds agents from the same records.

Status-bar glyphs are basic Unicode (`✻`, `●◆✔○`), written as octal `printf`
escapes. The bar's font lacks Nerd Font glyphs, and the shell that draws it
doesn't expand `$'\u…'`.
