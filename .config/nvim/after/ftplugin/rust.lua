-- List-aware `gq`, including inside `//` comments. Runs after the runtime rust
-- ftplugin (which already sets 'n' but only a number-matching 'formatlistpat')
-- so bullets (-, *, +) and `1)` numbering are also recognized. The existing
-- 'comments' handling the `//` leader is left untouched.
require('core.formatlist').apply()
