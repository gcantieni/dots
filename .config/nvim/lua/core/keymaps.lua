-- Keymaps and user commands. Reloadable via <leader>R.
-- The <leader>R binding itself lives in init.lua alongside reload_core_config.
-- Keymaps and user commands overwrite on re-run, so re-sourcing is idempotent.

-- Prevent quitting out of multiple nvim buffers accidentally
vim.api.nvim_create_user_command('SafeQuit', function()
  -- If the current tab has a split, :q just closes that window (won't exit nvim), so allow it.
  local windows = vim.fn.winnr '$'
  local buffers = vim.fn.len(vim.fn.getbufinfo { buflisted = 1 })
  if windows == 1 and buffers > 1 then
    print 'Multiple buffers open — use :qa to quit'
  else
    vim.cmd 'q'
  end
end, {})

vim.cmd 'cnoreabbrev q SafeQuit'

vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

vim.keymap.set({ 'i', 's' }, '<Esc>', function()
  vim.snippet.stop()
  return '<Esc>'
end, { expr = true })

vim.keymap.set({ 'v', 'x', 'n' }, '<C-y>', '"+y', { desc = 'System clipboard yank.' })
vim.keymap.set('n', '<leader>qo', vim.diagnostic.setloclist, { desc = '[Q]uickfix list [O]pen' })
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('n', '<leader>fs', '<cmd>:w<CR>', { desc = '[F]ile [s]ave' })
vim.keymap.set('n', '<leader>w', '<cmd>cd %:h<cr>', { desc = 'C[W]D' })
vim.keymap.set('i', 'kj', '<Esc>')
vim.keymap.set('t', 'kj', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- could make more of a prefix someday.
local function toggle_file_spelling()
  vim.wo.spell = not vim.wo.spell
end

local function yank_current_file_path()
  local file_path = vim.fn.expand '%:p'
  vim.fn.setreg('+', file_path)
  print('Yanked: ', file_path)
end
vim.keymap.set('n', '<leader>fp', toggle_file_spelling, { desc = '[F]ile s[P]elling' })
vim.keymap.set('n', '<leader>fy', yank_current_file_path, { desc = '[F]ile [Y]ank path' })

local function open_proj_file(file)
  local base = vim.fn.getenv 'PROJ'
  if base == '' then
    vim.notify('PROJ is not set', vim.log.levels.ERROR)
    return
  end
  vim.cmd('edit ' .. base .. '/' .. file)
end

-- j for Journal, or proJ
vim.keymap.set('n', '<leader>jn', function()
  local base = vim.fn.getenv 'PROJ'
  if base == '' then
    vim.notify('PROJ is not set', vim.log.levels.ERROR)
    return
  end
  local md = base .. '/notes.md'
  local txt = base .. '/notes.txt'
  local target = (vim.fn.filereadable(txt) == 1 and vim.fn.filereadable(md) == 0) and txt or md
  vim.cmd('edit ' .. target)
end, { desc = 'Open notes' })
vim.keymap.set('n', '<leader>jt', function()
  open_proj_file 'todo.txt'
end, { desc = 'Open todos' })

vim.api.nvim_create_user_command('SyncTermCwd', function()
  local cwd = vim.b.terminal_cwd
  if cwd and cwd ~= '' then
    vim.cmd('cd ' .. cwd)
    print('Synced nvim cwd to:', cwd)
  else
    print 'Not a terminal buffer or cwd unavailable'
  end
end, {})

-- Smart <leader>w mapping:
-- - normal buffer  → cd %:h
-- - terminal buffer → SyncTermCwd
vim.keymap.set('n', '<leader>w', function()
  if vim.bo.buftype == 'terminal' then
    vim.cmd 'SyncTermCwd'
  else
    -- equivalent to :cd %:h
    vim.cmd 'cd %:h'
    print('cd to ' .. vim.fn.expand '%:h')
  end
end, { desc = 'C[W]D (buffer dir or SyncTermCwd in terminal)' })

-- bind A-o to "other window" in every mode
vim.keymap.set({ 'n', 'x', 'o' }, '<A-o>', '<C-w>w', { silent = true })
vim.keymap.set('i', '<A-o>', '<C-o><C-w>w', { silent = true })
vim.keymap.set('t', '<A-o>', '<C-\\><C-o><C-w>w', { silent = true })

-- Window resizing. Ctrl+arrows work in terminal mode too (via <Cmd>, which
-- doesn't leave the mode), so you can shrink an oversized toggleterm without
-- dropping out of it. <leader>= snaps every split back to equal -- the quick fix
-- when one gets stuck too tall/wide.
vim.keymap.set({ 'n', 't' }, '<C-Up>', '<Cmd>resize +3<CR>', { silent = true, desc = 'Taller window' })
vim.keymap.set({ 'n', 't' }, '<C-Down>', '<Cmd>resize -3<CR>', { silent = true, desc = 'Shorter window' })
vim.keymap.set({ 'n', 't' }, '<C-Left>', '<Cmd>vertical resize -4<CR>', { silent = true, desc = 'Narrower window' })
vim.keymap.set({ 'n', 't' }, '<C-Right>', '<Cmd>vertical resize +4<CR>', { silent = true, desc = 'Wider window' })
vim.keymap.set('n', '<leader>=', '<Cmd>wincmd =<CR>', { silent = true, desc = 'Equalize window sizes' })

-- Jump focus to the previous window and back. Alt-keys are unreliable over
-- SSH/tmux (and browser terminals like Prisma swallow them), so use a function
-- key. <Cmd> works in insert/terminal mode without leaving it, so returning to a
-- terminal window drops you back into insert. Insert mode is included so the
-- remote-safe path matches the Alt-o coverage.
vim.keymap.set({ 'n', 'i', 't' }, '<F7>', '<Cmd>wincmd p<CR>', { silent = true, desc = 'Focus previous window' })

vim.keymap.set('n', '<leader>db', function()
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
