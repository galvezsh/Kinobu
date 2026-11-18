# shellcheck shell=bash
# The look, part of the "desktop" block: Kinobu's themes (the kinobu-theme engine and Seasons)
# and the icon and cursor packs they use. Design: docs/themes.md.

# ---------------------------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------------------------
LOOK_THEME="kinobu"                 # the theme a user starts with; Seasons changes it
# Icon and cursor packs that are not in Ubuntu's archive but ship ready-made: downloaded,
# checked and unpacked once into $PREFIX/share/icons for every user. The ones in the archive
# come with APT (APT_PACKAGES in lib/apps.sh). Packs that only ship their source (Fluent,
# WhiteSur icons, Tela, Colloid) wait for kinobu-assets (see the roadmap).
# "name|URL|SHA-256|folders in the archive (path[:installed name])"
LOOK_PACKS=(
    "kora|https://codeload.github.com/bikass/kora/tar.gz/refs/tags/v2.0.6|159bdb7a09409a12e54a71136ec8889c51b0bf7c145c8b20e3509dc1e90089bd|kora-2.0.6/kora:kora kora-2.0.6/kora-pgrey:kora-pgrey"
    "phinger-cursors|https://github.com/phisch/phinger-cursors/releases/download/v2.2/phinger-cursors-variants.tar.bz2|46d4cfc30a38c19cada3339027b5a78f7b0bf74f3220eba7001c4fdd9d5a6e56|phinger-cursors-dark phinger-cursors-light"
    "catppuccin-cursors-mocha|https://github.com/catppuccin/cursors/releases/download/v2.0.0/catppuccin-mocha-dark-cursors.zip|a4d976491bdb1b1311b2de88327cad3f1c66c2d9da896e0c56362a660c802585|catppuccin-mocha-dark-cursors"
    "catppuccin-cursors-latte|https://github.com/catppuccin/cursors/releases/download/v2.0.0/catppuccin-latte-light-cursors.zip|4c0752cfa2da6c4cbcfe9539ca92585144b34651f22acf6cecf18850cb938880|catppuccin-latte-light-cursors"
    "nordzy-cursors|https://github.com/guillaumeboehm/Nordzy-cursors/releases/download/v2.4.0/Nordzy-cursors.tar.gz|3451c1221d58562a5eb647c45f3f7b5e2bbfe0aacf10d9cbc899bc36e5239e5a|Nordzy-cursors"
    "nordzy-cursors-white|https://github.com/guillaumeboehm/Nordzy-cursors/releases/download/v2.4.0/Nordzy-cursors-white.tar.gz|5873641192f7c89692f1335c525969879307482c0f70283142f3fa65cfa74ff6|Nordzy-cursors-white"
    "macos-cursors|https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/macOS.tar.xz|9c6e5e13b068ce51a9e90a9abd6ce232ec7d25d4ceb05aa8ac76efbb99c76762|macOS macOS-White"
    "whitesur-cursors|https://codeload.github.com/vinceliuice/WhiteSur-cursors/tar.gz/e190baf618ed95ee217d2fd45589bd309b37672b|35c817c2c26bc4d2c06801cfe6c924a068ad771d3846c5203b04d1c893dd5664|WhiteSur-cursors-e190baf618ed95ee217d2fd45589bd309b37672b/dist:WhiteSur-cursors"
)

# ---------------------------------------------------------------------------------------------
# System: the engine, Seasons, the themes and the packs (once, for every user)
# ---------------------------------------------------------------------------------------------
install_look() {
    if ! $SYSTEM_WRITES; then return 0; fi
    step "Themes: Seasons and the kinobu-theme engine"
    local themes="$SYSTEM_DIR/themes" templates="$SYSTEM_DIR/data/theme-templates" dir
    # The factory themes are swapped in whole, so a theme Kinobu no longer ships goes away
    sys "$SYSTEM_DIR" rm -rf "$themes.new"
    sys "$SYSTEM_DIR" mkdir -p "$themes.new"
    for dir in "$ROOT_DIR"/files/themes/*/; do
        dir=${dir%/}
        if [[ ${dir##*/} != templates ]]; then sys "$SYSTEM_DIR" cp -r "$dir" "$themes.new/"; fi
    done
    sys "$SYSTEM_DIR" chmod -R u=rwX,go=rX "$themes.new"
    sys "$SYSTEM_DIR" rm -rf "$themes"
    sys "$SYSTEM_DIR" mv "$themes.new" "$themes"
    put_file "$templates/gtk4-palette.css" <"$ROOT_DIR/files/themes/templates/gtk4-palette.css"
    put_file "$templates/gtk3-palette.css" <"$ROOT_DIR/files/themes/templates/gtk3-palette.css"
    put_file "$templates/gtk4-details.css" <"$ROOT_DIR/files/desktop/gtk4.css"
    put_file "$templates/gtk3-details.css" <"$ROOT_DIR/files/desktop/gtk3.css"
    write_translations
    put_file "$PROGRAMS_DIR/kinobu_theme.py" < <(render apps/kinobu_theme.py SYSTEM_DIR)
    put_file "$PROGRAMS_DIR/seasons.py" < <(render apps/seasons.py)
    put_file "$PROGRAMS_DIR/kinobu_wallhaven.py" < <(render apps/kinobu_wallhaven.py)
    put_file "$BIN_DIR/kinobu-theme" 0755 <<<"#!/bin/sh"$'\n'"exec python3 \"$PROGRAMS_DIR/kinobu_theme.py\" \"\$@\""
    put_file "$PREFIX/share/icons/hicolor/scalable/apps/os.kinobu.Themes.svg" < <(render apps/seasons.svg)
    put_file "$PREFIX/share/applications/os.kinobu.Themes.desktop" < <(render apps/seasons.desktop LAUNCHER)
    # Ubuntu Dock's Show Apps button looks for view-app-grid-ubuntu-symbolic: Kinobu's logo in its
    # place, in Yaru (found before Ubuntu's own in /usr/share) and in hicolor (for the other packs)
    local dir
    for dir in Yaru hicolor; do
        put_file "$PREFIX/share/icons/$dir/scalable/actions/view-app-grid-ubuntu-symbolic.svg" \
            <"$ROOT_DIR/files/branding/show-apps-symbolic.svg"
    done
    ok "$(find "$themes" -name theme.toml | wc -l) themes; Seasons is in the app grid (Settings folder)"
    install_look_packs
}

