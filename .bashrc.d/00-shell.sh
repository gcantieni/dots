# The shell itself: environment, PATH, $EDITOR, prompt.

export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Track interactive shells so we can gate readline-dependent setup
case $- in
    *i*) INTERACTIVE_SHELL=1 ;;
    *)   INTERACTIVE_SHELL=0 ;;
esac

# Expand default history file size to unlimited so you never lose terminal history.
# Commented due to issue with ksh.
export HISTFILESIZE=1000000000
export HISTSIZE=1000000000

# Hide build artifacts from rg in trees without a .gitignore.
# Opt out with `rg --no-config`; --no-ignore does not undo --ignore-file.
export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/ripgreprc"

# TODO: if SSH keys become a pain to manage:
# eval "$(ssh-agent)"
# ssh-add ~/.ssh/id_ed25519_for_git

# Prepend directories to PATH, skipping any that are missing or already there,
# so re-sourcing this file never grows or reorders PATH. Arguments are listed in
# the precedence order they end up in.
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

# Tool customization
path_prepend ~/.config/emacs/bin

# User customization
path_prepend ~/bin ~/.local/bin

# Added by Toolbox App.
path_append ~/.local/share/JetBrains/Toolbox/scripts

# Prepends ~/.cargo/bin, so it lands ahead of the directories above.
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Editor.
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

# Prompt, plus the emacs-vterm escape sequences it emits.
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

# Only load Liquid Prompt in interactive shells, not from a script or from scp
#[[ $- = *i* ]] && source $HOME/repos/liquidprompt/liquidprompt
