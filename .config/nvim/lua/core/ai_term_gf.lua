local termcwd = require 'core.termcwd'

local function parse_target()
  local file = vim.fn.expand '<cfile>'
  local text = vim.api.nvim_get_current_line()
  local lnum = text:match(vim.pesc(file) .. ':(%d+):%d+:')
  if lnum then
    return file, tonumber(lnum)
  end
  local path
  path, lnum = file:match '^(.-):(%d+)$'
  return path or file, tonumber(lnum)
end

local function open_target(path, line)
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  if line then
    vim.api.nvim_win_set_cursor(0, { line, 0 })
  end
end

local function resolve_path(cwd, path)
  if vim.startswith(path, '/') then
    return vim.fs.normalize(path)
  end
  return vim.fs.normalize(cwd .. '/' .. path)
end

local function ai_term_gf()
  local file = vim.fn.expand '<cfile>'
  if file == '' then
    return
  end
  local line
  file, line = parse_target()
  local cwd = termcwd.get_terminal_shell_cwd(0) or vim.fn.getcwd()
  file = resolve_path(cwd, file)
  if vim.api.nvim_get_mode().mode:sub(1, 1) == 't' then
    vim.cmd 'stopinsert'
  end
  if vim.uv.fs_stat(file) then
    open_target(file, line)
    return
  end
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  require('telescope.builtin').find_files {
    cwd = cwd,
    default_text = vim.fs.basename(file),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        open_target(resolve_path(cwd, selection.path or selection.filename or selection[1]), line)
      end)
      return true
    end,
  }
end

-- Cleared augroup so <leader>R replaces this handler instead of stacking.
local aug = vim.api.nvim_create_augroup('core.ai_term_gf', { clear = true })
vim.api.nvim_create_autocmd('TermOpen', {
  group = aug,
  callback = function(args)
    local opts = { buffer = args.buf, desc = 'AI terminal gf' }
    vim.keymap.set('n', 'gf', ai_term_gf, opts)
    vim.keymap.set('t', 'gf', ai_term_gf, opts)
  end,
})
