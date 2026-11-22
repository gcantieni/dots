-- Git porcelain (fugitive) and diff/history viewing (diffview), under <leader>g.
-- Hunk-level operations live in gitsigns.lua under <leader>h.
return {
  {
    'tpope/vim-fugitive',
    cmd = { 'Git', 'G', 'Gedit', 'Gread', 'Gwrite', 'Gdiffsplit' },
    init = function()
      -- The dotfile repos (see the dots/dotsw shell aliases) keep no .git under
      -- the work tree, so nothing finds them from a buffer. :Dots / :Dotsw point
      -- this nvim's whole git environment at one, so fugitive, gitsigns and
      -- diffview all agree; :Dots! restores the normal per-project detection
      -- (fugitive keeps its ~ -> ~/.dots mapping, which only shows up for files
      -- in no other repo). Any args go on to :Git, so `:Dots status` works.
      local function git_env(dir, args)
        dir = dir and vim.fn.expand(dir)
        if dir and vim.fn.isdirectory(dir) == 0 then
          return vim.notify('no repo at ' .. dir, vim.log.levels.ERROR)
        end
        vim.env.GIT_DIR = dir
        vim.env.GIT_WORK_TREE = dir and vim.env.HOME or nil

        -- Both plugins cache the repo they resolved, so make them look again.
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          pcall(vim.api.nvim_buf_del_var, buf, 'git_dir')
        end
        local ok, gs = pcall(require, 'gitsigns')
        if ok then
          gs.detach_all()
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) then
              gs.attach { bufnr = buf }
            end
          end
        end

        if args ~= '' then
          vim.cmd('Git ' .. args)
        else
          vim.notify('git dir: ' .. (vim.env.GIT_DIR or '(per project)'))
        end
      end

      for cmd, dir in pairs { Dots = '~/.dots', Dotsw = '~/.dots-work' } do
        vim.api.nvim_create_user_command(cmd, function(opts)
          git_env(not opts.bang and dir or nil, opts.args)
        end, { nargs = '*', bang = true, desc = 'Point nvim at ' .. dir .. ' (! to clear)' })
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
      -- Quick review comments for Claude (review.nvim; <leader>cs sends them).
      local comment = { 'n', 'c', '<cmd>Review qc<CR>', { desc = 'Comment for Claude' } }
      local comment_range = { 'x', 'c', ':Review qc<CR>', { desc = 'Comment range for Claude' } }
      return {
        enhanced_diff_hl = true,
        keymaps = {
          view = { close, comment, comment_range },
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
