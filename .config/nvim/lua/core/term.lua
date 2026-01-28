-- Track most recently used terminal buffer
local last_terminal_buf = nil
local last_non_terminal_buf = nil

-- Autocmd to track buffer usage
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    local bt = vim.bo[buf].buftype

    if bt == 'terminal' then
      last_terminal_buf = buf
    elseif bt ~= '' then
      -- ignore special buffers like help, quickfix, etc.
      return
    else
      last_non_terminal_buf = buf
    end
  end,
})

local function toggle_terminal_or_buffer()
  local buf = vim.api.nvim_get_current_buf()
  local bt = vim.bo[buf].buftype

  -- If we're in a terminal, go back to last normal buffer
  if bt == 'terminal' then
    if last_non_terminal_buf and vim.api.nvim_buf_is_valid(last_non_terminal_buf) then
      vim.api.nvim_set_current_buf(last_non_terminal_buf)
    else
      vim.notify('No previous buffer found', vim.log.levels.WARN)
    end
    return
  end

  -- Otherwise, go to last terminal
  if last_terminal_buf and vim.api.nvim_buf_is_valid(last_terminal_buf) then
    vim.api.nvim_set_current_buf(last_terminal_buf)
  else
    vim.notify('No terminal buffer found', vim.log.levels.WARN)
  end
end

-- Keymaps
-- This will actually be mapped to Ctrl-/
vim.keymap.set({ 'n', 'i' }, '<C-_>', toggle_terminal_or_buffer, { desc = 'Jump to last terminal' })
vim.keymap.set('t', '<C-_>', function()
  vim.cmd 'stopinsert'
  toggle_terminal_or_buffer()
end, { desc = 'Leave terminal to last buffer' })
