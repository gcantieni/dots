# Default path stuff
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/snap/bin

# Tool customization
export PATH=/home/gcantieni/.config/emacs/bin:/opt/nvim-linux-x86_64/bin:$PATH

# User customization
export PATH=$HOME/.local/bin:/u/gcantieni/bin/lin:/home/gcantieni/.local/bin:$PATH

source "$HOME/.abinitio_bashrc"

# Expand default history file size to unlimited so you never lose terminal history.
# Commented due to issue with ksh.
export HISTFILESIZE=1000000000
export HISTSIZE=1000000000

eval "$(direnv hook bash)"

export EDITOR=nvim

alias v=$EDITOR
alias vg='rg --files --hidden --glob "!{.git,node_modules}/*" | fzf --preview "bat --style=numbers --color=always {} | head -n 100" | xargs -o nvim'

alias c=code

alias .1='cd /disk1/sand/base-trunk-1/mpower/src'
alias .2='cd /disk1/sand/base-trunk-2/mpower/src'

alias sbash='source "$HOME/.bashrc"'
alias vbash='nvim "$HOME/.bashrc"'
alias vnvim='nvim "$HOME/.config/nvim/lua/config/options.lua"'

alias gc-path="echo $PATH | tr ':' '\n'"

alias fd="fdfind"

alias rmtmp="find /tmp -mindepth 1 -delete" # don't rm -rf

alias dots='/usr/bin/git --git-dir "$HOME/.dots/" --work-tree "$HOME"'

# Tools

# fzf integration
[[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash 

# Only load Liquid Prompt in interactive shells, not from a script or from scp
#[[ $- = *i* ]] && source $HOME/repos/liquidprompt/liquidprompt

# this seemed to be missing some chars--annoying

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

bold=$(tput bold)
blue=$(tput setaf 4)
reset=$(tput sgr0)
bold_blue () {
    echo "\[$bold\]\[$blue\]$1\[$reset\]\[$reset\]"
}

PS1="$(bold_blue '[')\u:\w$(bold_blue ']')\n\\$ "

PS1=$PS1'\[$(vterm_prompt_end)\]'

command -v zoxide &>/dev/null && eval "$(zoxide init bash)"
