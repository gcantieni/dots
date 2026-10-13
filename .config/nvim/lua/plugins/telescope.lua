return { -- Fuzzy Finder (files, lsp, etc)
  'nvim-telescope/telescope.nvim',
  event = 'VimEnter',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { -- If encountering errors, see telescope-fzf-native README for installation instructions
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
      cond = function()
        return vim.fn.executable 'make' == 1
      end,
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  config = function()
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    -- In trees that aren't git repos, ripgrep has no .gitignore to honour and
    -- lists every build artifact alongside the sources. This ignore file
    -- supplies the exclusions instead.
    -- rg aborts on a missing --ignore-file, so only pass it when it is there.
    local rg_ignore_file = (function()
      local xdg = vim.env.XDG_CONFIG_HOME or vim.fs.joinpath(vim.uv.os_homedir(), '.config')
      local path = vim.fs.joinpath(xdg, 'ripgrep', 'ignore')

      if vim.uv.fs_stat(path) then
        return '--ignore-file=' .. path
      end
    end)()

    -- Toggled by :TelescopeArtifacts. rg's --no-ignore does not undo
    -- --ignore-file, so a picker-level `no_ignore = true` cannot serve as the
    -- escape hatch — the flag has to be withheld instead.
    local filter_artifacts = true

    local function with_ignore(cmd)
      if filter_artifacts and rg_ignore_file then
        cmd[#cmd + 1] = rg_ignore_file
      end

      return cmd
    end

    local function grep_arguments()
      return with_ignore {
        'rg',
        '--color=never',
        '--no-heading',
        '--with-filename',
        '--line-number',
        '--column',
        '--smart-case',
      }
    end

    require('telescope').setup {
      -- You can put your default mappings / updates / etc. in here
      --  All the info you're looking for is in `:help telescope.setup()`
      --
      -- defaults = {
      --   mappings = {
      --     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
      --   },
      -- },
      defaults = {
        -- Truncate paths from the *left* when they don't fit, so the end of the
        -- path (the filename — the important part) is always preserved:
        --   …/some/dir/important_name.lua
        path_display = { 'truncate' },
        vimgrep_arguments = grep_arguments(),
        -- C-u/C-d page through the results list rather than scrolling the
        -- preview (default). Scrolling the results is the common need.
        mappings = {
          i = {
            ['<C-u>'] = actions.results_scrolling_up,
            ['<C-d>'] = actions.results_scrolling_down,
          },
          n = {
            ['<C-u>'] = actions.results_scrolling_up,
            ['<C-d>'] = actions.results_scrolling_down,
          },
        },
      },
      pickers = {
        buffers = {
          sort_lastused = true,
        },
        find_files = {
          -- A function, not a table: telescope appends --hidden/--no-ignore to
          -- this list in place, which would accumulate across invocations.
          find_command = function()
            return with_ignore { 'rg', '--files', '--color', 'never' }
          end,
        },
      },
      extensions = {
        ['ui-select'] = {
          require('telescope.themes').get_dropdown(),
        },
      },
    }

    -- Enable Telescope extensions if they are installed
    pcall(require('telescope').load_extension, 'fzf')
    pcall(require('telescope').load_extension, 'ui-select')

    vim.api.nvim_create_user_command('TelescopeArtifacts', function()
      filter_artifacts = not filter_artifacts
      require('telescope.config').values.vimgrep_arguments = grep_arguments()
      vim.notify('Telescope build artifacts: ' .. (filter_artifacts and 'hidden' or 'shown'))
    end, { desc = 'Toggle hiding build artifacts in telescope file/grep pickers' })

    -- Use default telescope pickers
    local builtin = require 'telescope.builtin'
    vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    vim.keymap.set('n', '<leader><leader>', builtin.find_files, { desc = '[S]earch all files' })
    vim.keymap.set('n', '<leader>sf', function()
      local file_dir = vim.fn.expand '%:h'
      builtin.find_files { cwd = file_dir }
    end, { desc = '[S]earch [f]iles from file dir' })

    -- This one is actually awesome, allows to re-access the previous list
    -- great for fuzzy-find etc.
    vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
    vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
    vim.keymap.set('n', '<leader>sb', function()
      require('telescope.builtin').live_grep_buffers()
    end, { desc = 'Search in open buffers' })
    vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
    vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
    vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
    vim.keymap.set('n', '<leader>,', function()
      builtin.buffers { sort_mru = true, ignore_current_buffer = true }
    end, { desc = '[ ] Find existing buffers' })
    vim.keymap.set('n', '<leader>st', '<cmd>TodoTelescope<CR>')

    -- Slightly advanced example of overriding default behavior and theme
    vim.keymap.set('n', '<leader>/', function()
      -- You can pass additional configuration to Telescope to change the theme, layout, etc.
      builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
        winblend = 10,
        previewer = false,
      })
    end, { desc = '[/] Fuzzily search in current buffer' })

    -- It's also possible to pass additional configuration options.
    --  See `:help telescope.builtin.live_grep()` for information about particular keys
    vim.keymap.set('n', '<leader>s/', function()
      builtin.live_grep {
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      }
    end, { desc = '[S]earch [/] in Open Files' })

    -- Shortcut for searching your Neovim configuration files
    vim.keymap.set('n', '<leader>sn', function()
      builtin.find_files { cwd = vim.fn.stdpath 'config' }
    end, { desc = '[S]earch [N]eovim files' })
  end,
}
