# shellcheck shell=bash
# Block "desktop": extensions, theme, weather, workspaces, wallpapers, dock, app grid and GTK styles.

# ---------------------------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------------------------
# GNOME extensions
EGO_EXTENSIONS=(                    # downloaded from extensions.gnome.org
    caffeine@patapon.info
    clipboard-indicator@tudmotu.com
    desktop-cube@schneegans.github.com
    CoverflowAltTab@palatis.blogspot.com
    blur-my-shell@aunetx
    workspace-wallpapers@jonathan.aljl.eu
    weatheroclock@CleoMenezesJr.github.io
)
SYSTEM_EXTENSIONS=(                 # shipped with Ubuntu / gnome-shell-extensions
    ubuntu-dock@ubuntu.com
    ding@rastersoft.com
    tiling-assistant@ubuntu.com
    ubuntu-appindicators@ubuntu.com
    snapd-search-provider@canonical.com
    snapd-prompting@canonical.com
    web-search-provider@ubuntu.com
    apps-menu@gnome-shell-extensions.gcampax.github.com
    places-menu@gnome-shell-extensions.gcampax.github.com
    drive-menu@gnome-shell-extensions.gcampax.github.com
    user-theme@gnome-shell-extensions.gcampax.github.com
)

# Desktop
ACCENT="purple"                     # accent colour and Yaru-<accent>-dark theme (matches the wallpapers)
# shellcheck disable=SC2034  # read by render (files/desktop/dconf.ini)
COLOR_SCHEME="prefer-dark"          # prefer-dark | default
IDLE_DELAY=300                      # seconds before the screen turns off (AC and battery)
SLEEP_ON_AC=1800                    # seconds before suspending on AC power
SLEEP_ON_BATTERY=900                # seconds before suspending on battery
WORKSPACES=4                        # fixed number of workspaces
FAVORITE_APPS=(                     # dock, only the ones that are installed
    helium.desktop google-chrome.desktop org.gnome.Nautilus.desktop org.gnome.Ptyxis.desktop
    org.gnome.Calculator.desktop
    com.microsoft.VSCode.desktop code.desktop
    intellij-idea_intellij-idea.desktop pycharm_pycharm.desktop
    android-studio_android-studio.desktop spotify.desktop
)
# App grid (full run only): these folders first, then the apps every install has; anything else
# goes after them, where GNOME puts it. A folder only shows the listed apps that are installed.
APP_FOLDERS=(                       # "id|name|translate the name|apps"
    "System|X-GNOME-Shell-System.directory|true|update-manager.desktop firmware-updater_firmware-updater.desktop desktop-security-center_desktop-security-center.desktop nvidia-settings.desktop org.gnome.DiskUtility.desktop org.gnome.baobab.desktop nm-connection-editor.desktop org.gnome.Logs.desktop org.gnome.Sysprof.desktop"
    "Settings|Kinobu-Settings.directory|true|org.gnome.Settings.desktop org.gnome.tweaks.desktop org.gnome.Extensions.desktop"
    "Utilities|X-GNOME-Shell-Utilities.directory|true|org.gnome.Papers.desktop org.gnome.Loupe.desktop org.gnome.Showtime.desktop org.gnome.Characters.desktop org.gnome.font-viewer.desktop gnome-language-selector.desktop org.gnome.seahorse.Application.desktop org.gnome.TextEditor.desktop"
)
APP_GRID_FIRST=(                    # after the folders, the installed ones in this order
    os.kinobu.Welcome.desktop firefox_firefox.desktop snap-store_snap-store.desktop
    org.gnome.Contacts.desktop org.gnome.Calendar.desktop org.gnome.Geary.desktop
    org.gnome.Weather.desktop org.gnome.clocks.desktop
)
WALLPAPER_DIR="wallpapers"          # next to the script: 1.jpg, 2.png... one per workspace

