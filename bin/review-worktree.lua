-- Loaded by ~/bin/review-worktree. Closing the last diffview sends unsent review comments
-- to the Claude pane ($CLAUDE_PANE), then quits nvim unless there are unsaved changes.
vim.api.nvim_create_autocmd('User', {
  pattern = 'DiffviewViewClosed',
  callback = function()
    vim.schedule(function()
      -- Another diffview (e.g. the <leader>gd staging view) is still open: keep going.
      if #require('diffview.lib').views > 0 then
        return
      end
      local ok, qc = pcall(require, 'review.quick_comments')
      if ok then
        qc.send(nil, { clear = true, silent = true })
      end
      if not pcall(vim.cmd, 'qa') then
        vim.notify('unsaved changes; not quitting', vim.log.levels.WARN)
      end
    end)
  end,
})
