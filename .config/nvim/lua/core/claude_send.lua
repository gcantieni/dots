-- Send text to a running Claude agent living in a tmux pane. Agents are
-- discovered from the same records the `claude-agents` script reads
-- (~/.claude/status/*.json, written by `claude-agents hook`), so this shares
-- the tmux-pane-as-agent model of the `prefix+a` overview.
--
-- The chosen agent is remembered per nvim instance (vim.g, so it survives
-- <leader>R) and reused while its pane is alive. Otherwise: with one live agent
-- it's used directly; with several, a telescope picker lists them by the status
-- "description" fields with a live pane preview. <leader>cp re-picks.
-- After pasting, focus switches to that pane so you can add a prompt and hit
-- Enter.

local M = {}

-- Launched for a specific agent (tmux prefix+g review popup sets $CLAUDE_PANE).
if vim.g.claude_send_pane == nil and vim.env.CLAUDE_PANE then
  vim.g.claude_send_pane = vim.env.CLAUDE_PANE
end

local status_dir = vim.fn.expand '~/.claude/status'
local claude_agents = vim.fn.expand '~/bin/claude-agents'

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
-- check in ~/bin/claude-agents live_records()).
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

-- Human-readable one-liner for a record, using the claude-agents record fields.
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
-- ~/bin/claude-agents. Returns true on success.
local function send_and_focus(pane, text)
  vim.fn.system({ 'tmux', 'load-buffer', '-b', 'nvim-claude-send', '-' }, text)
  if vim.v.shell_error ~= 0 then
    vim.notify('claude-send: tmux load-buffer failed', vim.log.levels.ERROR)
    return false
  end
  vim.fn.system { 'tmux', 'paste-buffer', '-d', '-p', '-b', 'nvim-claude-send', '-t', pane }
  if vim.v.shell_error ~= 0 then
    vim.notify('claude-send: tmux paste-buffer failed (pane gone?)', vim.log.levels.ERROR)
    vim.g.claude_send_pane = nil
    return false
  end
  vim.g.claude_send_pane = pane
  vim.fn.system { 'tmux', 'switch-client', '-t', pane }
  vim.fn.system { 'tmux', 'select-window', '-t', pane }
  vim.fn.system { 'tmux', 'select-pane', '-t', pane }
  return true
end

-- Telescope picker over the agents; reuses the pattern in core.ai_term_gf and
-- previews the pane via `claude-agents preview` (its output-trimming logic).
local function pick_agent(agents, on_pick)
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local previewers = require 'telescope.previewers'
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  pickers
    .new({}, {
      prompt_title = 'Pick Claude agent',
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
          return { claude_agents, 'preview', entry.value.pane }
        end,
      },
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            on_pick(selection.value.pane)
          end
        end)
        return true
      end,
    })
    :find()
end

-- Call on_pick(pane) with the remembered agent if its pane is alive, else the
-- only live agent, else one picked from a list. force always shows the picker.
function M.with_agent(on_pick, force)
  local remembered = vim.g.claude_send_pane
  if not force and remembered and live_panes()[remembered] then
    on_pick(remembered)
    return
  end
  local agents = list_agents()
  if #agents == 0 then
    vim.notify('claude-send: no live Claude agents', vim.log.levels.WARN)
    return
  end
  if #agents == 1 and not force then
    on_pick(agents[1].pane)
    return
  end
  pick_agent(agents, on_pick)
end

function M.send(text, force)
  M.with_agent(function(pane)
    send_and_focus(pane, text)
  end, force)
end

-- For callers that need a synchronous result (review.nvim's on_export): sends
-- to the remembered agent if alive, else falls back to M.send (async picker).
function M.send_sync(text)
  local pane = vim.g.claude_send_pane
  if pane and live_panes()[pane] then
    return send_and_focus(pane, text)
  end
  vim.schedule(function()
    M.send(text)
  end)
  return true
end

local function send_selection()
  local text = get_visual_selection()
  if not text or text == '' then
    vim.notify('claude-send: no visual selection', vim.log.levels.WARN)
    return
  end
  M.send(text)
end

local function repick()
  M.with_agent(function(pane)
    vim.g.claude_send_pane = pane
    vim.notify('claude-send: agent set to ' .. pane)
  end, true)
end

vim.keymap.set('x', '<leader>cs', send_selection, { desc = 'Send selection to Claude' })
vim.keymap.set('x', '<F5>', send_selection, { desc = 'Send selection to Claude' })
vim.keymap.set('n', '<leader>cp', repick, { desc = 'Pick Claude agent' })

return M
