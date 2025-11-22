-- TODO: use these to optionally disable these intrusive modules
_G.gc_lsp_enabled = true
_G.gc_whichkey_enabled = true

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true
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

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.scrolloff = 10
vim.o.confirm = true -- prompt instead of failing on save

-- NOTE: expermental grep stuff, trying to get something close to emacs grep experience
vim.o.grepprg = 'rg --vimgrep'

vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set({ 'i', 's' }, '<Esc>', function()
  vim.snippet.stop()
  return '<Esc>'
end, { expr = true })

vim.keymap.set({ 'v', 'x', 'n' }, '<C-y>', '"+y', { desc = 'System clipboard yank.' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('n', '<leader>fs', '<cmd>:w<CR>', { desc = '[F]ile [s]ave' })
vim.keymap.set('n', '<leader>w', '<cmd>cd %:h<cr>', { desc = 'C[W]D' })
vim.keymap.set('i', 'kj', '<Esc>')
vim.keymap.set('t', 'kj', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('n', '<Tab>', '<C-w>w', { silent = true })
-- bind A-o to "other window" in every mode
-- TODO: these aren't working
vim.keymap.set({ 'n', 'x', 'o' }, '<A-o>', '<C-w>w', { silent = true })
vim.keymap.set('i', '<A-o>', '<C-o><C-w>w', { silent = true })
vim.keymap.set('t', '<A-o>', '<cmd>:!echo hi<CR>') -- [[<C-><C-N><C-w>w]], { silent = true })

-- Automatically reread file contents as its written
vim.o.autoread = true
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
  command = "if mode() != 'c' | checktime | endif",
})
vim.api.nvim_create_autocmd('FileChangedShellPost', {
  command = "echohl WarningMsg | echo 'File changed on disk. Buffer reloaded.' | echohl None",
})

vim.api.nvim_create_autocmd('TermOpen', {
  pattern = 'term://*',
  callback = function(args)
    -- only do this for interactive shell terminals
    local name = vim.api.nvim_buf_get_name(args.buf)
    local shell = vim.fn.fnamemodify(vim.o.shell, ':t')
    if name:match(shell) then
      local job = vim.b[args.buf].terminal_job_id
      if job then
        vim.defer_fn(function()
          vim.api.nvim_chan_send(job, 'source ~/.config/nvim/bashrc_nvim\n')
        end, 50)
      end
    end
  end,
})

vim.keymap.set('n', '<leader>gb', function()
  local file = vim.fn.expand '%:t' -- full path; use '%:p' for full name
  local line = vim.fn.line '.'
  local cmd = string.format('break %s:%d', file, line)
  -- copy to system clipboard (+ register). Change '+' to '"' to copy to unnamed register.
  vim.fn.setreg('+', cmd)
  vim.notify('Copied to clipboard: ' .. cmd)
end, { desc = 'Copy gdb break command for current line' })

-- Go to last buffer
vim.keymap.set('n', '<leader><tab>', '<cmd>b#<CR>', { desc = 'Switch to last buffer' })

-- TODO: add a "which-key enabled" and "lsp-enabled" global that I can toggle
-- there's apparently an `enabled` field in each lazy declaration.

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- PLUGINS
-- TODO: try some of these perhaps
-- - [ ] iron repl run current file: https://github.com/Vigemus/iron.nvim?tab=readme-ov-file
-- - [ ] emacs-server like functionality: https://github.com/mhinz/neovim-remote  this would enable nvim-terminal oriented workflow which is pretty cool
-- - [ ] toggle-term

-- If a plugin spec hints at getting too long, it goes in a file under
-- lua/plugins.
require('lazy').setup({
  { import = 'plugins' },
  {
    'NotAShelf/direnv.nvim',
    config = function()
      require('direnv').setup {}
    end,
  },

  'NMAC427/guess-indent.nvim', -- Detect tabstop and shiftwidth automatically

  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },
  {
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
      delay = 300, -- TODO: tweak this
      icons = {
        mappings = vim.g.have_nerd_font,
        -- If you are using a Nerd Font: set icons.keys to an empty table which will use the
        -- default which-key.nvim defined Nerd Font icons, otherwise define a string table
        keys = {},
      },
      -- Document existing key chains
      spec = {
        { '<leader>s', group = '[S]earch' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      },
    },
  },
  {
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'https://github.com/sainnhe/everforest',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      vim.g.everforest_background = 'hard'
      vim.cmd.colorscheme 'everforest'
    end,
  },

  -- Highlight todo, notes, etc in comments
  { 'folke/todo-comments.nvim', event = 'VimEnter', dependencies = { 'nvim-lua/plenary.nvim' }, opts = { signs = false } },

  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
