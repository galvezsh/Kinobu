# shellcheck shell=bash
# Block "shortcuts": the launcher, the shortcut table, the Super+K cheat sheet and the welcome tour.

# ---------------------------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------------------------
# Keyboard shortcuts: "group|accelerators|action|target"
#   accelerators: GNOME syntax, several separated by spaces (first one is the main one)
#   target: "launch:<what>" (kinobu-launch), a dconf key path, or "-" (built-in, listed only)
SHORTCUTS=(
    "Apps|<Super>Return|Terminal (maximised)|launch:terminal"
    "Apps|<Super>e|File manager|launch:files"
    "Apps|<Super>b|Web browser|launch:browser"
    "Apps|<Super><Shift>Return|AI agent in a terminal|launch:agent"
    "Apps|<Primary><Shift>Escape|System monitor|launch:monitor"
    "Apps|<Super>space|Voice dictation (Handy)|launch:dictation"
    "Apps|<Super><Shift>space|Talk to Willow (voice assistant)|launch:voice"
    "Apps|<Super>period|Emoji and special characters|launch:emoji"
    "System|<Super>r <Alt>F2|Run a command|/org/gnome/desktop/wm/keybindings/panel-run-dialog"
    "System|<Super>i|Settings|/org/gnome/settings-daemon/plugins/media-keys/control-center"
    "System|<Super>m|Quick settings|/org/gnome/shell/keybindings/toggle-quick-settings"
    "System|<Super><Alt>k <Super><Alt>m|Mute the microphone (on/off)|/org/gnome/settings-daemon/plugins/media-keys/mic-mute"
    "System|<Super><Alt>a|Mute the sound (on/off)|/org/gnome/settings-daemon/plugins/media-keys/volume-mute"
    "System|<Super>n|Notifications|/org/gnome/shell/keybindings/toggle-message-tray"
    "System|<Super>v|Clipboard history|/org/gnome/shell/extensions/clipboard-indicator/toggle-menu"
    "System|<Super><Shift>s Print|Screenshot|/org/gnome/shell/keybindings/show-screenshot-ui"
    "System|<Super>l|Lock screen|/org/gnome/settings-daemon/plugins/media-keys/screensaver"
    "System|<Super>k|Show this shortcut list|launch:keys"
    "System|<Super>F1|Help: the welcome tour (Sprout)|launch:welcome"
    "System|<Super>|Activities overview|-"
    "System|<Super>a|All apps|-"
    "Windows|<Super>q <Alt>F4|Close window|/org/gnome/desktop/wm/keybindings/close"
    "Windows|<Super>f|Full screen|/org/gnome/desktop/wm/keybindings/toggle-fullscreen"
    "Windows|<Super>h|Minimise window|/org/gnome/desktop/wm/keybindings/minimize"
    "Windows|<Super>d|Show desktop|/org/gnome/desktop/wm/keybindings/show-desktop"
    "Windows|<Super>Up|Maximise window|-"
    "Windows|<Super>Down|Restore window size|-"
    "Windows|<Super>Left|Snap to left half|-"
    "Windows|<Super>Right|Snap to right half|-"
    "Windows|<Alt>Tab|Switch windows|-"
    "Windows|<Super>1|Open the 1st dock app (1–9)|-"
    "Workspaces|<Super>Page_Up <Super><Primary>Left <Primary><Alt>Left|Previous workspace|/org/gnome/desktop/wm/keybindings/switch-to-workspace-left"
    "Workspaces|<Super>Page_Down <Super><Primary>Right <Primary><Alt>Right|Next workspace|/org/gnome/desktop/wm/keybindings/switch-to-workspace-right"
    "Workspaces|<Super><Shift>Page_Up|Move window to previous workspace|/org/gnome/desktop/wm/keybindings/move-to-workspace-left"
    "Workspaces|<Super><Shift>Page_Down|Move window to next workspace|/org/gnome/desktop/wm/keybindings/move-to-workspace-right"
    # Ptyxis defaults (the rule: browser shortcut + Shift), listed only
    "Terminal|<Primary><Shift>t|New tab|-"
    "Terminal|<Primary><Shift>n|New window|-"
    "Terminal|<Primary><Shift>w|Close tab|-"
    "Terminal|<Primary><Shift>q|Close window|-"
    "Terminal|<Primary><Shift>c|Copy|-"
    "Terminal|<Primary><Shift>v|Paste|-"
    "Terminal|<Primary><Shift>f|Search|-"
    "Terminal|<Primary><Shift>a|Select all|-"
    "Terminal|<Primary>Page_Up <Primary>Page_Down|Previous / next tab|-"
    "Terminal|<Alt>1|Go to tab 1–9|-"
    "Terminal|<Primary>question|All terminal shortcuts|-"
)
# GNOME defaults that clash with the shortcuts above: "dconf key|new value"
SHORTCUT_RELEASES=(
    "/org/gnome/shell/keybindings/focus-active-notification|@as []"       # was Super+N
    "/org/gnome/settings-daemon/plugins/media-keys/help|@as []"          # GNOME Help, was Super+F1
    "/org/gnome/desktop/wm/keybindings/switch-input-source|['XF86Keyboard']"  # was Super+Space
    "/org/gnome/desktop/wm/keybindings/switch-input-source-backward|['<Shift>XF86Keyboard']"
    "/desktop/ibus/panel/emoji/hotkey|['<Super>semicolon']"               # IBus emoji typing, was Super+. too
    "/org/gnome/shell/extensions/dash-to-dock/shortcut|@as []"            # Ubuntu Dock app numbers, was Super+Q
    "/org/gnome/shell/extensions/dash-to-dock/shortcut-text|''"
)

