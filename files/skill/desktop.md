<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->
# Desktop (GNOME on Wayland)

## Settings

Read and change settings as the user, inside the graphical session:

```bash
gsettings get org.gnome.desktop.interface color-scheme
gsettings set org.gnome.desktop.interface accent-color 'blue'
dconf dump /org/gnome/shell/extensions/   # every extension setting
```

Theme: Yaru with an accent colour (`accent-color`, `gtk-theme`, `icon-theme` =
`Yaru-<colour>-dark`). Workspaces are fixed (`org.gnome.mutter dynamic-workspaces false`,
`org.gnome.desktop.wm.preferences num-workspaces`). The app grid starts with the System,
Settings and Utilities folders (`org.gnome.desktop.app-folders`), then the everyday apps
(`org.gnome.shell app-picker-layout`).

## Extensions

```bash
gnome-extensions list --enabled
gnome-extensions enable|disable <uuid>
gnome-extensions prefs <uuid>
```

User extensions live in `~/.local/share/gnome-shell/extensions/`. New ones load after
logging out and back in. The dock is the Ubuntu Dock (`dash-to-dock` settings).
Clipboard history is the clipboard-indicator extension (Super+V).

## Accounts, mail and calendar

Settings > Online Accounts connects Google, Microsoft and others; GNOME Contacts and
GNOME Calendar then show and edit those contacts and events. Geary reads the mail of those
accounts and keeps running in the background (`org.gnome.Geary run-in-background`, its
"Watch for new mail when closed" preference), so new mail is notified even when it is closed;
it starts hidden at login from `~/.config/autostart/geary-autostart.desktop`.

## Voice dictation (Handy)

Handy transcribes locally. On Wayland it cannot grab global keys or type by itself:
GNOME owns the shortcut (Super+Space) and `ydotool` types the text. If dictation does not
type, check `systemctl --user status ydotool` and `ls -l /dev/uinput`, and that Handy's
Advanced > typing tool is still ydotool (Kinobu sets it at setup).

## Zen (voice assistant)

Super+Shift+Space opens Zen (`@PROGRAMS_DIR@/zen.py`): it listens through Handy,
answers aloud with a small headless model and can only read the system, search the web and open
apps, pages or folders; real work goes to the user's agent. Settings in
`~/.config/kinobu/zen.json`, voices and models in `~/.local/share/kinobu/zen/` (personal Qwen
voices in `voices/`). If it stays silent, check the engine in its settings and the sound mute.

## Clock, weather and wallpapers

24 h clock with weekday and date. The weather in the top bar comes from the location set in
GNOME Weather (`org.gnome.shell.weather locations`). Each workspace has its own wallpaper
(workspace-wallpapers extension, key `workspace-wallpapers`, one file URI per workspace); the
images are in `~/.local/share/backgrounds/kinobu/`.

## Shell and terminal fonts

Bash uses Oh My Bash (`~/.oh-my-bash`, configured in the managed block of `~/.bashrc`;
aliases defined after it win). The prompt needs a Nerd Font: it is set in Ptyxis
(`org.gnome.Ptyxis font-name`), VS Code (`terminal.integrated.fontFamily`) and the JetBrains-based
IDEs (`options/terminal-font.xml` in `~/.config/JetBrains/<IDE><version>/`, or
`~/.config/Google/AndroidStudio<version>/` for Android Studio). Another terminal app needs the
same font, or the prompt shows boxes instead of icons.

Ptyxis uses the `Tokyo Night` palette (profile key `palette`). New Ptyxis windows and tabs show
fastfetch once, with the config in `~/.config/fastfetch/config.jsonc` and the logo in
`kinobu-logo.txt` next to it. Delete the `Managed by` line at the top of the config to keep your
own changes when the setup is re-run.

GTK apps get accent-colour details from `~/.config/gtk-4.0/kinobu.css` and
`~/.config/gtk-3.0/kinobu.css`, imported by an `kinobu` block in each `gtk.css`. The colours
come from the theme, so they follow the accent and light/dark mode; `--kinobu-intensity` at the
top of the GTK 4 file scales them (0 turns them off). Put your own CSS outside that block. Apps
pick changes up when they restart. `ff` runs fastfetch in the accent colour.

## Power

Screen-off time: `org.gnome.desktop.session idle-delay` (seconds, AC and battery).
Suspend: `org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout` and
`sleep-inactive-battery-timeout` (seconds). The power button suspends.

## Startup apps

`~/.config/autostart/*.desktop`. The Kinobu welcome tour opens once after the first setup;
open it again from the app grid (Kinobu Welcome) or with `@LAUNCHER@ welcome`.