# ---------------------------------------------------------------------------------------------
# Block: desktop
# ---------------------------------------------------------------------------------------------
# Installs and enables extensions, then applies theme, dock, workspaces and other settings
configure_desktop() {
    step "GNOME extensions"
    local shell_major uuid url new=false
    shell_major=$(gnome-shell --version)
    shell_major=${shell_major##* }; shell_major=${shell_major%%.*}
    for uuid in "${EGO_EXTENSIONS[@]}"; do
        if [[ -d "$HOME/.local/share/gnome-shell/extensions/$uuid" ]]; then
            ok "$uuid"
            continue
        fi
        url=$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${shell_major}" \
            | jq -r '.download_url // empty' 2>/dev/null || true)
        if [[ -z $url ]]; then
            warn "$uuid has no release for GNOME $shell_major"
            continue
        fi
        curl -fsSL "https://extensions.gnome.org${url}" -o "$TMP_DIR/$uuid.zip"
        gnome-extensions install --force "$TMP_DIR/$uuid.zip" >>"$LOG" 2>&1
        new=true
        ok "$uuid installed"
    done
    # Merge with what the user already has: ours are enabled, theirs stay as they are
    local ours=("${SYSTEM_EXTENSIONS[@]}" "${EGO_EXTENSIONS[@]}") enabled=() disabled=() item
    mapfile -t enabled < <(from_gvariant "$(gsettings get org.gnome.shell enabled-extensions)")
    for item in "${ours[@]}"; do
        if ! has_line "$item" "$(printf '%s\n' "${enabled[@]}")"; then enabled+=("$item"); fi
    done
    for item in $(from_gvariant "$(gsettings get org.gnome.shell disabled-extensions)"); do
        if ! has_line "$item" "$(printf '%s\n' "${ours[@]}")"; then disabled+=("$item"); fi
    done
    gsettings set org.gnome.shell enabled-extensions "$(to_gvariant "${enabled[@]}")"
    gsettings set org.gnome.shell disabled-extensions "$(to_gvariant "${disabled[@]}")"
    gsettings set org.gnome.shell disable-user-extensions false
    ok "$((${#SYSTEM_EXTENSIONS[@]} + ${#EGO_EXTENSIONS[@]})) extensions enabled"
    if $new; then need_reboot "new GNOME extensions (logging out is enough)"; fi

    step "Theme, clock, weather, workspaces, power and files"
    # The weather city comes from the time zone chosen when Ubuntu was installed (no location services)
    local settings
    WEATHER_LOCATION=$(weather_location)
    settings=$(render desktop/dconf.ini ACCENT COLOR_SCHEME WORKSPACES IDLE_DELAY SLEEP_ON_AC \
        SLEEP_ON_BATTERY WEATHER_LOCATION)
    if [[ -z $WEATHER_LOCATION ]]; then
        settings=$(grep -v -e '^locations=' -e '^automatic-location=' <<<"$settings")
        info "No city found for your time zone: choose one in the Weather app"
    fi
    dconf load / <<<"$settings"
    ok "Yaru $ACCENT, 24 h clock, weather, $WORKSPACES fixed workspaces, dock at the bottom"
    ok "Screen off after $((IDLE_DELAY / 60)) min; suspend after $((SLEEP_ON_AC / 60)) min on AC, $((SLEEP_ON_BATTERY / 60)) min on battery"

    step "Wallpapers (one per workspace)"
    local source_dir="$ROOT_DIR/$WALLPAPER_DIR" target_dir="$HOME/.local/share/backgrounds/$APP_ID"
    local n file ext uris=() found=0
    for ((n = 1; n <= WORKSPACES; n++)); do
        file=""
        for ext in jpg jpeg png webp; do
            if [[ -f $source_dir/$n.$ext ]]; then file="$source_dir/$n.$ext"; break; fi
        done
        if [[ -z $file ]]; then uris+=(""); continue; fi
        mkdir -p "$target_dir"
        if ! cmp -s "$file" "$target_dir/${file##*/}"; then cp "$file" "$target_dir/"; fi
        uris+=("file://$target_dir/${file##*/}")
        found=$((found + 1))
    done
    if ((found == 0)); then
        info "No images in ${source_dir/#$HOME/\~}: keeping the current wallpaper"
    else
        dconf_set /org/gnome/shell/extensions/workspace-wallpapers/workspace-wallpapers "$(to_gvariant "${uris[@]}")"
        if [[ -n ${uris[0]} ]]; then
            dconf_set /org/gnome/desktop/background/picture-uri "'${uris[0]}'"
            dconf_set /org/gnome/desktop/background/picture-uri-dark "'${uris[0]}'"
            dconf_set /org/gnome/desktop/background/picture-options "'zoom'"
            dconf_set /org/gnome/desktop/screensaver/picture-uri "'${uris[0]}'"
        fi
        ok "$found of $WORKSPACES workspaces with their own wallpaper (the 1st is also the lock screen)"
    fi

    step "Dock favourites"
    local app favorites=()
    for app in "${FAVORITE_APPS[@]}"; do
        if has_app "$app"; then favorites+=("$app"); fi
    done
    if ((${#favorites[@]})); then
        gsettings set org.gnome.shell favorite-apps "$(to_gvariant "${favorites[@]}")"
        ok "${#favorites[@]} apps pinned"
    fi

    configure_geary

    install_gtk_styles
}

# The city of the system time zone in GNOME Weather's format, empty when it cannot be found.
# zone1970.tab gives the coordinates of each time zone; libgweather, the nearest city.
weather_location() {
    local zone
    zone=$(timedatectl show -p Timezone --value 2>/dev/null || true)
    python3 - "$zone" 2>/dev/null <<'PY' || true
import re, sys
import gi
gi.require_version("GWeather", "4.0")
from gi.repository import GWeather

def degrees(text, width):
    sign = -1 if text[0] == "-" else 1
    value = int(text[1:1 + width]) + int(text[1 + width:3 + width]) / 60
    if len(text) > 3 + width:
        value += int(text[3 + width:5 + width]) / 3600
    return sign * value

for line in open("/usr/share/zoneinfo/zone1970.tab"):
    field = line.rstrip("\n").split("\t")
    if line.startswith("#") or len(field) < 3 or field[2] != sys.argv[1]:
        continue
    lat, lon = re.match(r"([+-]\d+)([+-]\d+)", field[1]).groups()
    city = GWeather.Location.get_world().find_nearest_city(degrees(lat, 2), degrees(lon, 3))
    print("<" + city.serialize().print_(True) + ">")
    break
PY
}

# Turns on Geary's "Watch for new mail when closed": the setting plus the autostart entry the
# package ships, which is what Geary itself does when the preference is switched on.
configure_geary() {
    step "Geary in the background"
    local entry=/usr/share/applications/geary-autostart.desktop
    if ! command -v geary >/dev/null || [[ ! -f $entry ]]; then
        warn "Geary is not installed: its background mode was not set"
        return 0
    fi
    gsettings set org.gnome.Geary run-in-background true
    put_user_file "$HOME/.config/autostart/geary-autostart.desktop" <"$entry"
    ok "Watches for new mail when closed and starts hidden at login (add your account in Online Accounts)"
}

# App grid: the APP_FOLDERS first, then the APP_GRID_FIRST apps that are installed. Folders the
# user already has are kept, and apps not listed go after these, wherever GNOME puts them.
arrange_app_grid() {
    step "App grid"
    local entry id name translate apps children=() layout="" pos=0 app ids=()
    local base=/org/gnome/desktop/app-folders/folders
    # The Settings folder is Kinobu's own: its name comes from a .directory file, so it is shown in
    # the desktop language like GNOME's System and Utilities
    put_user_file "$HOME/.local/share/desktop-directories/Kinobu-Settings.directory" < <(render desktop/settings.directory)
    mapfile -t children < <(from_gvariant "$(gsettings get org.gnome.desktop.app-folders folder-children)")
    for entry in "${APP_FOLDERS[@]}"; do
        IFS='|' read -r id name translate apps <<<"$entry"
        local -a list=()
        read -ra list <<<"$apps"
        dconf_set "$base/$id/name" "'$name'"
        dconf_set "$base/$id/translate" "$translate"
        dconf_set "$base/$id/apps" "$(to_gvariant "${list[@]}")"
        if ! has_line "$id" "$(printf '%s\n' "${children[@]}")"; then children+=("$id"); fi
        layout+="'$id': <{'position': <$pos>}>, "
        pos=$((pos + 1)); ids+=("$id")
    done
    gsettings set org.gnome.desktop.app-folders folder-children "$(to_gvariant "${children[@]}")"
    for app in "${APP_GRID_FIRST[@]}"; do
        # The welcome tour's launcher is written later, by the shortcuts block
        if [[ $app == os.kinobu.Welcome.desktop ]] || has_app "$app"; then
            layout+="'$app': <{'position': <$pos>}>, "
            pos=$((pos + 1))
        fi
    done
    gsettings set org.gnome.shell app-picker-layout "[{${layout%, }}]"
    ok "Folders ${ids[*]} first, then $((pos - ${#ids[@]})) apps; the rest after them"
}

# Writes the GTK 4 and GTK 3 stylesheets (files/desktop/gtk4.css, gtk3.css) and imports them from
# each gtk.css (managed block). Every colour comes from the theme, so they follow the accent and
# light/dark mode; Ptyxis keeps its terminal palette.
install_gtk_styles() {
    step "GTK apps: accent-colour details (GTK 4 and GTK 3)"
    local version gtk_dir css_changed
    for version in 4.0 3.0; do
        gtk_dir="$HOME/.config/gtk-$version"
        put_user_file "$gtk_dir/$APP_ID.css" < <(render "desktop/gtk${version%.0}.css")
        css_changed=$CHANGED
        # Leftover of the Custom Accent Colors extension: its import fails once the file is gone
        if [[ -f $gtk_dir/gtk.css && ! -f $gtk_dir/custom-accent.css ]] \
            && grep -qF "CustomAccentExtension Start" "$gtk_dir/gtk.css"; then
            sed -i '/CustomAccentExtension Start/,/CustomAccentExtension End/d' "$gtk_dir/gtk.css"
            info "GTK $version: removed a broken import left by the Custom Accent Colors extension"
        fi
        put_block "$gtk_dir/gtk.css" "/* >>> $APP_ID >>> */" "/* <<< $APP_ID <<< */" "@import url(\"$APP_ID.css\");"
        if $css_changed; then CHANGED=true; fi
        report_changed "GTK $version: ~/.config/gtk-$version/$APP_ID.css" "GTK $version: already up to date"
    done
    info "Apps that are open pick it up when they restart"
}
