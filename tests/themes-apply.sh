#!/bin/bash
# Applies themes with kinobu-theme in a fake home and prints what GNOME and the files got.
# Run it through tests/run.sh: it is started with `env -i` and its own D-Bus, so the bus and
# every service it starts (dconf-service among them) use the fake home, never the real one.
set -u
# Guard: never against a real home. On 2026-11-18 a direct run applied a theme to the author's desktop.
if [[ ${KINOBU_TEST_HOME:-} != "$HOME" || $HOME != /tmp/* || -z ${XDG_CONFIG_HOME:-} ]]; then
    echo "Run it through tests/run.sh: it needs a fake home of its own" >&2
    exit 1
fi
cd "$(dirname "$0")/.." || exit 1
k() { python3 -I files/apps/kinobu_theme.py "$@"; }
get() { gsettings get "$@"; }
profile() { echo "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$(get org.gnome.Ptyxis default-profile-uuid | tr -d "'")/"; }
k set kinobu --mode light >/dev/null
echo "kinobu-light scheme=$(get org.gnome.desktop.interface color-scheme) accent=$(get org.gnome.desktop.interface accent-color) icons=$(get org.gnome.desktop.interface icon-theme) palette=$(get "$(profile)" palette) style=$(get org.gnome.Ptyxis interface-style)"
grep -c 'kinobu.css' "$XDG_CONFIG_HOME/gtk-4.0/gtk.css" | sed 's/^/gtk4-import=/'
grep -c 'prefers-color-scheme' "$XDG_CONFIG_HOME/gtk-4.0/kinobu.css" | sed 's/^/gtk4-variants=/'
echo "kinobu-light-palette=$(k current)"
# Palettes: one asked for by name; a mode moves to the pair; the dark-style switch's CSS has both
k set tokyo-night --palette storm >/dev/null
echo "palette-storm=$(k current) css=$(grep -c 'prefers-color-scheme' "$XDG_CONFIG_HOME/gtk-4.0/kinobu.css") bg=$(grep -m1 -o 'window-bg-color: #[0-9A-F]*' "$XDG_CONFIG_HOME/gtk-4.0/kinobu.css")"
k set tokyo-night --mode light >/dev/null
echo "mode-light=$(k current) scheme=$(get org.gnome.desktop.interface color-scheme)"
k set tokyo-night --palette nothing 2>&1 | head -1
# kinobu-do style, as Willow uses it
mkdir -p "$HOME/bin" && printf '#!/bin/sh\nexec python3 -I %s/files/apps/kinobu_theme.py "$@"\n' "$PWD" >"$HOME/bin/kinobu-theme"
chmod +x "$HOME/bin/kinobu-theme"
sed "s|@BIN_DIR@|$HOME/bin|g; s|@PROGRAMS_DIR@|$PWD/files/apps|g" files/apps/kinobu-do >"$HOME/bin/kinobu-do"
echo "do-style=$(bash "$HOME/bin/kinobu-do" style dark) now=$(k current)"
# A look file from before palettes (a variant): the update keeps the mode
printf 'theme = "nord"\nvariant = "light"\n' >"$XDG_CONFIG_HOME/kinobu/look.toml"
k refresh >/dev/null
printf 'theme = "dracula"\nvariant = "light"\n' >"$XDG_CONFIG_HOME/kinobu/look-dracula.toml"
cp "$XDG_CONFIG_HOME/kinobu/look.toml" "$XDG_CONFIG_HOME/kinobu/look-kept.toml"
mv "$XDG_CONFIG_HOME/kinobu/look-dracula.toml" "$XDG_CONFIG_HOME/kinobu/look.toml"
k refresh >/dev/null
echo "dracula-moved=$(k current)"
mv "$XDG_CONFIG_HOME/kinobu/look-kept.toml" "$XDG_CONFIG_HOME/kinobu/look.toml"
echo "old-look=$(k current) file-palette=$(grep -c '^palette = "snow-storm"' "$XDG_CONFIG_HOME/kinobu/look.toml") file-variant=$(grep -c '^variant' "$XDG_CONFIG_HOME/kinobu/look.toml")"
# A theme whose icon pack is not installed anywhere falls back to Yaru
mkdir -p "$XDG_CONFIG_HOME/kinobu/themes/missing-pack"
sed 's/^icons = .*/icons = "NoSuchIconPack"/' files/themes/macos/theme.toml >"$XDG_CONFIG_HOME/kinobu/themes/missing-pack/theme.toml"
k set missing-pack --mode light >/dev/null
echo "missing-pack icons=$(get org.gnome.desktop.interface icon-theme)"
k set macos >/dev/null
echo "macos buttons=$(get org.gnome.desktop.wm.preferences button-layout) icons=$(get org.gnome.desktop.interface icon-theme) palette=$(get "$(profile)" palette)"
test -s "$XDG_DATA_HOME/org.gnome.Ptyxis/palettes/kinobu-macos.palette" && echo "macos-palette-file=yes"
k current
k set nothing-like-this 2>&1 | head -1
# The user's picks: kept when the theme changes, back to the theme's with "theme"
k pick icons Adwaita >/dev/null
k pick cursor Adwaita >/dev/null
k set tokyo-night >/dev/null
echo "picks-kept icons=$(get org.gnome.desktop.interface icon-theme) cursor=$(get org.gnome.desktop.interface cursor-theme)"
grep -c '^icons = "Adwaita"' "$XDG_CONFIG_HOME/kinobu/look.toml" | sed 's/^/look-file=/'
k pick icons theme >/dev/null
echo "back-to-theme icons=$(get org.gnome.desktop.interface icon-theme)"
# Links in the home folder: the packs in use, nothing of the user's touched
mkdir -p "$HOME/.local/share/icons" && ln -s /usr/share/icons/Yaru "$HOME/.local/share/icons/MyOwn"
k set kinobu --mode dark >/dev/null
echo "home-link=$(readlink "$HOME/.local/share/icons/Yaru-olive-dark")"
k set nord >/dev/null
echo "old-link-gone=$([[ -e $HOME/.local/share/icons/Yaru-olive-dark ]] && echo no || echo yes) own-link-kept=$([[ -L $HOME/.local/share/icons/MyOwn ]] && echo yes || echo no)"
echo "default-cursor=$(grep '^Inherits' "$HOME/.icons/default/index.theme")"
# Wallpapers: four; changing one makes the four yours; one on every workspace
mkdir -p "$HOME/Pictures" && cp /usr/share/backgrounds/warty-final-ubuntu.png "$HOME/Pictures/a.png" 2>/dev/null \
    || printf 'x' >"$HOME/Pictures/a.png"
k pick wallpaper 2 "$HOME/Pictures/a.png" >/dev/null
echo "one-wallpaper=$(grep -o '"[^"]*"' <<<"$(grep '^wallpapers' "$XDG_CONFIG_HOME/kinobu/look.toml")" | wc -l)"
k pick wallpapers "$HOME/Pictures/a.png" >/dev/null
echo "everywhere=$(grep -o 'a.png' "$XDG_CONFIG_HOME/kinobu/look.toml" | wc -l)"
k pick wallpaper 5 "$HOME/Pictures/a.png" 2>&1 | head -1
