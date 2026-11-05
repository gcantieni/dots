-- Quick comments on any line/range, sent as one markdown message to the Claude
-- agent chosen in core.claude_send.
local function send_comments()
  require('core.claude_send').with_agent(function(pane)
    vim.g.claude_send_pane = pane
    require('review.quick_comments').send(nil, { clear = true })
  end)
end

-- Side panel width leaving 80 columns (+1 separator) for the main window.
local function toggle_panel()
  local width = math.max(24, math.min(50, vim.o.columns - 81))
  require('review.config').get().quick_comments.panel.width = width
  require('review.quick_comments').toggle_panel()
end

return {
  'vuki656/review.nvim',
  event = 'VeryLazy',
  cmd = 'Review',
  keys = {
    { '<leader>cn', '<cmd>Review qc<cr>', desc = 'Add a [n]ote for Claude' },
    { '<leader>cn', ':Review qc<cr>', mode = 'x', desc = 'Add a [n]ote on range for Claude' },
    { '<leader>cl', toggle_panel, desc = 'List Claude comments' },
    { '<leader>cs', send_comments, desc = 'Send comments to Claude' },
  },
  opts = {
    quick_comments = { panel = { position = 'right', width = 40 } },
    export = {
      on_export = function(content)
        return require('core.claude_send').send_sync(content)
      end,
    },
  },
}
