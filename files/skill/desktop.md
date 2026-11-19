<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->
# Desktop (GNOME on Wayland)

## Settings

Read and change settings as the user, inside the graphical session:

```bash
gsettings get org.gnome.desktop.interface color-scheme
gsettings set org.gnome.desktop.interface accent-color 'blue'
dconf dump /org/gnome/shell/extensions/   # every extension setting
```

The look comes from a theme (see "Themes" below): do not set `accent-color`, `gtk-theme`,
`icon-theme`, `cursor-theme`, fonts or wallpapers by hand, use `kinobu-theme`. Workspaces are fixed (`org.gnome.mutter dynamic-workspaces false`,
`org.gnome.desktop.wm.preferences num-workspaces`). The app grid starts with the System,
Settings and Utilities folders (`org.gnome.desktop.app-folders`, `org.gnome.shell
app-picker-layout`); the apps follow wherever GNOME or the user puts them.

## Extensions

```bash
gnome-extensions list --enabled
gnome-extensions enable|disable <uuid>
gnome-extensions prefs <uuid>
```

User extensions live in `~/.local/share/gnome-shell/extensions/`. New ones load after
logging out and back in. The dock is the Ubuntu Dock (`dash-to-dock` settings); its Show Apps button shows
Kinobu's logo (`view-app-grid-ubuntu-symbolic` in the Yaru and hicolor icon folders of `/usr/local/share/icons`).
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

## Willow (voice assistant)

Super+Shift+Space opens Willow (`@PROGRAMS_DIR@/voice.py`): it listens through Handy,
answers aloud with a small headless model and can only read the system, search the web and open
apps, pages or folders; real work goes to the user's agent. Settings in
`~/.config/kinobu/voice.json`, voices and models in `~/.local/share/kinobu/voice/` (personal Qwen
voices in `voices/`). The stop button next to the microphone, Esc or Super+Shift+Space again stop
it while it speaks. If it stays silent, check the engine in its settings and the sound mute.

## Themes (Seasons)

A theme changes the whole look at once: GNOME's accent, the colours of every
libadwaita app, the icons, the cursor, the window buttons, the terminal palette and, when it
has them, a wallpaper per workspace. Each theme has palettes, each one dark or light (Tokyo
Night: night, storm, moon, day, light); the palette sets the mode. Seasons (`@LAUNCHER@ themes`, or `@LAUNCHER@ themes icons|cursors|fonts|wallpapers`)
is the app; `kinobu-theme` does the same from the command line:

```bash
kinobu-theme list                          # the themes and their palettes, the one in use marked
kinobu-theme current                       # theme, palette, mode
kinobu-theme set tokyo-night --palette storm   # apply a theme in one of its palettes
kinobu-theme set nord --mode light         # its light palette (dark or light mode)
kinobu-theme packs                         # icon packs and cursors installed
kinobu-theme pick icons Papirus            # the user's own pick over the theme's
kinobu-theme pick cursor theme             # back to the theme's
kinobu-theme pick interface-font "Inter 11"
kinobu-theme pick wallpaper 2 ~/Pictures/forest.jpg   # wallpaper 2 of 4; 1 is also the lock screen
kinobu-theme pick wallpapers ~/Pictures/forest.jpg     # the same on every workspace ("theme": the theme's)
kinobu-theme look                          # the user's look file
kinobu-theme new "My Nord" --from nord     # the user's own copy of a theme (prints its id)
kinobu-theme colour my-nord polar-night accent=#D08770 background=#2A2421   # its colours
kinobu-theme buttons my-nord left          # its window buttons on the left (or right)
kinobu-theme delete my-nord                # to the Trash (not the theme in use)
```

