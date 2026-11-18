# Integrations with the tools I use: fzf, direnv, zoxide, yazi, tmux, dots, reps.

# fzf integration
if [[ $INTERACTIVE_SHELL -eq 1 ]]; then
    command -v fzf >/dev/null && eval "$(fzf --bash 2>/dev/null)"
    bind '"\C-o": "$(find \"$PWD\" -type d | fzf)\e\C-e"'
fi

command -v direnv &>/dev/null && eval "$(direnv hook bash)"

# Jump anywhere
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"

# yazi, exiting into whatever directory it left off in
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}

alias dots='git --git-dir "$HOME/.dots/" --work-tree "$HOME"'
alias dotsw='git --git-dir "$HOME/.dots-work/" --work-tree "$HOME"'

case $- in
    *i*) "$HOME/bin/dots-pull" ;;
esac

# A pane restored by tmux-resurrect starts without its session's PROJ.
# ~/bin/tmux-resurrect-save keeps the last known PROJ of each session.
if [ -n "$TMUX" ] && [ -z "$PROJ" ]; then
    _sess=$(tmux display-message -p -t "$TMUX_PANE" '#S' 2>/dev/null)
    _proj=$(awk -F'\t' -v s="$_sess" '$1 == s { print $2; exit }' \
        ~/.local/share/tmux/resurrect/proj-env 2>/dev/null)
    if [ -n "$_proj" ]; then
        export PROJ=$_proj
        tmux set-environment -t "=$_sess" PROJ "$_proj"
    fi
    unset _sess _proj
fi

alias projcd='cd "$PROJ"'
alias projn='$EDITOR $PROJ/notes.txt'
alias projt='$EDITOR $PROJ/todo.txt'

# Subcommands that move the session's working dir also move the current shell.
gc-proj() {
    local d
    case ${1:-} in
        cd)
            command gc-proj "$@" || return $?
            if d=$(command gc-proj dir) && [[ -n $d ]]; then
                builtin cd -- "$d"
            fi
            ;;
        done)
            # This shell's working dir would keep the project's tree busy.
            builtin cd ~ || return
            command gc-proj "$@"
            ;;
        *)
            command gc-proj "$@"
            ;;
    esac
}

# Flashcard reminder
if [[ $- == *i* ]] && command -v reps >/dev/null; then
    reps due
fi
