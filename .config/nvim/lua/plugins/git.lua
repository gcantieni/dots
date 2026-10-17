-- Git porcelain (fugitive) and diff/history viewing (diffview), under <leader>g.
-- Hunk-level operations live in gitsigns.lua under <leader>h.
return {
  {
    'tpope/vim-fugitive',
    cmd = { 'Git', 'G', 'Gedit', 'Gread', 'Gwrite', 'Gdiffsplit' },
    init = function()
      -- Bare dotfile repos (see the dots/dotsw shell aliases). They rely on core.worktree being set.
      for cmd, dir in pairs({ Dots = '~/.dots', Dotsw = '~/.dots-work' }) do
        vim.api.nvim_create_user_command(cmd, function(opts)
          vim.b.git_dir = vim.fn.expand(dir)
          vim.cmd('Git ' .. opts.args)
        end, { nargs = '*', desc = 'Fugitive on ' .. dir })
      end

      -- Fugitive's own gq closes the status window, even when it's the last one.
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'fugitive',
        callback = function(ev)
          vim.keymap.set('n', 'q', 'gq', { buffer = ev.buf, remap = true, desc = 'Close git status' })
        end,
      })
    end,
    keys = {
      { '<leader>gs', '<cmd>Git<CR>', desc = '[G]it [s]tatus' },
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
        '<leader>gS',
        function()
          vim.ui.input({ prompt = 'Show commit: ', default = 'HEAD' }, function(rev)
            if rev and rev ~= '' then
              vim.cmd('DiffviewOpen ' .. rev .. '^!')
            end
          end)
        end,
        desc = '[G]it [S]how commit',
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
