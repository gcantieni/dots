-- Quick comments on any line/range, sent as one markdown message to the Claude
-- agent chosen in core.claude_send.
local function send_comments()
  require('core.claude_send').with_agent(function(pane)
    vim.g.claude_send_pane = pane
    require('review.quick_comments').send(nil, { clear = true })
  end)
end

return {
  'vuki656/review.nvim',
  event = 'VeryLazy',
  cmd = 'Review',
  keys = {
    { '<leader>cq', '<cmd>Review qc<cr>', desc = 'Comment line for Claude' },
    { '<leader>cq', ':Review qc<cr>', mode = 'x', desc = 'Comment range for Claude' },
    { '<leader>cl', '<cmd>Review qp<cr>', desc = 'List Claude comments' },
    { '<leader>cS', send_comments, desc = 'Send comments to Claude' },
  },
  opts = {
    export = {
      on_export = function(content)
        return require('core.claude_send').send_sync(content)
      end,
    },
  },
}
