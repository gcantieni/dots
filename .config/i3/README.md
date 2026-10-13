# i3 setup

i3 on X11 alongside GNOME; GDM is the login manager and GNOME remains the fallback.
Config files: `~/.config/i3/config`, `~/.config/i3status/config`.

## Install
```
sudo apt install i3-wm i3lock xss-lock playerctl feh copyq
```
Avoid the `i3` metapackage; it pulls in dunst, which duplicates mate-notification-daemon.

## Switching sessions
- To i3: at the GDM login screen, click your user, click the gear icon (bottom right), pick **i3**.
- To GNOME: Super+Shift+X to log out, then pick **Ubuntu on Xorg** from the gear.
- GDM remembers the last session chosen.

## Design
- New workspaces are tabbed; Super+S toggles a side-by-side split.
- Workspaces 1-5 live on the left monitor (DP-1), 6-10 on the right (HDMI-2, primary).
  Each monitor switches workspaces independently.
- Fullscreen is per monitor, never spanning both.
- `gaps inner 6` between windows and screen edges.
- Tray (network, bluetooth) on the primary monitor's bar.
- Bar and i3status use the Tomorrow Night palette and JetBrainsMono Nerd Font icons.
- Wallpaper: `~/.config/i3/wallpaper` is a symlink to the image; repoint it and reload.

## What replaces GNOME services
GNOME's `monitors.xml`, xkb options, and idle settings aren't applied outside GNOME,
so the config's startup section sets them:
- Monitor layout via `xrandr`
- Keyboard: `caps:swapescape,compose:ralt`
- Screen blanking off (matches GNOME `idle-delay 0`)

Helpers (all started from the config, none duplicated):
- gsd-xsettings: GTK theme, fonts, cursor
- mate-notification-daemon: notifications
- polkit-mate-authentication-agent-1: auth prompts
- nm-applet, blueman-applet: network, bluetooth
- xss-lock + i3lock: locks on suspend and `loginctl lock-session`
- pactl, playerctl: media keys
- feh: wallpaper
- copyq: clipboard history

No brightness keys; this machine has no backlight.

## Shortcuts (Super = Mod)
| Action | Keys |
|---|---|
| Terminal (ghostty) | Super+Enter |
| App launcher | Super+D or Super+Space |
| Window switcher | Super+Tab |
| Launch mode, then b/B/f/e/c/n/m | Super+O (Brave, Brave private, Firefox, Edge, Code, Obsidian, Thunderbird) |
| Files (Nautilus) / file browser (rofi) / Settings | Super+E / Super+Shift+E / Super+I |
| Screenshot: GUI / region / window | Print / Shift+Print / Ctrl+Print (region and window go to clipboard) |
| Clipboard history | Super+C |
| Previous/next tab (focus) | Super+H/L (or arrows); J/K up/down |
| Move window | Super+Shift+H/J/K/L |
| Tabbed ↔ side by side | Super+S (Super+Shift+S: stacked vertically) |
| Back to tabbed | Super+T |
| Nest next window beside / below | Super+B / Super+V |
| Fullscreen (this monitor) | Super+F |
| Floating toggle | Super+Shift+Space |
| Resize mode | Super+R, then H/J/K/L, Esc to exit |
| Workspace 1-5 (left) / 6-10 (right) | Super+1…5 / Super+6…0 |
| Send window to workspace | Super+Shift+number |
| Prev/next workspace on this monitor | Super+[ / Super+] |
| Focus left/right monitor | Super+, / Super+. |
| Move window to other monitor | Super+Shift+, / Super+Shift+. |
| Move workspace to other monitor | Super+Ctrl+, / Super+Ctrl+. |
| Close window | Super+Shift+Q |
| Lock | Super+Esc |
| Reload / restart i3 / log out | Super+Shift+C / R / X |

## Validate after editing
```
i3 -C -c ~/.config/i3/config
```
Then Super+Shift+C to reload.

## Undo
Switch GDM back to **Ubuntu on Xorg**, then:
```
rm -rf ~/.config/i3 ~/.config/i3status
sudo apt remove i3-wm i3lock xss-lock playerctl feh copyq && sudo apt autoremove
```
