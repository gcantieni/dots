-- List-aware `gq` (hanging indents for -, *, +, 1., 1)). Runs after the runtime
-- markdown ftplugin so our 'formatoptions'/'formatlistpat' win. Prose textwidth
-- for markdown is set separately in core/autocmds.lua.
require('core.formatlist').apply()
