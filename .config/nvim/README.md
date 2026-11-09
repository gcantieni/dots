# nvim

lazy.nvim config, originally derived from kickstart. Leader is **Space**, localleader
is **`,`**. The layout (`lua/core/*` loaded eagerly, `lua/plugins/*` as lazy specs)
is in `~/.config/CLAUDE.md`. This file covers only what you can't see from the code.

- **`<leader>R` reloads `lua/core/*` only.** It re-`require`s the `core.*`
  namespace in place. Plugin spec changes need `:Lazy reload` or a restart.
  `autocmds.lua` clears each augroup on re-source so handlers don't stack. Every
  file in `lua/core/` is loaded, so a site-only module is just an extra file there
  (tracked in the work repo, not `dots`).
- **Sending to Claude agents** (`lua/core/claude_send.lua` + `lua/plugins/review.lua`,
  keys under `<leader>c`). Agents are not nvim terminals: they are Claude Code
  sessions in tmux panes, found through the `~/.claude/status/*.json` records that
  `claude-agents hook` writes. No hooks means "no live Claude agents" (see the
  top-level README). Text is bracketed-pasted into the pane without submitting it.
  The chosen pane is remembered per nvim instance in `vim.g.claude_send_pane`.
  Review comments come from review.nvim's quick comments, exported as markdown
  through its `on_export` hook into the same sender.
- **Telescope outside git repos.** With no `.gitignore`, ripgrep lists every build
  artifact. `plugins/telescope.lua` passes `--ignore-file=~/.config/ripgrep/ignore`
  to both `find_files` and `vimgrep_arguments`. Add exclusions to that file, not
  the Lua. `:TelescopeArtifacts` turns the filter off. A picker's `no_ignore = true`
  won't, because rg's `--no-ignore` doesn't undo `--ignore-file`. Shell `rg` uses
  the same file through `~/.config/ripgrep/ripgreprc`, but `RIPGREP_CONFIG_PATH` is
  only exported in `.bashrc`, not fish.
