<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->
# Desktop (GNOME on Wayland)

## Settings

Read and change them as the user, inside the graphical session:

```bash
gsettings get org.gnome.desktop.interface color-scheme
dconf dump /org/gnome/shell/extensions/     # every extension's settings
```

The look (accent, icons, cursor, fonts, wallpapers) comes from a theme: change it with
`kinobu-theme`, never by hand (see look.md).

- Workspaces are fixed: `org.gnome.mutter dynamic-workspaces` and
  `org.gnome.desktop.wm.preferences num-workspaces`.
- The app grid starts with the System, Settings and Utilities folders
  (`org.gnome.desktop.app-folders`); the apps follow where GNOME or the user puts them.
- Clock: 24 h with weekday and date. Weather: the location set in GNOME Weather
  (`org.gnome.shell.weather locations`).

## Extensions

```bash
gnome-extensions list --enabled
gnome-extensions enable|disable <uuid>
gnome-extensions prefs <uuid>
```

User extensions live in `~/.local/share/gnome-shell/extensions/`; new ones load after logging out
and in. The dock is Ubuntu Dock (`dash-to-dock` settings), with @APP_NAME@'s logo on its Show Apps
button. Clipboard history: the clipboard-indicator extension (Super+V).

## Accounts, mail and calendar

Settings > Online Accounts connects Google, Microsoft and others; Contacts and Calendar then show
them. Geary reads that mail and runs in the background (`org.gnome.Geary run-in-background`,
started hidden from `~/.config/autostart/geary-autostart.desktop`), so new mail is notified.

## Dictation (Handy)

Handy transcribes on this computer (Super+Space). On Wayland GNOME owns the shortcut and
`ydotool` types the text. If nothing is typed: `systemctl --user status ydotool`,
`ls -l /dev/uinput`, and Handy's Advanced > typing tool must be ydotool.

## Shell and terminal

Bash with Oh My Bash (`~/.oh-my-bash`, set in @APP_NAME@'s block of `~/.bashrc`; aliases defined
after it win). The prompt's icons need a Nerd Font, set in Ptyxis (`org.gnome.Ptyxis font-name`),
VS Code (`terminal.integrated.fontFamily`) and the JetBrains IDEs
(`~/.config/JetBrains/<IDE><version>/options/terminal-font.xml`). Another terminal app needs the
same font, or the prompt shows boxes.

Ptyxis opens only the window asked for (its session restore is off). New windows show fastfetch once (`~/.config/fastfetch/config.jsonc`); `ff` shows it again in
the theme's colours. Deleting the `Managed by` line at the top of that config keeps the user's own
changes on updates.

## Power and startup

- Screen off: `org.gnome.desktop.session idle-delay` (seconds).
- Suspend: `org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout` and
  `sleep-inactive-battery-timeout` (seconds). The power button suspends.
- Startup apps: `~/.config/autostart/*.desktop`. The welcome tour opens once after the setup;
  again with Super+F1.
