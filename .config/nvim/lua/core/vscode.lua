-- Hand the current buffer off to VS Code for a GUI debug session: same project,
-- same file, same cursor, ready for F5. Neovim stays the editor of record; VS
-- Code is only borrowed for its debugger, and the project's .vscode/launch.json
-- keeps both sides on the same launch arguments (see plugins/debug.lua).
-- Reloadable via <leader>R.

local M = {}

local uv = vim.uv or vim.loop

-- Paths that mark a project root when they exist under it, e.g. a build
-- directory the launch configs are written relative to. Checked nearest
-- ancestor first, before the markers below. Other modules add to this.
M.root_probes = {}

local function is_probed_root(dir)
  for _, probe in ipairs(M.root_probes) do
    if uv.fs_stat(dir .. '/' .. probe) then
      return true
    end
  end
  return false
end

-- Marker test for other projects. `.vscode` only counts when it actually
-- holds workspace config: ~/.vscode is VS Code's own extension directory, and
-- accepting it bare would make $HOME the root of everything under it.
local function is_project_marker(name, dir)
  if name == '.git' or name == '.p4config' then
    return true
  end
  if name ~= '.vscode' then
    return false
  end
  for _, f in ipairs { 'launch.json', 'tasks.json', 'settings.json' } do
    if uv.fs_stat(dir .. '/.vscode/' .. f) then
      return true
    end
  end
  return false
end

--- Project root to open as the VS Code workspace folder.
---@param path string Absolute path of a file (or directory) inside the project.
---@return string
function M.project_root(path)
  local dir = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)

  local candidate = dir
  while candidate do
    if is_probed_root(candidate) then
      return candidate
    end
    local parent = vim.fs.dirname(candidate)
    if parent == candidate then
      break
    end
    candidate = parent
  end

  return vim.fs.root(dir .. '/', is_project_marker) or dir
end

-- `code` is fire-and-forget: it exits as soon as the window is told to open, so
-- only a non-zero exit is worth surfacing.
local function spawn(cmd)
  local function report(code, stderr)
    if code == 0 then
      return
    end
    local msg = table.concat({ 'code exited ' .. code, stderr }, '\n')
    vim.notify(vim.trim(msg), vim.log.levels.ERROR)
  end

  if vim.system then
    vim.system(cmd, { text = true }, function(out)
      vim.schedule(function()
        report(out.code, out.stderr)
      end)
    end)
    return
  end

  local stderr = {}
  vim.fn.jobstart(cmd, {
    stderr_buffered = true,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr, data)
      end
    end,
    on_exit = function(_, code)
      report(code, table.concat(stderr, '\n'))
    end,
  })
end

--- Open the current file in VS Code at the cursor, with the project root as the
--- workspace folder, so F5 starts the workspace's own debug configuration.
function M.debug_in_vscode()
  local file = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= '' or file == '' then
    vim.notify('No file in this buffer to hand off to VS Code', vim.log.levels.WARN)
    return
  end

  if vim.fn.executable 'code' == 0 then
    vim.notify("'code' is not on PATH -- install the VS Code shell command", vim.log.levels.ERROR)
    return
  end

  local ok, err = pcall(vim.cmd, 'wall')
  if not ok then
    vim.notify('Nothing handed off -- could not save all buffers:\n' .. err, vim.log.levels.ERROR)
    return
  end

  file = vim.fn.fnamemodify(file, ':p')
  -- charcol, not the 0-based byte column from nvim_win_get_cursor: --goto wants
  -- a 1-based character column.
  local target = ('%s:%d:%d'):format(file, vim.fn.line '.', vim.fn.charcol '.')
  local root = M.project_root(file)

  spawn { 'code', '--reuse-window', root, '--goto', target }
  vim.notify('VS Code: ' .. vim.fn.fnamemodify(file, ':.') .. ' (workspace ' .. root .. ')')
end

vim.api.nvim_create_user_command('DebugInVSCode', M.debug_in_vscode, {
  desc = 'Open the current file and project in VS Code at the cursor, ready to debug',
})

vim.keymap.set('n', '<leader>dv', M.debug_in_vscode, { desc = 'Debug in [V]S Code (hand off cursor + project)' })

return M
