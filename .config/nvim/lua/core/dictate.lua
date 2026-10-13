-- Dictation via the same ~/bin/gc-dictate whisper.cpp wrapper the tmux
-- prefix+v binding uses, in --stdout mode so the text lands in the buffer
-- rather than a tmux pane.
--
-- One toggle key: the first press starts recording (the script returns
-- immediately with no output), the second press blocks briefly while whisper
-- runs and then inserts the transcript at the cursor.

local script = vim.fn.expand '~/bin/gc-dictate'

local function insert_at_cursor(text)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { text })
  vim.api.nvim_win_set_cursor(0, { row, col + #text })
end

local function toggle()
  if vim.fn.executable(script) == 0 then
    vim.notify('dictate: ' .. script .. ' not executable', vim.log.levels.ERROR)
    return
  end

  -- Recording state lives in the script's own state dir, so nvim does not need
  -- to track it -- an empty result simply means "recording just started".
  local out = vim.fn.system { script, '--stdout' }
  if vim.v.shell_error ~= 0 then
    vim.notify('dictate: ' .. vim.trim(out), vim.log.levels.ERROR)
    return
  end

  local text = vim.trim(out)
  if text == '' then
    vim.notify('dictate: recording -- press again to stop', vim.log.levels.INFO)
    return
  end

  insert_at_cursor(text)
end

vim.keymap.set({ 'n', 'i' }, '<F6>', function()
  -- From insert mode the cursor may sit past the last char; normalise first.
  toggle()
end, { desc = 'Dictate (whisper) toggle' })

vim.keymap.set('n', '<leader>ad', toggle, { desc = '[A]i [d]ictate toggle' })
