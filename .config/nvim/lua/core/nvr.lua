-- Helpers for `nvr` (neovim-remote) invoked from inside an nvim :terminal.
--
-- When EDITOR=nvr and you open a file from a toggleterm, nvr runs `:edit` in the
-- *current* window -- which is the terminal itself. That hijacks the toggleterm,
-- wrecks its size, and leaves the term "stuck". goto_editable_window() is run by
-- the `~/bin/nvr-edit` wrapper (via `nvr -cc`) *before* the edit, so the file
-- lands in a normal editing window above the terminal instead.
--
-- Reloadable: called fresh via require() on each nvr invocation, so <leader>R
-- picks up edits here without restarting nvim.

local M = {}

-- A "normal" editing window: not floating, showing a real file buffer (not a
-- terminal, quickfix, help, etc.).
local function is_editable_win(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end
  if vim.api.nvim_win_get_config(win).relative ~= '' then
    return false -- floating window (e.g. a floated toggleterm)
  end
  local buf = vim.api.nvim_win_get_buf(win)
  return vim.bo[buf].buftype == ''
end

--- Focus a normal editing window so a following :edit opens there rather than in
--- the terminal the nvr call came from. Prefers the previously-focused window,
--- then any editable window in the current tab; if none exists (e.g. a
--- fullscreen terminal) it opens a fresh split above.
function M.goto_editable_window()
  local cur = vim.api.nvim_get_current_win()
  if is_editable_win(cur) then
    return
  end

  -- Previously-focused window (the one you were editing before jumping to the term).
  local prev = vim.fn.win_getid(vim.fn.winnr '#')
  if prev ~= cur and is_editable_win(prev) then
    vim.api.nvim_set_current_win(prev)
    return
  end

  -- Any other editable window in this tab.
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= cur and is_editable_win(win) then
      vim.api.nvim_set_current_win(win)
      return
    end
  end

  -- Nothing editable open: split a new window above the terminal and give it an
  -- empty scratch buffer for the pending :edit to replace.
  vim.cmd 'aboveleft split'
  vim.cmd 'enew'
end

return M
