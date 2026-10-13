-- Git porcelain (fugitive) and diff/history viewing (diffview), under <leader>g.
-- Hunk-level operations live in gitsigns.lua under <leader>h.
return {
  {
    'tpope/vim-fugitive',
    cmd = { 'Git', 'G', 'Gedit', 'Gread', 'Gwrite', 'Gdiffsplit' },
    keys = {
      { '<leader>gg', '<cmd>Git<CR>', desc = '[G]it status' },
      { '<leader>gc', '<cmd>Git commit<CR>', desc = '[G]it [c]ommit' },
      { '<leader>gb', '<cmd>Git blame<CR>', desc = '[G]it [b]lame' },
      { '<leader>gl', '<cmd>Git log --oneline --decorate --graph<CR>', desc = '[G]it [l]og' },
      { '<leader>ge', '<cmd>Gedit<CR>', desc = '[G]it [e]dit object (sha/branch)' },
    },
  },
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory', 'DiffviewToggleFiles' },
    opts = function()
      local close = { 'n', 'q', '<cmd>DiffviewClose<CR>', { desc = 'Close diffview' } }
      return {
        enhanced_diff_hl = true,
        keymaps = {
          view = { close },
          file_panel = { close },
          file_history_panel = { close },
        },
      }
    end,
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<CR>', desc = '[G]it [d]iff working tree' },
      { '<leader>gq', '<cmd>DiffviewClose<CR>', desc = '[G]it diff [q]uit' },
      { '<leader>gh', '<cmd>DiffviewFileHistory<CR>', desc = '[G]it [h]istory (repo)' },
      { '<leader>gf', '<cmd>DiffviewFileHistory %<CR>', desc = '[G]it history ([f]ile)' },
      -- `<rev>^!` is git's "this commit against its parent" syntax.
      {
        '<leader>gs',
        function()
          vim.ui.input({ prompt = 'Show commit: ', default = 'HEAD' }, function(rev)
            if rev and rev ~= '' then
              vim.cmd('DiffviewOpen ' .. rev .. '^!')
            end
          end)
        end,
        desc = '[G]it [s]how commit',
      },
      {
        '<leader>gr',
        function()
          vim.ui.input({ prompt = 'Diff against revision: ', default = 'HEAD' }, function(rev)
            if rev and rev ~= '' then
              vim.cmd('DiffviewOpen ' .. rev)
            end
          end)
        end,
        desc = '[G]it diff vs [r]evision',
      },
    },
  },
}
