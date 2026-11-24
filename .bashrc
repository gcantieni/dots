# Config lives in ~/.bashrc.d/*.sh, loaded in filename order; this file is just
# the loader. Fragments are numbered because order matters: 00-shell sets
# INTERACTIVE_SHELL and path_prepend, both used by later ones.
# A fragment that only applies to some machines guards itself and `return`s.
# Machine-local fragments from other dotfiles repos use 90+ so they can override.
for _rc in "$HOME"/.bashrc.d/*.sh; do
    [ -f "$_rc" ] && source "$_rc"
done
unset _rc
