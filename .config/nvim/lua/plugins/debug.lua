-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    'leoluz/nvim-dap-go',
  },
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<F1>',
      function()
        require('dap').step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<F2>',
      function()
        require('dap').step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<F3>',
      function()
        require('dap').step_out()
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>b',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>B',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = 'Debug: Set Breakpoint',
    },
    -- Without this there's no way to see session output after an unhandled exception.
    -- Not on <F7>: that's the window-switch key, which has to work over browser
    -- sessions that swallow Alt.
    {
      '<leader>du',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: Toggle dap-ui (last session result)',
    },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        'delve',
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    -- Change breakpoint icons
    -- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    -- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    -- local breakpoint_icons = vim.g.have_nerd_font
    --     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
    --   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    -- for type, icon in pairs(breakpoint_icons) do
    --   local tp = 'Dap' .. type
    --   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
    --   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    -- end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Share the project's .vscode/launch.json with VS Code. nvim-dap reads
    -- launch.json on demand, but resolves both its location and
    -- ${workspaceFolder} against getcwd() -- wrong when nvim sits in a
    -- subdirectory of the workspace root. Resolve both against the root
    -- core.vscode hands to `code` so a configuration means the same thing in
    -- either editor.
    -- load_launchjs() is deprecated in this nvim-dap: the provider below feeds
    -- dap on demand instead, and offers every launch.json entry whatever the
    -- filetype, so no adapter-type-to-filetype map is needed.
    local vscode_ext = require 'dap.ext.vscode'

    local function resolve_root(value, root)
      if type(value) == 'string' then
        return (
          value
            :gsub('%${workspaceFolder}', function()
              return root
            end)
            :gsub('%${workspaceFolderBasename}', function()
              return vim.fs.basename(root)
            end)
        )
      end
      if type(value) ~= 'table' then
        return value
      end
      local out = {}
      for k, v in pairs(value) do
        out[k] = resolve_root(v, root)
      end
      -- A config carrying __call resolves launch.json `inputs` when called, and
      -- does so from the original table -- re-wrap so the prompted values still
      -- come back with the root substituted.
      local mt = getmetatable(value)
      if mt and type(mt.__call) == 'function' then
        return setmetatable(out, {
          __call = function()
            return resolve_root(mt.__call(value), root)
          end,
        })
      end
      return out
    end

    dap.providers.configs['dap.launch.json'] = function(bufnr)
      local name = vim.api.nvim_buf_get_name(bufnr)
      local root = require('core.vscode').project_root(name ~= '' and name or vim.fn.getcwd())
      local ok, configs = pcall(vscode_ext.getconfigs, root .. '/.vscode/launch.json')
      if not ok then
        vim.notify_once('Ignoring ' .. root .. '/.vscode/launch.json: ' .. tostring(configs), vim.log.levels.WARN)
        return {}
      end
      return resolve_root(configs, root)
    end

    -- cppdbg is VS Code's C/C++ adapter; register it only if cpptools happens to
    -- be installed (`:MasonInstall cpptools`). Without it the launch.json entries
    -- still show up in the picker, but only VS Code can run them.
    local cpptools = vim.fn.exepath 'OpenDebugAD7'
    if cpptools ~= '' then
      dap.adapters.cppdbg = {
        id = 'cppdbg',
        type = 'executable',
        command = cpptools,
      }
    end

    -- Install golang specific config
    require('dap-go').setup {
      delve = {
        -- On Windows delve must be run attached or it crashes.
        -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
        detached = vim.fn.has 'win32' == 0,
      },
    }
  end,
}
