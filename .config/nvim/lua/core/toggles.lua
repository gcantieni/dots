-- Editor option toggles, all under <leader>o. LSP inlay hints (<leader>oi) are
-- mapped in plugins/lsp.lua since they need an attached client.

local function map(key, fn, desc)
  vim.keymap.set('n', '<leader>o' .. key, fn, { desc = desc })
end

local function notify(name, on)
  vim.notify(name .. ' ' .. (on and 'on' or 'off'), vim.log.levels.INFO)
end

map('w', require('core.softwrap').toggle, '[O]ption soft [W]rap')

map('s', function()
  vim.wo.spell = not vim.wo.spell
  notify('Spell', vim.wo.spell)
end, '[O]ption [S]pelling')

-- Raw markdown: drop render-markdown and conceal together so they can't drift.
local function set_raw_markdown(raw)
  if raw and vim.wo.conceallevel > 0 then
    vim.w.rendered_conceallevel = vim.wo.conceallevel
  end
  vim.wo.conceallevel = raw and 0 or (vim.w.rendered_conceallevel or 2)
  pcall(vim.cmd, 'RenderMarkdown ' .. (raw and 'buf_disable' or 'buf_enable'))
end

map('m', function()
  local raw = vim.wo.conceallevel > 0
  set_raw_markdown(raw)
  notify('Rendered markdown', not raw)
end, '[O]ption rendered [M]arkdown')

-- Rendering hides conflict markers' surroundings and mangles the hunks, so
-- markdown with merge conflicts opens raw.
vim.api.nvim_create_autocmd('BufWinEnter', {
  group = vim.api.nvim_create_augroup('core_toggles_conflict', { clear = true }),
  callback = function(ev)
    if vim.bo[ev.buf].filetype ~= 'markdown' then
      return
    end
    vim.schedule(function()
      if vim.api.nvim_get_current_buf() == ev.buf and vim.fn.search([[^<<<<<<< ]], 'nw') > 0 then
        set_raw_markdown(true)
      end
    end)
  end,
})
