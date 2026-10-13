-- Send the current visual selection to a running Claude agent living in a tmux
-- pane. Agents are discovered from the same records the `claude-status` script
-- reads (~/.claude/status/*.json, written by ~/bin/claude-status-hook), so this
-- shares the tmux-pane-as-agent model of the `prefix+a` overview.
--
-- With one live agent, the selection is sent straight to it. With several, a
-- telescope picker lists them by the status "description" fields (state, summary,
-- cwd, session:window) with a live pane preview, then sends to the chosen one.
-- After pasting, focus switches to that pane so you can add a prompt and hit
-- Enter.

local status_dir = vim.fn.expand '~/.claude/status'
local claude_status = vim.fn.expand '~/bin/claude-status'

-- Charwise/linewise/blockwise visual selection as a single string, or nil.
local function get_visual_selection()
  local mode = vim.fn.mode()
  if mode ~= 'v' and mode ~= 'V' and mode ~= '\22' then
    return nil
  end
  local ok, region = pcall(vim.fn.getregion, vim.fn.getpos 'v', vim.fn.getpos '.', { type = mode })
  if not ok or not region or #region == 0 then
    return nil
  end
  return table.concat(region, '\n')
end

-- Set of pane ids that currently exist, for liveness filtering (mirrors the
-- check in ~/bin/claude-status live_records()).
local function live_panes()
  local out = vim.fn.systemlist { 'tmux', 'list-panes', '-a', '-F', '#{pane_id}' }
  local set = {}
  if vim.v.shell_error == 0 then
    for _, p in ipairs(out) do
      set[p] = true
    end
  end
  return set
end

-- Read every status record, keeping only those whose pane is still alive.
-- Sorted with agents matching the current cwd first, then by state urgency.
local function list_agents()
  local files = vim.fn.glob(status_dir .. '/*.json', false, true)
  if not files or #files == 0 then
    return {}
  end
  local alive = live_panes()
  local rank = { waiting = 0, busy = 1, done = 2, idle = 3 }
  local cwd = vim.fn.getcwd()
  local agents = {}
  for _, file in ipairs(files) do
    local ok, rec = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), '\n'))
    if ok and type(rec) == 'table' and rec.pane and alive[rec.pane] then
      rec._match = (rec.cwd == cwd) or (rec.cwd and vim.startswith(cwd, rec.cwd .. '/')) or false
      table.insert(agents, rec)
    end
  end
  table.sort(agents, function(a, b)
    if a._match ~= b._match then
      return a._match
    end
    local ra, rb = rank[a.state] or 4, rank[b.state] or 4
    if ra ~= rb then
      return ra < rb
    end
    return (a.pane or '') < (b.pane or '')
  end)
  return agents
end

-- Human-readable one-liner for a record, using the claude-status fields.
local function describe(rec)
  local label = rec.summary
  if label == nil or label == '' then
    label = rec.project or '?'
  end
  return string.format(
    '%-7s  %-24s  %s  [%s:%s]',
    rec.state or '?',
    label,
    vim.fn.fnamemodify(rec.cwd or '', ':~'),
    rec.tmux_session or '?',
    rec.window_index or '?'
  )
end

-- Paste text into a pane as one bracketed block (so multi-line selections don't
-- submit early), then switch focus to that pane. Mirrors the jump sequence in
-- ~/bin/claude-status.
local function send_and_focus(pane, text)
  vim.fn.system({ 'tmux', 'load-buffer', '-b', 'nvim-claude-send', '-' }, text)
  if vim.v.shell_error ~= 0 then
    vim.notify('claude-send: tmux load-buffer failed', vim.log.levels.ERROR)
    return
  end
  vim.fn.system { 'tmux', 'paste-buffer', '-d', '-p', '-b', 'nvim-claude-send', '-t', pane }
  if vim.v.shell_error ~= 0 then
    vim.notify('claude-send: tmux paste-buffer failed (pane gone?)', vim.log.levels.ERROR)
    return
  end
  vim.fn.system { 'tmux', 'switch-client', '-t', pane }
  vim.fn.system { 'tmux', 'select-window', '-t', pane }
  vim.fn.system { 'tmux', 'select-pane', '-t', pane }
end

-- Telescope picker over the agents; reuses the pattern in core.ai_term_gf and
-- previews the pane via `claude-status --preview` (its output-trimming logic).
local function pick_agent(agents, text)
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local previewers = require 'telescope.previewers'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  pickers
    .new({}, {
      prompt_title = 'Send selection to Claude',
      finder = finders.new_table {
        results = agents,
        entry_maker = function(rec)
          local display = describe(rec)
          return { value = rec, display = display, ordinal = display }
        end,
      },
      sorter = conf.generic_sorter {},
      previewer = previewers.new_termopen_previewer {
        get_command = function(entry)
          return { claude_status, '--preview', entry.value.pane }
        end,
      },
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            send_and_focus(selection.value.pane, text)
          end
        end)
        return true
      end,
    })
    :find()
end

local function send_selection()
  local text = get_visual_selection()
  if not text or text == '' then
    vim.notify('claude-send: no visual selection', vim.log.levels.WARN)
    return
  end
  local agents = list_agents()
  if #agents == 0 then
    vim.notify('claude-send: no live Claude agents', vim.log.levels.WARN)
    return
  end
  if #agents == 1 then
    send_and_focus(agents[1].pane, text)
    return
  end
  pick_agent(agents, text)
end

vim.keymap.set('x', '<leader>as', send_selection, { desc = 'Send selection to Claude' })
vim.keymap.set('x', '<F5>', send_selection, { desc = 'Send selection to Claude' })
