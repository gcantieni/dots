# nvim

`~/.config/nvim` uses lazy.nvim and started from kickstart. Leader is Space.
Localleader is `,`, used for buffer-local mappings in special views. Leader-group
labels are in the which-key spec in `init.lua`.

## Layout

- `lua/core/*.lua` all load alphabetically from `init.lua`. `<leader>R`
  reloads every `core.*` module in place but not plugin specs. Each augroup in
  `autocmds.lua` is cleared when re-sourced, so handlers don't stack. A
  machine-specific module is just another file here.
- `lua/plugins/*.lua` hold one plugin spec per file, imported with
  `{ import = 'plugins' }`. Changing a spec needs `:Lazy sync` or a reload, not
  `<leader>R`.

## Modules worth knowing

- `claude_send.lua`: send a visual selection to a Claude pane (`<F5>`,
  `<leader>as`). Finds agents from `~/.claude/status/*.json`.
- `vscode.lua`: hand the buffer to VS Code for debugging (`<leader>dv`). Other
  modules add root probes through `M.root_probes`.
- `ai_term_gf.lua`: `gf` in terminal buffers, resolving against the terminal's
  cwd.
- `termcwd.lua`, `trace.lua`, `nvr.lua`, `softwrap.lua`, `formatlist.lua`,
  `toggles.lua`, `gotodef.lua`, `uv_filetype.lua`: smaller helpers.

## Search ignores

Outside a git repo, ripgrep has no `.gitignore`, so it lists build artifacts
beside sources. `plugins/telescope.lua` passes
`--ignore-file=~/.config/ripgrep/ignore` to both `find_files` and
`vimgrep_arguments`. Add exclusions to that file, not to the Lua.
`:TelescopeArtifacts` turns the filter off. A picker's `no_ignore = true` won't,
because rg's `--no-ignore` doesn't undo `--ignore-file`. Shell `rg` reads the
same file through `~/.config/ripgrep/ripgreprc` and `RIPGREP_CONFIG_PATH`, and
`rg --no-config` skips it.
