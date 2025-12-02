vim.api.nvim_create_autocmd('TermOpen', {
  pattern = 'term://*',
  callback = function(args)
    -- only do this for interactive shell terminals
    local name = vim.api.nvim_buf_get_name(args.buf)
    local shell = vim.fn.fnamemodify(vim.o.shell, ':t')
    if name:match(shell) then
      local job = vim.b[args.buf].terminal_job_id
      if job then
        vim.defer_fn(function()
          vim.api.nvim_chan_send(job, 'source ~/.config/nvim/bashrc_nvim\n')
        end, 50)
      end
    end
  end,
})