# ---------------------------------------------------------------------------------------------
# Block: shortcuts
# ---------------------------------------------------------------------------------------------
# "<Super><Shift>Page_Up" -> "Super + Shift + PgUp"
pretty_keys() {
    local accel=$1 mods="" key
    while [[ $accel == \<*\>* ]]; do
        case ${accel%%>*} in
            "<Super") mods+="Super + " ;;
            "<Shift") mods+="Shift + " ;;
            "<Primary"|"<Control") mods+="Ctrl + " ;;
            "<Alt") mods+="Alt + " ;;
        esac
        accel=${accel#*>}
    done
    case $accel in
        "") echo "${mods% + }"; return ;;
        Return) key="Enter" ;; Escape) key="Esc" ;; space) key="Space" ;;
        Page_Up) key="PgUp" ;; Page_Down) key="PgDn" ;; Print) key="PrtSc" ;; question) key="?" ;; period) key="." ;;
        Left) key="←" ;; Right) key="→" ;; Up) key="↑" ;; Down) key="↓" ;;
        ?) key=${accel^^} ;;
        *) key=$accel ;;
    esac
    echo "$mods$key"
}

# Accelerator in a form that compares: modifiers lower case and sorted, <Primary> = <Control>.
# "<Super><Primary>Left" and "<Control><Super>left" both give "control+super+left"
accel_id() {
    local accel=$1 mod mods=()
    while [[ $accel == \<*\>* ]]; do
        mod=${accel%%>*}; mod=${mod#<}; mod=${mod,,}
        if [[ $mod == primary ]]; then mod=control; fi
        mods+=("$mod"); accel=${accel#*>}
    done
    if ((${#mods[@]})); then
        mapfile -t mods < <(printf '%s\n' "${mods[@]}" | sort)
        printf '%s+' "${mods[@]}"
    fi
    printf '%s\n' "${accel,,}"
}

# Display form of all accelerators of a shortcut: "Super + Q  or  Alt + F4"
pretty_all_keys() {
    local accel result=""
    for accel in $1; do result+="${result:+  or  }$(pretty_keys "$accel")"; done
    echo "$result"
}

# Kinobu's keys win: any other binding that uses one of them loses it, the user's own custom
# shortcuts included (with a warning). GNOME's clashing defaults are in SHORTCUT_RELEASES, since
# dconf only holds values that differ from GNOME's; this catches what users and other tools set.
free_kinobu_keys() {
    local -A owned=() targets=()
    local entry group accels action target a dir section line key value path item name
    for entry in "${SHORTCUTS[@]}"; do
        IFS='|' read -r group accels action target <<<"$entry"
        if [[ $target == - ]]; then continue; fi    # GNOME's own function, only listed
        for a in $accels; do owned[$(accel_id "$a")]=$action; done
        if [[ $target == /* ]]; then targets[$target]=1; fi
    done
    for dir in /org/gnome/desktop/wm/keybindings/ /org/gnome/shell/keybindings/ \
        /org/gnome/mutter/keybindings/ /org/gnome/mutter/wayland/keybindings/ \
        /org/gnome/settings-daemon/plugins/media-keys/; do
        section=""
        while IFS= read -r line; do
            case $line in
                "["*"]") section=${line#[}; section=${section%]}; if [[ $section == / ]]; then section=""; fi; continue ;;
                ""|name=*|command=*|custom-keybindings=*) continue ;;
            esac
            key=${line%%=*}; value=${line#*=}
            path="$dir${section:+$section/}$key"
            if [[ -n ${targets[$path]:-} || $path == */custom-keybindings/$APP_ID-* ]]; then continue; fi
            local -a list=() kept=() lost=()
            mapfile -t list < <(from_gvariant "$value")
            for item in "${list[@]}"; do
                if [[ -n ${owned[$(accel_id "$item")]:-} ]]; then lost+=("$item"); else kept+=("$item"); fi
            done
            if ((${#lost[@]} == 0)); then continue; fi
            if [[ $key == binding ]]; then
                # One of the user's own custom shortcuts: it keeps its name and command, not the keys
                name=$(dconf read "${path%binding}name"); name=${name//\'/}
                dconf write "$path" "''"
                warn "Your shortcut \"${name:-$path}\" used $(pretty_keys "${lost[0]}"), now Kinobu's \"${owned[$(accel_id "${lost[0]}")]}\": give it other keys in Settings > Keyboard"
            else
                if ((${#kept[@]})); then dconf write "$path" "$(to_gvariant "${kept[@]}")"; else dconf write "$path" "@as []"; fi
                info "$(pretty_keys "${lost[0]}") taken from ${path##*/} for Kinobu"
            fi
        done < <(dconf dump "$dir" 2>/dev/null || true)
    done
}

# Installs the launcher, applies the shortcut table and writes the cheat sheet data
configure_shortcuts() {
    write_launcher

    step "Releasing GNOME defaults that clash"
    local entry
    for entry in "${SHORTCUT_RELEASES[@]}"; do dconf_set "${entry%%|*}" "${entry#*|}"; done
    ok "Super+N, Super+Space, Super+. and Super+Q freed"

    step "Applying shortcuts"
    local group accels action target paths=() i=0 base=/org/gnome/settings-daemon/plugins/media-keys
    for entry in "${SHORTCUTS[@]}"; do
        IFS='|' read -r group accels action target <<<"$entry"
        local -a list=()
        read -ra list <<<"$accels"
        case $target in
            -) ;;
            launch:*)
                # Own namespace (kinobu-N) so the user's custom shortcuts are kept
                local path="$base/custom-keybindings/$APP_ID-$i/"
                dconf_set "${path}name" "'$action'"
                dconf_set "${path}command" "'$LAUNCHER ${target#launch:}'"
                dconf_set "${path}binding" "'${list[0]}'"
                paths+=("$path")
                i=$((i + 1)) ;;
            *)
                dconf_set "$target" "$(to_gvariant "${list[@]}")" ;;
        esac
    done
    # Merge: keep custom shortcuts that are not ours, replace ours
    local current kept=() item
    current=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
    for item in $(from_gvariant "$current"); do
        if [[ $item != *"/$APP_ID-"* ]]; then kept+=("$item"); fi
    done
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$(to_gvariant "${kept[@]}" "${paths[@]}")"
    free_kinobu_keys
    write_cheat_sheet
    ok "${#SHORTCUTS[@]} shortcuts ready (Super+K shows them all)"
    write_welcome
}

# Writes kinobu-launch, the helper the app shortcuts run
write_launcher() {
    step "Launcher (${LAUNCHER/#$HOME/\~})"
    put_file "$LAUNCHER" 0755 < <(render apps/kinobu-launch SYSTEM_DIR PROGRAMS_DIR BIN_DIR)
    report_changed "Installed"
}

# Writes the Super+K cheat sheet: its data (group, keys, action) from the SHORTCUTS table and
# the window that shows it (files/apps/keys.py: Python with GTK 4 and libadwaita)
write_cheat_sheet() {
    local entry group accels action target
    put_file "$SYSTEM_DIR/data/shortcuts.tsv" < <(
        for entry in "${SHORTCUTS[@]}"; do
            IFS='|' read -r group accels action target <<<"$entry"
            printf '%s\t%s\t%s\n' "$group" "$(pretty_all_keys "$accels")" "$action"
        done)
    put_file "$PROGRAMS_DIR/keys.py" < <(render apps/keys.py SYSTEM_DIR PROGRAMS_DIR)
}

# The texts of Kinobu's own apps and notices, one file per language (files/i18n), and the small
# module the Python apps read them with. Shared by the welcome tour and the notifier.
write_translations() {
    local file
    for file in "$ROOT_DIR/files"/i18n/*.json; do
        put_file "$SYSTEM_DIR/i18n/${file##*/}" < "$file"
    done
    put_file "$PROGRAMS_DIR/kinobu_i18n.py" < <(render apps/kinobu_i18n.py)
}

# The welcome tour: its window and its launcher in the app grid. show_welcome opens it once.
write_welcome() {
    step "Welcome tour"
    local changed=false
    write_translations
    put_file "$PROGRAMS_DIR/welcome.py" < <(render apps/welcome.py LAUNCHER)
    if $CHANGED; then changed=true; fi
    put_file "$PREFIX/share/applications/os.kinobu.Welcome.desktop" < <(render apps/welcome.desktop SYSTEM_DIR PROGRAMS_DIR)
    if $changed; then CHANGED=true; fi
    report_changed "Ready in the app grid (Kinobu Welcome)"
}

# After the first full run the tour opens once: right away when nothing needs a reboot, and at
# the next login otherwise (an autostart entry the window deletes when it is closed)
# shellcheck disable=SC2034  # WELCOME is read by finish_run (core.sh)
show_welcome() {
    if [[ ! -f $PROGRAMS_DIR/welcome.py ]]; then return 0; fi
    put_user_file "$HOME/.config/autostart/$APP_ID-welcome.desktop" < <(render apps/welcome-autostart.desktop SYSTEM_DIR PROGRAMS_DIR)
    if ((${#REBOOT_REASONS[@]} == 0)) && [[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; then
        (setsid python3 "$PROGRAMS_DIR/welcome.py" </dev/null >/dev/null 2>&1 &)
        WELCOME=now
    else
        WELCOME=login
    fi
}
