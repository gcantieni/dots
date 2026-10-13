return {
  'akinsho/toggleterm.nvim',
  version = '*',
  opts = {
    direction = 'horizontal', -- bottom split: keeps full code width, code + terminal visible
    size = 15,
    persist_size = false, -- always reopen at `size` instead of remembering a resized (stuck-large) height
    open_mapping = [[<C-_>]], -- Ctrl-/ toggles the terminal in normal/insert/terminal mode
    float_opts = { border = 'curved' }, -- used by the <leader>ty float flip
    -- insert_mappings / terminal_mappings default to true, so open_mapping is
    -- active everywhere. Bare :ToggleTerm smart-toggles (count targets a specific
    -- terminal, e.g. 2<C-_>), and only manages toggleterm terminals so the Codex
    -- sidebar is left alone.
  },
  config = function(_, opts)
    require('toggleterm').setup(opts)
    -- Toggle terminals 1-4 with hjkl: j=1, k=2, l=3, h=4.
    local map = vim.keymap.set
    map('n', '<leader>tj', '<cmd>1ToggleTerm<cr>', { desc = 'Terminal [1]' })
    map('n', '<leader>tk', '<cmd>2ToggleTerm<cr>', { desc = 'Terminal [2]' })
    map('n', '<leader>tl', '<cmd>3ToggleTerm<cr>', { desc = 'Terminal [3]' })
    map('n', '<leader>th', '<cmd>4ToggleTerm<cr>', { desc = 'Terminal [4]' })

    -- Flip the current/last terminal between bottom split and a big float, for
    -- the occasional long command. <leader>ty is two-handed so it's quick.
    local terminal = require('toggleterm.terminal')
    local function flip_float()
      local t = terminal.get(vim.b.toggle_number or -1, true) or terminal.get_last_focused()
      if not t then
        vim.notify('No terminal to float', vim.log.levels.WARN)
        return
      end
      local to = (t.direction == 'float') and 'horizontal' or 'float'
      if t:is_open() then t:close() end
      t:change_direction(to)
      t:open()
    end
    map('n', '<leader>ty', flip_float, { desc = 'Terminal float/unfloat current' })

    -- Remote-safe alias for the C-/ open_mapping: browser terminals (Prisma)
    -- swallow Ctrl-/, so F8 does the same smart-toggle. <Cmd> toggles cleanly
    -- from terminal mode without the <C-\><C-o> dance.
    map({ 'n', 'i', 't' }, '<F8>', '<Cmd>ToggleTerm<CR>', { silent = true, desc = 'Toggle terminal' })
  end,
}
