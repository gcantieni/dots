-- Make `gq`/`gw` treat bulleted/numbered lists as lists: wrapped lines get a
-- hanging indent aligned under the item text instead of falling back to the
-- left margin. Shared by the after/ftplugin/* files so every filetype that
-- opts in uses the same markers. Reloadable via <leader>R.
local M = {}

-- Markers recognized (optional leading whitespace, then a marker + whitespace):
--   -  *  +  bullets, and  1.  /  1)  numbering.
M.pat = [[^\s*[-*+]\s\+\|^\s*\d\+[.)]\s\+]]

function M.apply()
  -- 'n' (see :h fo-table): recognize lists via 'formatlistpat' when formatting.
  -- Appended so any flags the runtime ftplugin set (e.g. croql) are preserved.
  vim.opt_local.formatoptions:append 'n'
  vim.opt_local.formatlistpat = M.pat
  -- 'n' only produces the hanging indent when 'autoindent' is on (:h fo-table).
  vim.opt_local.autoindent = true
  -- ...and only when nothing else drives the indent of each wrapped line. An
  -- 'indentexpr' (rust's built-in GetRustIndent) would win and send wrapped
  -- lines to the left margin, so clear it. treesitter's indent module also sets
  -- 'indentexpr' asynchronously -- it is disabled for these filetypes in
  -- lua/plugins/treesitter.lua so it can't race this. Editing then falls back to
  -- cindent (cpp/rust) / autoindent (markdown).
  vim.opt_local.indentexpr = ''
end

return M
