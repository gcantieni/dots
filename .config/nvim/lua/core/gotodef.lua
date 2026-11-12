-- gd as the one "go to definition": the language server's answer when it has
-- one, help links in help buffers, and Vim's text-search gd otherwise.

local method = 'textDocument/definition'

local function builtin(keys)
  local ok, err = pcall(vim.cmd, 'normal! ' .. keys)
  if not ok then
    vim.notify((err:gsub('^Vim%b():', '')), vim.log.levels.ERROR)
  end
end

local function pick(items)
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local make_entry = require 'telescope.make_entry'
  local conf = require('telescope.config').values
  local opts = {}
  pickers
    .new(opts, {
      prompt_title = 'LSP Definitions',
      finder = finders.new_table { results = items, entry_maker = make_entry.gen_from_quickfix(opts) },
      previewer = conf.qflist_previewer(opts),
      sorter = conf.generic_sorter(opts),
      push_cursor_on_edit = true,
      push_tagstack_on_edit = true,
    })
    :find()
end

local function goto_definition()
  if vim.bo.buftype == 'help' then
    return builtin(vim.keycode '<C-]>')
  end
  local bufnr = vim.api.nvim_get_current_buf()
  if #vim.lsp.get_clients { bufnr = bufnr, method = method } == 0 then
    return builtin 'gd'
  end
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  vim.lsp.buf_request_all(bufnr, method, function(client)
    return vim.lsp.util.make_position_params(win, client.offset_encoding)
  end, function(results)
    if vim.api.nvim_get_current_win() ~= win or vim.api.nvim_win_get_buf(win) ~= bufnr or not vim.deep_equal(vim.api.nvim_win_get_cursor(win), cursor) then
      return
    end
    local items, first, first_encoding = {}, nil, nil
    for client_id, r in pairs(results) do
      local client = vim.lsp.get_client_by_id(client_id)
      if r.result and client then
        local locs = vim.islist(r.result) and r.result or { r.result }
        if #locs > 0 and not first then
          first, first_encoding = locs[1], client.offset_encoding
        end
        vim.list_extend(items, vim.lsp.util.locations_to_items(locs, client.offset_encoding))
      end
    end
    if #items == 0 then
      vim.notify('No LSP definition; used text search', vim.log.levels.INFO)
      return builtin 'gd'
    end
    if #items == 1 then
      vim.lsp.util.show_document(first, first_encoding, { focus = true })
    else
      pick(items)
    end
  end)
end

vim.keymap.set('n', 'gd', goto_definition, { desc = 'Goto definition (LSP, help link, or text search)' })
