-- Autocommands. Reloadable via <leader>R.
-- Every autocmd is registered under a cleared augroup so re-sourcing replaces
-- handlers instead of stacking duplicates.

local aug = vim.api.nvim_create_augroup('core.autocmds', { clear = true })

-- Automatically reread file contents as it changes on disk
vim.o.autoread = true
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
  group = aug,
  command = "if mode() != 'c' | checktime | endif",
})
vim.api.nvim_create_autocmd('FileChangedShellPost', {
  group = aug,
  command = "echohl WarningMsg | echo 'File changed on disk. Buffer reloaded.' | echohl None",
})

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = aug,
  callback = function()
    vim.hl.on_yank()
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'qf',
  group = aug,
  callback = function(args)
    vim.keymap.set('n', 'q', '<cmd>cclose<CR>', { buffer = args.buf, silent = true, desc = 'Close quickfix list' })
  end,
})

-- Hard-wrap prose at a fixed column. Reflow the current paragraph with `gqap`
-- (or `gwap` to keep the cursor put); a visual selection reflows with `gq`.
-- Setting textwidth also auto-wraps as you type in these filetypes.
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown', 'text', 'gitcommit' },
  group = aug,
  callback = function(args)
    local width = args.match == 'gitcommit' and 72 or 80
    -- Local scope explicitly: plain vim.bo/vim.wo assignment would also move
    -- the global default, so every later buffer and window would inherit the
    -- prose textwidth and ruler.
    vim.api.nvim_set_option_value('textwidth', width, { scope = 'local', buf = args.buf })
    vim.api.nvim_set_option_value('colorcolumn', '+1', { scope = 'local', win = 0 })
  end,
})
