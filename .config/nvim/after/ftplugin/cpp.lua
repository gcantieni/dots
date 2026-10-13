-- List-aware `gq`, including inside `//` comments. Runs after the runtime
-- c/cpp ftplugin (which sets 'comments' and 'formatoptions' without 'n') so our
-- 'n' flag and 'formatlistpat' take effect. The existing 'comments' handling the
-- `//` leader is left untouched.
require('core.formatlist').apply()
