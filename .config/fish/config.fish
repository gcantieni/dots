if status is-interactive
  fish_add_path $HOME/bin
  fish_add_path $HOME/.local/bin
  fish_add_path $HOME/.config/emacs/bin
  fish_add_path $HOME/repos/flutter/bin
  fish_add_path /opt/homebrew/opt/rustup/bin
  fish_add_path /opt/homebrew/bin
  fish_add_path /opt/homebrew/opt/ruby/bin
  fish_add_path /opt/homebrew/lib/ruby/gems/3.4.0/bin

  # Disable greeting message
  set -g fish_greeting

  # tools
  direnv hook fish | source
  zoxide init fish | source
  fzf --fish | source
  status is-interactive; and rbenv init - fish | source

  # ssh
  keychain --eval --agents ssh id_rsa -q | source

  # Emacs vterm integration
  if [ "$INSIDE_EMACS" = 'vterm' ]  
     function vterm_printf;
       if begin; [  -n "$TMUX" ]  ; and  string match -q -r "screen|tmux" "$TERM"; end
         # tell tmux to pass the escape sequences through
         printf "\ePtmux;\e\e]%s\007\e\\" "$argv"
       else if string match -q -- "screen*" "$TERM"
         # GNU screen (screen, screen-256color, screen-256color-bce)
         printf "\eP\e]%s\007\e\\" "$argv"
       else
         printf "\e]%s\e\\" "$argv"
       end
    end
 
    function vterm_prompt_end;
        vterm_printf '51;A'(whoami)'@'(hostname)':'(pwd)
    end
 
    functions --copy fish_prompt vterm_old_fish_prompt
 
    function fish_prompt --description 'Write out the prompt; do not replace this. Instead, put this at end of your file.'
      # Remove the trailing newline from the original prompt. This is done
      # using the string builtin from fish, but to make sure any escape codes
      # are correctly interpreted, use %b for printf.
      printf "%b" (string join "\n" (vterm_old_fish_prompt))
      vterm_prompt_end
    end
   end

  function dots 
    /usr/bin/git --git-dir "$HOME/.dots" --work-tree "$HOME" $argv
  end

  # completion for dots was a pain. have to trick it into completing
  # file names based only on last string typed. better 'n nuthin'
  complete -c dots -e
  # Complete git subcommands when no subcommand has been given yet
  complete -c dots -n '__fish_use_subcommand' -a 'add bisect branch checkout clone commit diff fetch grep init log merge mv pull push rebase reset restore rm show status switch tag'

  complete -c dots -a '(complete -C"commandline -ct")'

  alias lex="ssh -L 11000:gcantieni-l2.abinitio.com:4000 gcantieni@ssh-lex.abinitio.com"
  alias rdp="ssh -i /Users/gus/.ssh/id_rsa -L 12000:gcantieni-l2.abinitio.com:3389 gcantieni@ssh-lex.abinitio.com"
  alias src="source ~/.config/fish/config.fish"
  alias v='nvim'
end
