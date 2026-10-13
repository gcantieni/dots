-- ChatGPT spat this out. Convenient for many use cases.

local M = {}

local function terminal_pid(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local job_id = vim.b[bufnr].terminal_job_id
  if not job_id then
    return nil
  end

  local pid = vim.fn.jobpid(job_id)
  if type(pid) ~= 'number' or pid <= 0 then
    return nil
  end
  return pid
end

--- Get the current working directory of the running process in an nvim terminal buffer.
--- Tracks `cd` changes in the shell (Linux via /proc, macOS via lsof).
--- @param bufnr? integer
--- @return string|nil cwd
function M.get_terminal_shell_cwd(bufnr)
  local pid = terminal_pid(bufnr)
  if not pid then
    return nil
  end

  -- Linux /proc approach
  local proc_link = ('/proc/%d/cwd'):format(pid)
  if vim.loop.fs_stat(proc_link) then
    local target = vim.loop.fs_readlink(proc_link)
    if type(target) == 'string' and target ~= '' then
      return target
    end
  end

  -- macOS fallback (requires `lsof`)
  -- lsof -a -p <pid> -d cwd -Fn  => outputs lines like:
  -- p1234
  -- fcwd
  -- n/Users/you/path
  local ok, out = pcall(vim.fn.systemlist, { 'lsof', '-a', '-p', tostring(pid), '-d', 'cwd', '-Fn' })
  if ok and type(out) == 'table' then
    for _, line in ipairs(out) do
      if vim.startswith(line, 'n') and #line > 1 then
        return line:sub(2)
      end
    end
  end

  return nil
end

return M
