# Default path stuff
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/snap/bin

source "$HOME/.localrc"

# Tool customization
export PATH=/home/gcantieni/.config/emacs/bin:/opt/nvim-linux-x86_64/bin:$PATH

# User customization
export PATH=$HOME/bin:$HOME/.local/bin:/u/gcantieni/bin:/home/gcantieni/.local/bin:$PATH

# Track interactive shells so we can gate readline-dependent setup
case $- in
    *i*) INTERACTIVE_SHELL=1 ;;
    *)   INTERACTIVE_SHELL=0 ;;
esac


# Expand default history file size to unlimited so you never lose terminal history.
# Commented due to issue with ksh.
export HISTFILESIZE=1000000000
export HISTSIZE=1000000000

## Colorize the ls output ##
alias ls='ls --color=auto'

## Use a long listing format ##
alias ll='ls -la'

## Show hidden files ##
alias l.='ls -d .* --color=auto'

export EDITOR=nvim
if [ -n "$NVIM" ]; then
  export EDITOR=nvr
  direnv reload 2>/dev/null
  #source ~/.config/nvim/bashrc_nvim >/dev/null 2>&1
fi

alias v='$EDITOR'
alias vg='rg --files --hidden --glob "!{.git,node_modules}/*" | fzf --preview "bat --style=numbers --color=always {} | head -n 100" | xargs -o nvim'

alias c=code

alias .1='cd /disk1/sand/base-trunk-1/mpower/src'
alias .2='cd /disk1/sand/base-trunk-2/mpower/src'

alias src='source "$HOME/.bashrc"'

alias fd="fdfind"

alias rmtmp="find /tmp -mindepth 1 -delete" # don't rm -rf

alias dots='/usr/bin/git --git-dir "$HOME/.dots/" --work-tree "$HOME"'

alias projcd='cd "$PROJ"'
alias projn='$EDITOR $PROJ/notes.txt'
alias projt='$EDITOR $PROJ/todo.txt'
alias gdb='gdb -q'

# Tools

# fzf integration
if [[ $INTERACTIVE_SHELL -eq 1 ]]; then
    [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash
    bind '"\C-o": "$(find \"$PWD\" -type d | fzf)\e\C-e"'
fi

# Only load Liquid Prompt in interactive shells, not from a script or from scp
#[[ $- = *i* ]] && source $HOME/repos/liquidprompt/liquidprompt

function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}

eval "$(direnv hook bash)"

vterm_printf() {
    if [ -n "$TMUX" ] \
        && { [ "${TERM%%-*}" = "tmux" ] \
            || [ "${TERM%%-*}" = "screen" ]; }; then
        # Tell tmux to pass the escape sequences through
        printf "\ePtmux;\e\e]%s\007\e\\" "$1"
    elif [ "${TERM%%-*}" = "screen" ]; then
        # GNU screen (screen, screen-256color, screen-256color-bce)
        printf "\eP\e]%s\007\e\\" "$1"
    else
        printf "\e]%s\e\\" "$1"
    fi
}

# allows directory tracking in emacs vterm
vterm_prompt_end() {
    vterm_printf "51;A$(whoami)@$(hostname):$(pwd)"
}

if [[ $INTERACTIVE_SHELL -eq 1 ]]; then
    bold=$(tput bold)
    blue=$(tput setaf 4)
    reset=$(tput sgr0)
    bold_blue () {
        echo "\[$bold\]\[$blue\]$1\[$reset\]\[$reset\]"
    }

    PS1="$(bold_blue '[')\u:\w$(bold_blue ']')\n\\$ "
    PS1=$PS1'\[$(vterm_prompt_end)\]'
fi

# Jump anywhere
command -v zoxide &>/dev/null && eval "$(zoxide init bash)"
. "$HOME/.cargo/env"
