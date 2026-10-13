-- snacks.nvim used to come in as a claudecode.nvim dependency; keep it as a
-- standalone spec so <F9> window zoom survives after claudecode was removed.
return {
  'folke/snacks.nvim',
  opts = {
    zoom = {},
  },
  keys = {
    {
      '<F9>',
      function()
        require('snacks').zoom()
      end,
      desc = 'Zoom current window',
      mode = { 'n', 'i', 't' },
    },
  },
}
