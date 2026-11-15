# Login shells (tmux panes, ssh) don't read .bashrc on their own.
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
