-- Gutter signs plus per-hunk stage/reset/preview, all under <leader>h.
return {
  'lewis6991/gitsigns.nvim',
  opts = {
    signs = {
      add = { text = '+' },
      change = { text = '~' },
      delete = { text = '_' },
      topdelete = { text = '‾' },
      changedelete = { text = '~' },
    },
    on_attach = function(bufnr)
      local gs = require 'gitsigns'

      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end

      -- ]c/[c are diff-mode's own hunk motions, so only override outside a diff.
      map('n', ']c', function()
        if vim.wo.diff then
          vim.cmd.normal { ']c', bang = true }
        else
          gs.nav_hunk 'next'
        end
      end, 'Jump to next git change')

      map('n', '[c', function()
        if vim.wo.diff then
          vim.cmd.normal { '[c', bang = true }
        else
          gs.nav_hunk 'prev'
        end
      end, 'Jump to previous git change')

      map('v', '<leader>hs', function()
        gs.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
      end, 'Git [s]tage hunk')
      map('v', '<leader>hr', function()
        gs.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
      end, 'Git [r]eset hunk')

      map('n', '<leader>hs', gs.stage_hunk, 'Git [s]tage hunk')
      map('n', '<leader>hr', gs.reset_hunk, 'Git [r]eset hunk')
      map('n', '<leader>hS', gs.stage_buffer, 'Git [S]tage buffer')
      map('n', '<leader>hu', gs.undo_stage_hunk, 'Git [u]ndo stage hunk')
      map('n', '<leader>hR', gs.reset_buffer, 'Git [R]eset buffer')
      map('n', '<leader>hp', gs.preview_hunk, 'Git [p]review hunk')
      map('n', '<leader>hb', gs.blame_line, 'Git [b]lame line')
      map('n', '<leader>hB', gs.blame, 'Git [B]lame buffer')
      map('n', '<leader>hd', gs.diffthis, 'Git [d]iff against index')
      map('n', '<leader>hD', function()
        gs.diffthis '@'
      end, 'Git [D]iff against last commit')

      map('n', '<leader>hti', gs.toggle_current_line_blame, 'Git [t]oggle [i]nline blame')
      map('n', '<leader>htd', gs.toggle_deleted, 'Git [t]oggle [d]eleted')

      map({ 'o', 'x' }, 'ih', gs.select_hunk, 'Select git hunk')
    end,
  },
}
