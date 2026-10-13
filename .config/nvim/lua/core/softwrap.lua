-- Soft-wrapped prose.
--
-- A few markdown documents keep each paragraph on a single physical line, so
-- that copying a paragraph into Confluence yields a paragraph rather than a
-- column of broken lines. Hard-wrapping those files would defeat the point and
-- reading them unwrapped is worse, so they are displayed as though wrapped;
-- nothing on disk is touched. Membership is a property of the document, not of
-- its location, so it is recognized from the line lengths themselves --
-- `<leader>fw` overrides the guess in either direction.

local M = {}

-- Hard-wrapped prose stays inside 'textwidth' (80, see core/autocmds.lua), so
-- anything much wider is a one-line paragraph. A couple of stray long lines
-- prove nothing: a bare URL or a table row can run to any width.
local LONG_LINE = 120
local ENOUGH_LONG_LINES = 3
local SAMPLE_LINES = 500

local FILETYPES = { 'markdown', 'text' }

-- Options soft wrap takes over. The window-local ones outlive the buffer that
-- asked for them, so they are put back when an ordinary buffer arrives.
local BORROWED_WIN = { 'wrap', 'linebreak', 'breakindent', 'breakindentopt' }

local DISPLAY_MOTIONS = { 'j', 'k', '0', '$' }

-- Wrapped list items hang under their own text. Doubles as the mark of a
-- soft-wrapped window: nothing else sets 'breakindentopt', and unlike a window
-- variable it is carried along by :split, so a clone that inherited the wrap
-- options is still recognized as needing them undone.
local BREAKINDENTOPT = 'list:-1'

--- Does this buffer hold whole paragraphs on single lines?
function M.detect(buf)
  local long, in_fence = 0, false
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, SAMPLE_LINES, false)) do
    if line:match '^%s*```' then
      in_fence = not in_fence
    elseif not in_fence and #line > LONG_LINE and not line:match '^    ' and not line:match '^%s*|' then
      long = long + 1
      if long >= ENOUGH_LONG_LINES then
        return true
      end
    end
  end
  return false
end

-- Deliberately not vim.bo/vim.wo: assigning through those sets the global
-- value as well, which both leaks into later buffers and destroys the default
-- this module restores from.
local function setlocal(scope, id, name, value)
  vim.api.nvim_set_option_value(name, value, { scope = 'local', [scope] = id })
end

function M.enable(buf, win)
  setlocal('buf', buf, 'textwidth', 0)
  setlocal('win', win, 'wrap', true)
  setlocal('win', win, 'linebreak', true) -- break between words, not mid-word
  setlocal('win', win, 'breakindent', true)
  setlocal('win', win, 'breakindentopt', BREAKINDENTOPT)
  setlocal('win', win, 'colorcolumn', '') -- there is no column to stay inside of
  for _, key in ipairs(DISPLAY_MOTIONS) do
    vim.keymap.set({ 'n', 'x' }, key, 'g' .. key, { buffer = buf, desc = 'Move by display line' })
  end
  vim.b[buf].softwrap = true
end

--- Hand the window back its global defaults. Left alone: 'textwidth' and
--- 'colorcolumn', which the prose FileType autocmd has already set for
--- whichever buffer just arrived.
function M.clear_window(win)
  if vim.api.nvim_get_option_value('breakindentopt', { scope = 'local', win = win }) ~= BREAKINDENTOPT then
    return
  end
  for _, name in ipairs(BORROWED_WIN) do
    setlocal('win', win, name, vim.go[name])
  end
end

function M.disable(buf, win)
  M.clear_window(win)
  vim.api.nvim_exec_autocmds('FileType', { buffer = buf, modeline = false })
  for _, key in ipairs(DISPLAY_MOTIONS) do
    pcall(vim.keymap.del, { 'n', 'x' }, key, { buffer = buf })
  end
  vim.b[buf].softwrap = false
end

function M.toggle()
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  if vim.b[buf].softwrap then
    M.disable(buf, win)
  else
    M.enable(buf, win)
  end
  vim.notify('Soft wrap ' .. (vim.b[buf].softwrap and 'on' or 'off'), vim.log.levels.INFO)
end

local function wants_softwrap(buf)
  if not vim.tbl_contains(FILETYPES, vim.bo[buf].filetype) then
    return false
  end
  local decided = vim.b[buf].softwrap
  if decided ~= nil then
    return decided
  end
  return M.detect(buf)
end

vim.keymap.set('n', '<leader>fw', M.toggle, { desc = '[F]ile soft [W]rap' })

-- BufWinEnter rather than FileType: half of these options are window-local, so
-- they have to be reapplied every time the buffer lands in a window (and undone
-- when some other buffer takes the window over). It also runs late enough to
-- win against the runtime markdown ftplugin.
local aug = vim.api.nvim_create_augroup('core.softwrap', { clear = true })
vim.api.nvim_create_autocmd('BufWinEnter', {
  group = aug,
  callback = function(args)
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_buf(win) ~= args.buf then
      return
    end
    if wants_softwrap(args.buf) then
      M.enable(args.buf, win)
    else
      M.clear_window(win)
    end
  end,
})

return M
