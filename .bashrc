export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8 
alias asciinema='LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 asciinema'

# Default path stuff
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin

# Prepend directories to PATH, skipping any that are missing or already there,
# so re-sourcing this file never grows or reorders PATH. Arguments are listed in
# the precedence order they end up in. Defined before .localrc so it can use it.
path_prepend() {
    local dir i
    for (( i = $#; i >= 1; i-- )); do
        dir="${!i}"
        if [ ! -d "$dir" ]; then
            continue
        fi
        case ":$PATH:" in
            *":$dir:"*) continue ;;
        esac
        PATH="$dir${PATH:+:$PATH}"
    done
}

# Append counterpart, for directories that should lose to everything else.
path_append() {
    local dir
    for dir in "$@"; do
        if [ ! -d "$dir" ]; then
            continue
        fi
        case ":$PATH:" in
            *":$dir:"*) continue ;;
        esac
        PATH="${PATH:+$PATH:}$dir"
    done
}

[ -f "$HOME/.localrc" ] && source "$HOME/.localrc"

# Tool customization
path_prepend ~/.config/emacs/bin /opt/nvim-linux-x86_64/bin

# User customization
path_prepend ~/bin ~/.local/bin

# Added by Toolbox App. Lives here, not .profile: the PATH reset above would drop
# it on any re-source of this file.
path_append ~/.local/share/JetBrains/Toolbox/scripts

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
alias l='ls -d .* --color=auto'

# Hide build artifacts from rg in trees without a .gitignore.
# Opt out with `rg --no-config`; --no-ignore does not undo --ignore-file.
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/ripgreprc"

export EDITOR=nvim
if [ -n "$NVIM" ]; then
  # Inside an nvim :terminal, route editors through nvr so files open in THIS
  # nvim. nvr-edit is a wrapper (~/bin/nvr-edit) that opens the file in a normal
  # editing window above the toggleterm instead of hijacking the terminal window.
  # EDITOR stays a single command (no extra args) so callers that invoke
  # "$EDITOR" as one word (e.g. the vw function below) still work.
  export EDITOR='nvr-edit'
  # GIT_EDITOR gets the blocking variant. --remote-wait-silent is the crucial
  # bit: plain `nvr` returns instantly, so git reads the still-unedited temp file.
  # --remote-wait blocks until the buffer is gone; `-cc split` opens it in a
  # split instead of hijacking the window; bufhidden=wipe means finishing with
  # :x / ZZ (write + close) wipes the buffer and releases the wait in one step.
  export GIT_EDITOR='nvr -cc split --remote-wait-silent +"setl bufhidden=wipe"'
  direnv reload 2>/dev/null
fi

alias vd='nvr -c "cd $PWD"'

alias v='$EDITOR'
alias vg='rg --files --hidden --glob "!{.git,node_modules}/*" | fzf --preview "bat --style=numbers --color=always {} | head -n 100" | xargs -o nvim'
# For v $(which <cmd>)

vw() {
  local p
  p="$(command -v -- "$1")" || return
  "${EDITOR:-vi}" "$p"
}
_vw_complete() {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"
  COMPREPLY=($(compgen -c -- "$cur"))
}
complete -F _vw_complete vw

# TODO: if SSH keys become a pain to manage:
# eval "$(ssh-agent)"
# ssh-add ~/.ssh/id_ed25519_for_git

alias c=code

alias src='source "$HOME/.bashrc"'

alias fd="fdfind"

alias rmtmp="find /tmp -mindepth 1 -delete" # don't rm -rf

alias dots='/usr/bin/git --git-dir "$HOME/.dots/" --work-tree "$HOME"'
alias dotsw='/usr/bin/git --git-dir "$HOME/.dots-work/" --work-tree "$HOME"'

alias projcd='cd "$PROJ"'
alias projn='$EDITOR $PROJ/notes.txt'
alias projt='$EDITOR $PROJ/todo.txt'
alias gdb='gdb -q'
alias cat=batcat
alias cd.='cd ..'
alias cd..='cd ../..'
alias cd...='cd ../../..'
alias cd....='cd ../../../..'
alias cd.....='cd ../../../../..'
alias cd......='cd ../../../../../..'
alias cd.......='cd ../../../../../../..'
alias cd........='cd ../../../../../../../..'

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

alias taskcd='cd "$TASK"'

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

# Quick-edit a config from a curated list
cfg() {
  local files=(
    ~/.localrc
    ~/.bashrc
    ~/.tmux.conf
    ~/.config/nvim/init.lua
    ~/AGENTS.md
    # add more here as you accumulate them
  )
  local f
  f=$(printf '%s\n' "${files[@]}" | fzf \
        --preview 'bat --style=numbers --color=always {} 2>/dev/null | head -n 100') \
    && [[ -n "$f" ]] && eval "${EDITOR:-nvim} \"\$f\""
}

# Flashcard reminder
if [[ $- == *i* ]] && command -v reps >/dev/null; then
    reps due
fi

[ -f "$HOME/.bashrc.work" ] && source "$HOME/.bashrc.work"