# Downloads the LOOK_PACKS that are missing or changed. A pack that cannot be downloaded or does
# not match its checksum is skipped with a warning: themes that use it fall back to Yaru.
install_look_packs() {
    step "Icons and cursors for the themes"
    local icons="$PREFIX/share/icons" marks="$PREFIX/share/icons/.$APP_ID" entry name url sum folders
    local file dir item path as installed=0 current=0
    sys "$PREFIX/share" mkdir -p "$icons"
    for entry in "${LOOK_PACKS[@]}"; do
        IFS='|' read -r name url sum folders <<<"$entry"
        if [[ "$(cat "$marks/$name" 2>/dev/null)" == "$sum" ]]; then current=$((current + 1)); continue; fi
        file="$TMP_DIR/pack-$name" dir="$TMP_DIR/pack-$name.d"
        rm -rf "$file" "$dir"
        if ! download "$url" "$file"; then warn "$name could not be downloaded: themes that use it show Yaru"; continue; fi
        if ! echo "$sum  $file" | sha256sum -c --quiet - >>"$LOG" 2>&1; then
            warn "$name did not match its checksum and was not installed"
            continue
        fi
        mkdir -p "$dir"
        case $url in
            *.zip) run unzip -q "$file" -d "$dir" ;;
            *) run tar -xf "$file" -C "$dir" ;;
        esac
        for item in $folders; do
            path=${item%%:*} as=${item##*:}
            as=${as##*/}
            if [[ ! -d $dir/$path ]]; then warn "$name: $path is missing from its archive"; continue 2; fi
            sys "$icons" rm -rf "$icons/$as.new"
            sys "$icons" cp -r "$dir/$path" "$icons/$as.new"
            sys "$icons" chmod -R u=rwX,go=rX "$icons/$as.new"
            sys "$icons" rm -rf "$icons/$as"
            sys "$icons" mv "$icons/$as.new" "$icons/$as"
        done
        put_file "$marks/$name" <<<"$sum"
        installed=$((installed + 1))
    done
    ok "$installed installed, $current already up to date (and the packs from Ubuntu: Papirus, Numix Circle, elementary, Bibata, Breeze)"
}

# ---------------------------------------------------------------------------------------------
# Each user: their look (their file decides; a new user starts with LOOK_THEME)
# ---------------------------------------------------------------------------------------------
apply_look() {
    step "Your look"
    local engine="$PROGRAMS_DIR/kinobu_theme.py" out gtk_dir action
    if [[ ! -f $engine ]]; then
        warn "The theme engine is not installed: run $APP_NAME with --install"
        return 0
    fi
    # Leftover of the Custom Accent Colors extension: its import fails once the file is gone
    for gtk_dir in "$HOME/.config/gtk-4.0" "$HOME/.config/gtk-3.0"; do
        if [[ -f $gtk_dir/gtk.css && ! -f $gtk_dir/custom-accent.css ]] \
            && grep -qF "CustomAccentExtension Start" "$gtk_dir/gtk.css"; then
            sed -i '/CustomAccentExtension Start/,/CustomAccentExtension End/d' "$gtk_dir/gtk.css"
        fi
    done
    if grep -qE '^theme = "[^"]+"' "$CONFIG_DIR/look.toml" 2>/dev/null; then action=(refresh); else action=(set "$LOOK_THEME"); fi
    if ! out=$(python3 "$engine" "${action[@]}" 2>&1); then
        log "$out"
        warn "The theme could not be applied: open Seasons to choose one"
        return 0
    fi
    log "$out"
    if [[ ${action[0]} == refresh ]]; then
        ok "Your theme and your picks are kept (Seasons changes them)"
    else
        ok "The $LOOK_THEME theme: choose another one, and your icons, cursor, fonts and wallpapers, in Seasons"
    fi
    while IFS= read -r line; do
        if [[ $line == "· "* ]]; then info "${line#· }"; fi
    done <<<"$out"
}
