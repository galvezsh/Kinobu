<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->
# The look: themes, wallpapers, login and boot screens

## Themes (Seasons)

A theme changes everything at once: GNOME's accent, the colours of every app, the icons, the
cursor, the window buttons, the terminal and four wallpapers (one per workspace). Each theme has
palettes, each dark or light; the palette sets the mode. Seasons (`@LAUNCHER@ themes`) is the app;
`kinobu-theme` does the same from the command line:

```bash
kinobu-theme list                            # themes and palettes, the one in use marked
kinobu-theme current                         # theme, palette, mode
kinobu-theme set tokyo-night --palette storm # apply a theme in one of its palettes
kinobu-theme set nord --mode light           # its light palette
kinobu-theme packs                           # icon packs and cursors installed
kinobu-theme pick icons Papirus              # the user's pick over the theme's ("theme" goes back)
kinobu-theme pick interface-font "Inter 11"
kinobu-theme pick wallpaper 2 ~/Pictures/forest.jpg   # wallpaper 2 of 4; 1 is also the lock screen
kinobu-theme pick wallpapers ~/Pictures/forest.jpg    # the same on every workspace
kinobu-theme pick login-sound ~/Music/bell.ogg       # or logout-sound; kinobu, off (desktop.md)
kinobu-theme new "My Nord" --from nord       # the user's own copy of a theme (prints its id)
kinobu-theme colour my-nord polar-night accent=#D08770   # its colours
kinobu-theme buttons my-nord left            # its window buttons on the left (or right)
kinobu-theme delete my-nord                  # to the Trash (not the theme in use)
```

- The user's picks live in `~/.config/kinobu/look.toml`: updates never change it, and picks stay
  when the theme changes (Seasons' "Follow the theme" switches).
- Factory themes: `@SYSTEM_DIR@/themes/`. The user's own: `~/.config/kinobu/themes/<id>/theme.toml`.
- Icon and cursor packs: the system's in `/usr/share/icons` and `/usr/local/share/icons`; a user
  adds their own by unpacking them into `~/.local/share/icons`.
- With Papirus icons the folders take the theme's colour: a hidden icon theme of links,
  `~/.local/share/icons/Papirus-*-kinobu-<colour>` (a theme may name it: `folders = "violet"`).
- Never edit what the engine writes: `~/.config/gtk-4.0/kinobu.css`, `gtk-3.0/kinobu.css`, the
  `kinobu-*.palette` of Ptyxis, the links in `~/.local/share/icons`. Open apps take a new theme
  when they open again.

## Wallpapers

Four, one per workspace (repeated in order on more), kept by the workspace-wallpapers extension.
A theme's come from Wallhaven into `~/.local/share/kinobu/wallpapers`. Change them with
`kinobu-theme pick wallpaper`: never set `org.gnome.desktop.background picture-uri` while the
extension runs, it takes that as the pick for the workspace on screen.

## Terminal colours

The theme gives Ptyxis its palette, made legible on its background. fastfetch and @APP_NAME@'s
own output take the theme's accent from `~/.local/state/kinobu/terminal-dark` or `-light`.

## Login and boot screens

- Login screen (GDM): @APP_NAME@'s background, built by `@BIN_DIR@/kinobu-login-screen`, without
  Ubuntu's logo and in GNOME's green accent (`/usr/share/gdm/dconf/95-kinobu-login`). `sudo kinobu-login-screen --remove`
  brings Ubuntu's back.
- Boot screen (Plymouth): the maker's logo with @APP_NAME@'s rings turning under it, installed by
  `@BIN_DIR@/kinobu-boot-splash` in `/usr/share/plymouth/themes/kinobu`.
  `sudo kinobu-boot-splash --remove` brings Ubuntu's back.
- The boot menu (GRUB) is left as Ubuntu has it.
