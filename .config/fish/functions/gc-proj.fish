# Subcommands that move the session's working dir also move the current shell.
# Fish port of the gc-proj wrapper in ~/.bashrc.
function gc-proj --wraps gc-proj --description 'gc-proj, moving this shell on cd/done'
    switch "$argv[1]"
        case cd
            command gc-proj $argv; or return $status
            set -l d (command gc-proj dir)
            and test -n "$d"
            and builtin cd -- $d
        case done
            # This shell's working dir would keep the project's tree busy.
            builtin cd ~; or return
            command gc-proj $argv
        case '*'
            command gc-proj $argv
    end
end
