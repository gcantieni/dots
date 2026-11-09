vim.filetype.add {
  pattern = {
    ['.*'] = {
      function(_, bufnr)
        local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
        if line:find '^#!.*[/%s]uv run' then
          return 'python'
        end
      end,
      { priority = -math.huge },
    },
  },
}