In Seasons each theme card's menu (⋮) has Duplicate; the user's own themes also have
Customise (colours with a live preview and contrast checks, the window buttons' side), Open the file
and Delete. Themes, Icons and Cursors show
the system's and the user's own in two groups; a user installs icon or cursor packs by unpacking
them into `~/.local/share/icons` (or `~/.icons`).

The user's choices live in `~/.config/kinobu/look.toml`: Kinobu's updates never change it and
picks stay when the theme changes. In Seasons each section has a "Follow the theme" switch: off
keeps the current icons, cursor, fonts or wallpapers as the user's own. Wallpapers has "Find
wallpapers on Wallhaven…": safe-for-work pictures from wallhaven.cc, saved in ~/Pictures/Wallhaven. Factory themes are in `@SYSTEM_DIR@/themes/`, the user's own
in `~/.config/kinobu/themes/<id>/theme.toml` (same format; the same id overrides a factory one).
Never edit the files the engine writes (`~/.config/gtk-4.0/kinobu.css`, `gtk-3.0/kinobu.css`,
the `kinobu-*.palette` in Ptyxis' palettes folder, the links in `~/.local/share/icons`): they are
rewritten on every change. Open apps take a new theme when they open again. Icon packs and
cursors are in `/usr/share/icons` (APT: Papirus, Numix Circle, elementary, Bibata, Breeze) and
`/usr/local/share/icons` (Kora, Phinger, Catppuccin, Nordzy, macOS and WhiteSur cursors).

## Login screen

The screen before signing in (GDM) shows Kinobu's background: Ubuntu's own theme with the grey
replaced, built by `@BIN_DIR@/kinobu-login-screen` and chosen through the `gdm-theme.gresource`
alternative; apt rebuilds it when Ubuntu updates its theme. `sudo kinobu-login-screen --remove`
brings Ubuntu's back. The boot menu (GRUB) is not changed by Kinobu.

The boot splash (Plymouth) shows Kinobu's rings turning on black: a two-step theme in
`/usr/share/plymouth/themes/kinobu`, chosen by hand as the `default.plymouth` alternative (so
Ubuntu's updates keep it) by `@BIN_DIR@/kinobu-boot-splash`, which rebuilds the start-up image
(`update-initramfs -u`). `sudo kinobu-boot-splash --remove` brings Ubuntu's back.

## Clock, weather and wallpapers

24 h clock with weekday and date. The weather in the top bar comes from the location set in
GNOME Weather (`org.gnome.shell.weather locations`). There are four wallpapers, one per workspace
and repeated in order on more; a theme's come from Wallhaven, downloaded to
`~/.local/share/kinobu/wallpapers` when it is applied. Each workspace has its own wallpaper
(workspace-wallpapers extension, key `workspace-wallpapers`, one file URI per workspace; its
schema is in the extension's folder, so use `kinobu-theme pick wallpaper`). Do not set
`org.gnome.desktop.background picture-uri` while the extension runs: it takes that as the pick for
the workspace on screen.

## Shell and terminal fonts

Bash uses Oh My Bash (`~/.oh-my-bash`, configured in the managed block of `~/.bashrc`;
aliases defined after it win). The prompt needs a Nerd Font: it is set in Ptyxis
(`org.gnome.Ptyxis font-name`), VS Code (`terminal.integrated.fontFamily`) and the JetBrains-based
IDEs (`options/terminal-font.xml` in `~/.config/JetBrains/<IDE><version>/`, or
`~/.config/Google/AndroidStudio<version>/` for Android Studio). Another terminal app needs the
same font, or the prompt shows boxes instead of icons.

Ptyxis' palette comes from the theme (profile key `palette`). New Ptyxis windows and tabs show
fastfetch once, with the config in `~/.config/fastfetch/config.jsonc` and the logo in
`kinobu-logo.txt` next to it. Delete the `Managed by` line at the top of the config to keep your
own changes when the setup is re-run.

GTK apps get the theme's colours from `~/.config/gtk-4.0/kinobu.css` and
`~/.config/gtk-3.0/kinobu.css` (written by `kinobu-theme`), imported by a `kinobu` block in each
`gtk.css`. Put your own CSS outside that block. `ff` runs fastfetch in the theme's accent, read
from `~/.local/state/kinobu/terminal-dark` or `-light` ("accent ring1 ring2" as r;g;b, written
by the theme engine). The engine makes a palette's terminal colours legible on its background.

## Power

Screen-off time: `org.gnome.desktop.session idle-delay` (seconds, AC and battery).
Suspend: `org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout` and
`sleep-inactive-battery-timeout` (seconds). The power button suspends.

## Startup apps

`~/.config/autostart/*.desktop`. The Kinobu welcome tour opens once after the first setup;
open it again with Super+F1 or `@LAUNCHER@ welcome` (it is hidden from the app grid).
