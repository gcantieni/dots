-- Show only the line text for one special quickfix list id
--vim.o.quickfixtextfunc = 'QFTextOnlyForOneList'
vim.o.quickfixtextfunc = 'v:lua.QFTextOnlyForOneList'

function _G.QFTextOnlyForOneList(info)
  local qf = vim.fn.getqflist { id = info.id, items = 0 }
  local items = qf.items
  local out = {}

  local special_id = vim.g.qf_text_only_id

  for i = info.start_idx, info.end_idx do
    local it = items[i]
    if info.id == special_id then
      -- text only (what you asked for)
      out[#out + 1] = it.text or ''
    else
      -- reasonable default for other quickfix lists
      local fname = (it.bufnr and it.bufnr > 0) and vim.fn.bufname(it.bufnr) or (it.filename or '')
      out[#out + 1] = string.format('%s:%d:%d: %s', fname, it.lnum or 0, it.col or 0, it.text or '')
    end
  end

  return out
end

local function cword()
  return vim.fn.expand '<cword>'
end

_G.VimgrepCword = function()
  local pat = cword()
  print('Cword: ' .. pat)
  if not pat or pat == '' then
    return
  end

  -- Make it "literal" so symbols in the word don't act like regex
  -- \V = very nomagic, then escape /
  local esc = pat:gsub('\\', '\\\\'):gsub('/', '\\/')

  vim.cmd('silent! vimgrep /\\V' .. esc .. '/j %')

  vim.fn.setqflist({}, 'a', { title = 'vimgrep %: ' .. pat })
  vim.g.qf_text_only_id = vim.fn.getqflist({ id = 0 }).id

  vim.cmd 'copen'
end

-- Progressive narrowing
function _G.QFFilter(pattern)
  if not pattern or pattern == '' then
    return
  end

  local qf = vim.fn.getqflist { items = 0, title = 0 }
  local filtered = {}

  for _, it in ipairs(qf.items) do
    if (it.text or ''):find(pattern) then
      filtered[#filtered + 1] = it
    end
  end

  -- ✅ key change: items go in {what}, not as the first arg
  vim.fn.setqflist({}, 'r', {
    items = filtered,
    title = (qf.title or 'Quickfix') .. ' | filter: ' .. pattern,
  })

  vim.cmd 'copen'
end

vim.g.qf_stack = vim.g.qf_stack or {}

function _G.QFFilterStack(pattern)
  if not pattern or pattern == '' then
    return
  end

  local cur = vim.fn.getqflist { items = 0, title = 0 }
  table.insert(vim.g.qf_stack, cur.items)

  local out = {}
  for _, it in ipairs(cur.items) do
    if (it.text or ''):find(pattern) then
      out[#out + 1] = it
    end
  end

  vim.fn.setqflist({}, 'r', {
    items = out,
    title = (cur.title or 'Quickfix') .. ' | filter: ' .. pattern,
  })

  vim.cmd 'copen'
end

-- Session-local stacks keyed by quickfix list id (NOT vim.g)
local qf_stacks = {}

local function qf_get()
  -- id=0 means "current quickfix list"
  return vim.fn.getqflist { id = 0, items = 0, title = 0 }
end

local function qf_push_state(qf)
  if not qf or not qf.id then
    return
  end
  local id = qf.id
  local stack = qf_stacks[id]
  if stack == nil then
    stack = {}
    qf_stacks[id] = stack
  end
  table.insert(stack, { items = qf.items or {}, title = qf.title })
end

local function qf_apply(items, title)
  -- Use {items=...} form to avoid E475 on some builds
  vim.fn.setqflist({}, 'r', { items = items, title = title })
  vim.cmd 'copen'
end

local function qf_filter_literal(pattern)
  if not pattern or pattern == '' then
    return
  end

  local qf = qf_get()
  if not qf or not qf.id then
    return
  end

  qf_push_state(qf)

  local out = {}
  for _, it in ipairs(qf.items or {}) do
    if (it.text or ''):find(pattern, 1, true) then -- literal substring
      out[#out + 1] = it
    end
  end

  qf_apply(out, (qf.title or 'Quickfix') .. ' | filter: ' .. pattern)
end

-- Filter by word under cursor
_G.QFFilterCwordStack = function()
  local pat = vim.fn.expand '<cword>' -- switch to <cWORD> if you prefer
  qf_filter_literal(pat)
end

-- Interactive filter prompt
_G.QFFilterInteractiveStack = function()
  vim.ui.input({ prompt = 'Quickfix filter: ' }, function(pat)
    qf_filter_literal(pat)
  end)
end

-- Undo one filter step for the current quickfix list
_G.QFUndoFilter = function()
  local qf = qf_get()
  if not qf or not qf.id then
    return
  end

  local stack = qf_stacks[qf.id]
  if not stack or #stack == 0 then
    return
  end

  local prev = table.remove(stack)
  qf_apply(prev.items or {}, prev.title)
end

-- Clear stack for current list
_G.QFClearFilterStack = function()
  local qf = qf_get()
  if not qf or not qf.id then
    return
  end
  qf_stacks[qf.id] = {}
end

-- Mappings
vim.keymap.set('n', '<leader>vg', _G.VimgrepCword, { desc = 'vimgrep current file for cword (text-only qf)' })
vim.keymap.set('n', '<leader>qf', _G.QFFilterCwordStack, { desc = 'Filter quickfix by cword (stacked)' })
vim.keymap.set('n', '<leader>qi', _G.QFFilterInteractiveStack, { desc = 'Filter quickfix interactively (stacked)' })
vim.keymap.set('n', '<leader>qu', _G.QFUndoFilter, { desc = 'Undo quickfix filter' })
vim.keymap.set('n', '<leader>qC', _G.QFClearFilterStack, { desc = 'Clear quickfix filter stack' })
