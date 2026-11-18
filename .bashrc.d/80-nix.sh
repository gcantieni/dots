# Nix, on NixOS or via the package manager. Inert on machines without it.
command -v nix >/dev/null || return 0

export NIX_DIR="$HOME/nix"

# Edit the nix configuration: this host's configuration.nix by default, or a
# path relative to $NIX_DIR.
vn() {
    local target
    if [ $# -gt 0 ]; then
        target="$NIX_DIR/$1"
    else
        target="$NIX_DIR/hosts/$(hostname)/configuration.nix"
        [ -f "$target" ] || target="$NIX_DIR/flake.nix"
    fi
    "${EDITOR:-vi}" "$target"
}
_vn_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=($(cd "$NIX_DIR" 2>/dev/null && compgen -f -- "$cur"))
}
complete -o filenames -F _vn_complete vn

alias ncd='cd "$NIX_DIR"'
