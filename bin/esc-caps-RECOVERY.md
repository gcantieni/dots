# esc/caps swap — recovery notes

## Setting up a new Mac

After checking out dots:

    esc-caps-install

Loads the LaunchAgent, removes any native modifier mappings (backed up to
~/.local/state/esc-caps/), applies the swap and prints `esc-switch -p`. Log out
and back in if it says it removed a native mapping. Safe to re-run.

## Resume the Claude Code session

    cd ~/Sync/Documents
    claude --resume bfb474f6-c670-4931-8901-59fb6a5166a9

`claude --resume` with no id shows a picker; `claude --continue` reopens the most
recent conversation in that directory. Transcript lives at
~/.claude/projects/-Users-gus-Sync-Documents/bfb474f6-c670-4931-8901-59fb6a5166a9.jsonl

## Expected state after logging back in

    esc-switch -p

Should print "swap: ON", NO "native mapping is LIVE" warning, an empty global
layer, and a per-keyboard layer with two rules. Caps should type Escape and
Escape should type Caps Lock, on every keyboard.

## If the keyboard is wrong or unusable

Everything is reversible with the mouse via Terminal. In order of escalation:

1. Turn the swap off (keys return to hardware default):

       esc-switch -c

2. Put back the original System Settings mapping (caps acts as escape on the
   built-in keyboard only — the behaviour you had before 2026-09-04).
   Needs a logout to take effect:

       defaults -currentHost write -g com.apple.keyboard.modifiermapping.0-0-0 \
         '({HIDKeyboardModifierMappingSrc=30064771129;HIDKeyboardModifierMappingDst=30064771113;})'

   Original value is also saved in ~/bin/native-modifiermapping-0-0-0.backup

3. Remove the whole setup:

       launchctl bootout gui/$(id -u)/com.gus.esc-caps-swap
       rm ~/Library/LaunchAgents/com.gus.esc-caps-swap.plist
       rm ~/bin/esc-caps-ensure ~/bin/com.gus.esc-caps-swap.plist
       hidutil property --set '{"UserKeyMapping":[]}'

   Previous esc-switch is at ~/bin/esc-switch.bak

4. Last resort, no terminal needed: System Settings > Keyboard >
   Keyboard Shortcuts > Modifier Keys sets Caps Lock behaviour per keyboard.

## What was changed

- ~/bin/esc-caps-ensure                 re-applies the swap to any unmapped keyboard
- ~/bin/esc-switch                      toggle (rewritten; original at .bak)
- ~/bin/com.gus.esc-caps-swap.plist     LaunchAgent, runs ensure at login + every 10s
- ~/Library/LaunchAgents/...plist       symlink to the above
- deleted: com.apple.keyboard.modifiermapping.0-0-0 from `defaults -currentHost -g`
  (this is the change that requires a logout)
- ~/.esc-caps-off                       kill switch; present = swap disabled
