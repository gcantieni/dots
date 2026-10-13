vim.g.mapleader = ' '
vim.g.maplocalleader = ','
vim.g.have_nerd_font = true
-- Options, keymaps, user commands, and autocmds live in lua/core/*.lua so that
-- <leader>R can hot-reload them. Only leader keys and have_nerd_font stay here
-- (they must be set before lazy.setup, and don't reload meaningfully).

---- Load all Lua files in ~/.config/lua/core
local config_dir = vim.fn.stdpath 'config'
local core_dir = config_dir .. '/lua/core'

local function load_core_modules()
  local core_files = vim.fn.glob(core_dir .. '/*.lua', false, true)
  table.sort(core_files)

  local errors = {}
  for _, f in ipairs(core_files) do
    local mod = 'core.' .. vim.fn.fnamemodify(f, ':t:r')
    local ok, err = pcall(require, mod)
    if not ok then
      table.insert(errors, mod .. ': ' .. err)
    end
  end

  return errors
end

local function reload_core_config()
  for name, _ in pairs(package.loaded) do
    if name == 'core' or name:match '^core%.' then
      package.loaded[name] = nil
    end
  end

  local errors = load_core_modules()
  if #errors == 0 then
    vim.notify('Reloaded core config', vim.log.levels.INFO)
    return
  end

  vim.notify(table.concat(errors, '\n'), vim.log.levels.ERROR, { title = 'Core reload failed' })
end

for _, err in ipairs(load_core_modules()) do
  vim.notify(err, vim.log.levels.ERROR, { title = 'Core load failed' })
end

-- <leader>R reloads lua/core/* (options, keymaps, commands, autocmds) in place.
-- It does NOT reload plugin specs -- for those, use :Lazy sync / :Lazy reload
-- <name> or restart nvim.
vim.keymap.set('n', '<leader>R', reload_core_config, { desc = '[R]eload core config (not plugins)' })

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
-- - iron repl run current file: https://github.com/Vigemus/iron.nvim?tab=readme-ov-file

-- If a plugin spec hints at getting too long, it goes in a file under
-- lua/plugins.
require('lazy').setup({
  { import = 'plugins' },

  { 'NMAC427/guess-indent.nvim', opts = {} }, -- Detect tabstop and shiftwidth automatically

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
        { '<leader>t', group = '[T]erm' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
        { '<leader>ht', group = 'Git hunk [t]oggle' },
        { '<leader>p', group = '[P]4' },
        { '<leader>q', group = '[Q]uickfix' },
        { '<leader>f', group = '[F]ile' },
        { '<leader>j', group = '[J]ournal' },
        { '<leader>g', group = '[G]it' },
        { '<leader>d', group = '[D]ebug' },
        { '<leader>v', group = '[V]imgrep' },
        { '<leader>l', group = '[L]sp' },
      },
    },
  },
  {
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'https://github.com/sainnhe/everforest',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      vim.o.background = 'dark'
      vim.g.everforest_background = 'hard'
      vim.g.everforest_better_performance = 1
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
