-- Editor options. Reloadable via <leader>R (re-required from init.lua).
-- Leader keys and have_nerd_font stay in init.lua (must precede lazy.setup).

vim.o.number = true
vim.o.relativenumber = true
vim.o.mouse = 'a'
-- Don't show the mode, since it's already in the status line
vim.o.showmode = false
-- 2 is decent
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.showtabline = 2
vim.o.breakindent = true
vim.o.expandtab = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true
vim.opt.winborder = 'rounded'
-- opt is key: See `:help lua-options` and `:help lua-options-guide`
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Better diff: histogram + indent heuristic give cleaner hunks; linematch
-- aligns rows inside a hunk so DiffText highlights actual word changes.
vim.opt.diffopt:append { 'algorithm:histogram', 'indent-heuristic', 'linematch:60' }
vim.opt.fillchars:append { diff = '╱' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.scrolloff = 10
vim.o.confirm = true -- prompt instead of failing on save

-- NOTE: expermental grep stuff, trying to get something close to emacs grep experience
vim.o.grepprg = 'rg --vimgrep'

-- osc52 excape sequence standard for yanking to system clipbaord
-- must be supported by terminal emulator.
-- vim.g.loaded_clipboard_provider = nil

-- Use system clipboard (and over SSH+tmux this will go via OSC 52)
vim.opt.clipboard = 'unnamedplus'

-- Force OSC 52 provider
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy '+',
    ['*'] = require('vim.ui.clipboard.osc52').copy '*',
  },
  paste = {
    ['+'] = require('vim.ui.clipboard.osc52').paste '+',
    ['*'] = require('vim.ui.clipboard.osc52').paste '*',
  },
}

vim.g.netrw_browsex_viewer = 'open'
