# Aliases and the one-line functions they shade into.

alias asciinema='LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8 asciinema'

## Colorize the ls output ##
alias ls='ls --color=auto'

## Use a long listing format ##
alias ll='ls -la'

## Show hidden files ##
alias l='ls -d .* --color=auto'

alias c=code

alias src='source "$HOME/.bashrc"'

alias gdb='gdb -q'

alias rmtmp="find /tmp -mindepth 1 -delete" # don't rm -rf

command -v fd >/dev/null || { command -v fdfind >/dev/null && alias fd=fdfind; }

if command -v bat >/dev/null; then alias cat=bat
elif command -v batcat >/dev/null; then alias cat=batcat
fi

alias cd.='cd ..'
alias cd..='cd ../..'
alias cd...='cd ../../..'
alias cd....='cd ../../../..'
alias cd.....='cd ../../../../..'
alias cd......='cd ../../../../../..'
alias cd.......='cd ../../../../../../..'
alias cd........='cd ../../../../../../../..'

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

alias cco='claude --model opus'
alias ccs='claude --model sonnet'
alias cch='claude --model haiku'

# ask what is the capital of france  -- no quoting needed
ask() { claude --model sonnet -p "$*"; }
