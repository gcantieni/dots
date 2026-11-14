local ensure_installed = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' }
-- markdown/cpp/rust are excluded so `gq` list formatting (see
-- lua/core/formatlist.lua) can control 'indentexpr'.
local no_indent = { ruby = true, markdown = true, cpp = true, rust = true }

return { -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    local ts = require 'nvim-treesitter'
    ts.install(ensure_installed)
    local available = {}
    for _, lang in ipairs(ts.get_available()) do
      available[lang] = true
    end

    local function attach(buf, lang)
      if not pcall(vim.treesitter.start, buf, lang) then
        return
      end
      if lang == 'ruby' then
        vim.bo[buf].syntax = 'on'
      end
      if not no_indent[lang] then
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end
    end

    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('user-treesitter', { clear = true }),
      callback = function(args)
        local lang = vim.treesitter.language.get_lang(args.match)
        if not lang then
          return
        end
        if vim.treesitter.language.add(lang) then
          attach(args.buf, lang)
        elseif available[lang] then
          ts.install(lang):await(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
              attach(args.buf, lang)
            end
          end)
        end
      end,
    })
  end,
}
