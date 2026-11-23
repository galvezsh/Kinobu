# shellcheck shell=bash
# Block "user": Oh My Bash, the Nerd Font, ~/.bashrc, fastfetch and the terminal fonts.

# ---------------------------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------------------------
# Shell: Oh My Bash + a Nerd Font for its icons
# shellcheck disable=SC2034  # read by render (files/shell/bashrc.sh, files/skills/kinobu/SKILL.md)
OMB_THEME="powerbash10k"
OMB_PLUGINS=(git)
OMB_COMPLETIONS=(git ssh)
OMB_ALIASES=(general)
SHELL_ALIASES=("ll=ls -lhav")       # loaded after Oh My Bash, so they win (ff is a function: fastfetch in the accent colour)
NERD_FONT_VERSION="v3.5.1"
NERD_FONT_ARCHIVE="UbuntuSans"      # https://github.com/ryanoasis/nerd-fonts/releases
NERD_FONT_SHA256="abcbf48bb68e2dd09d43dc0ea04f6878cc8ee46334a9f9ce52b51e06f31aa0d0"
NERD_FONT_FILES="UbuntuSansMonoNerdFontMono-*.ttf"
NERD_FONT_FAMILY="UbuntuSansMono Nerd Font Mono"
TERMINAL_FONT_SIZE=11
# GNOME's own account pictures (gnome-control-center-faces): one at random for a user with none
ACCOUNT_FACES=/usr/share/pixmaps/faces
# Snaps of JetBrains-based IDEs whose terminal gets the Nerd Font (the installed ones)
JETBRAINS_IDES=(intellij-idea pycharm webstorm clion goland rider phpstorm rubymine rustrover datagrip android-studio)

# ---------------------------------------------------------------------------------------------
# Block: user
# ---------------------------------------------------------------------------------------------
# Installs Oh My Bash and the Nerd Font, writes the managed ~/.bashrc block and the fastfetch
# config, sets that font in every terminal and the palette in Ptyxis
configure_user() {
    step "Oh My Bash"
    if [[ -f $HOME/.oh-my-bash/oh-my-bash.sh ]]; then
        ok "Already installed (updates itself)"
    else
        # Cloned instead of using its installer, which replaces ~/.bashrc
        run git clone --depth 1 https://github.com/ohmybash/oh-my-bash.git "$HOME/.oh-my-bash"
        ok "Installed in ~/.oh-my-bash"
    fi

    step "Nerd Font ($NERD_FONT_FAMILY)"
    if [[ "$(fc-list : family)" == *"$NERD_FONT_FAMILY"* ]]; then
        ok "Already installed"
    else
        local font_dir="$HOME/.local/share/fonts/NerdFonts/$NERD_FONT_ARCHIVE"
        download "https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONT_VERSION/$NERD_FONT_ARCHIVE.tar.xz" \
            "$TMP_DIR/nerdfont.tar.xz"
        echo "$NERD_FONT_SHA256  $TMP_DIR/nerdfont.tar.xz" | sha256sum -c --quiet - \
            || die "Nerd Font checksum mismatch"
        mkdir -p "$font_dir"
        tar -xJf "$TMP_DIR/nerdfont.tar.xz" -C "$font_dir" --wildcards "$NERD_FONT_FILES"
        fc-cache -f "$font_dir" >/dev/null
        ok "Installed in ${font_dir/#$HOME/\~} (checksum verified)"
    fi

    write_shell_profile
    write_fastfetch

    step "Terminal: Ptyxis (font and palette)"
    if ! has_line org.gnome.Ptyxis "$(gsettings list-schemas 2>/dev/null)"; then
        info "Ptyxis is not installed"
    elif [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
        warn "No desktop session: Ptyxis was not set up (run $APP_NAME again from the GNOME desktop)"
    else
        gsettings set org.gnome.Ptyxis use-system-font false
        gsettings set org.gnome.Ptyxis font-name "$NERD_FONT_FAMILY $TERMINAL_FONT_SIZE"
        ptyxis_fresh_start
        # The palette belongs to a profile: Ptyxis creates the default one on first start
        local uuid
        uuid=$(gsettings get org.gnome.Ptyxis default-profile-uuid | tr -d "'") || true
        if [[ -z $uuid ]]; then
            uuid=$(tr -d - </proc/sys/kernel/random/uuid)
            gsettings set org.gnome.Ptyxis profile-uuids "['$uuid']"
            gsettings set org.gnome.Ptyxis default-profile-uuid "'$uuid'"
        fi
        ok "$NERD_FONT_FAMILY $TERMINAL_FONT_SIZE (the colours come from the theme)"
    fi

    step "Terminal font: VS Code"
    # Added only when missing, so a font the user chose is kept; a settings.json with comments is left alone
    # shellcheck disable=SC2016  # $k and $v are jq variables
    edit_json "$HOME/.config/Code/User/settings.json" '.[$k] //= $v' \
        --arg k terminal.integrated.fontFamily --arg v "$NERD_FONT_FAMILY"
    report_changed "Set in settings.json" "Nothing to change"

    step "Terminal font: JetBrains-based IDEs"
    # The terminal has its own font since 2025.1.1 (options/terminal-font.xml,
    # component TerminalFontOptions). It is written before the first launch too,
    # and the IDE carries it over when it updates to a new version. The config
    # folder name comes from the IDE itself (product-info.json): it is not always
    # <name><year.minor>, e.g. Android Studio uses three numbers and ~/.config/Google.
    local snap info_file vendor data_dir options found=0
    for snap in "${JETBRAINS_IDES[@]}"; do
        info_file="/snap/$snap/current/product-info.json"
        if [[ ! -f $info_file ]]; then continue; fi
        found=$((found + 1))
        vendor=$(jq -r '.productVendor // "JetBrains"' "$info_file")
        data_dir=$(jq -r '.dataDirectoryName // empty' "$info_file")
        if [[ -z $data_dir ]]; then warn "$snap: config folder unknown, set its terminal font by hand"; continue; fi
        options="$HOME/.config/$vendor/$data_dir/options"
        # After an IDE update, a new config folder written before its first start would stop
        # the IDE from importing the previous version's settings: wait until it has run once
        if [[ ! -d $HOME/.config/$vendor/$data_dir ]] \
            && compgen -G "$HOME/.config/$vendor/${data_dir%%[0-9]*}[0-9]*" >/dev/null; then
            info "$data_dir: open it once to import your settings, then run $APP_NAME again"
            continue
        fi
        if [[ -f $options/terminal-font.xml ]]; then
            ok "$data_dir: terminal font already set"
            continue
        fi
        mkdir -p "$options"
        render shell/jetbrains-terminal-font.xml FONT="$NERD_FONT_FAMILY" >"$options/terminal-font.xml"
        ok "$data_dir (${options/#$HOME/\~})"
    done
    if ((found == 0)); then info "No JetBrains-based IDE installed"; fi

    set_account_picture
}

# A user with no account picture gets one of GNOME's own at random, so the login screen and the
# top bar's menu never show the empty silhouette. Through AccountsService, which lets every user
# change their own picture without sudo; a picture already there is never replaced. Nothing here
# stops the setup: without AccountsService or GNOME's pictures it only says so.
set_account_picture() {
    step "Account picture"
    local accounts=org.freedesktop.Accounts user icon face
    user=$(gdbus call --system --dest $accounts --object-path /org/freedesktop/Accounts \
        --method $accounts.FindUserByName "$(id -un)" 2>>"$LOG" || true)
    user=${user#*\'}; user=${user%%\'*}
    if [[ $user != /org/freedesktop/Accounts/* ]]; then
        info "The account service did not answer: choose a picture in Settings > System > Users"
        return 0
    fi
    icon=$(gdbus call --system --dest $accounts --object-path "$user" \
        --method org.freedesktop.DBus.Properties.Get $accounts.User IconFile 2>>"$LOG" || true)
    icon=${icon#*\'}; icon=${icon%%\'*}
    if [[ -n $icon && -s $icon ]]; then
        ok "Yours is kept"
        return 0
    fi
    face=$(find "$ACCOUNT_FACES" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.png' \) 2>/dev/null | shuf -n 1 || true)
    if [[ -z $face ]]; then
        info "GNOME's pictures are not installed: choose one in Settings > System > Users"
    elif gdbus call --system --dest $accounts --object-path "$user" \
        --method $accounts.User.SetIconFile "$face" >>"$LOG" 2>&1; then
        ok "One of GNOME's at random: $(basename "${face%.*}") (change it in Settings > System > Users)"
    else
        warn "The account picture could not be set: choose one in Settings > System > Users"
    fi
}

# Ptyxis opens only the window asked for: its session restore (on by default) brought back the
# last session's windows with the first one after logging in, so Super+Enter opened two or more,
# the agent's tab among them without its program. Also on updates, for computers set up before.
ptyxis_fresh_start() {
    if has_line org.gnome.Ptyxis "$(gsettings list-schemas 2>/dev/null)" && [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
        gsettings set org.gnome.Ptyxis restore-session false
    fi
}

# Writes the managed block of ~/.bashrc: environment, Oh My Bash, aliases, ff and fastfetch
write_shell_profile() {
    step "Shell profile (.bashrc)"
    local alias_lines="" entry
    for entry in "${SHELL_ALIASES[@]}"; do alias_lines+="alias ${entry%%=*}='${entry#*=}'"$'\n'; done
    # files/shell/bashrc.sh, in this order: environment first (Oh My Bash sees it), then Oh My
    # Bash, then our aliases so they win over its own ones (it defines ll too)
    put_block "$HOME/.bashrc" "# >>> $APP_ID >>>" "# <<< $APP_ID <<<" "$(render shell/bashrc.sh APP_NAME JAVA_DIR \
        OMB_THEME OMB_PLUGINS="${OMB_PLUGINS[*]}" OMB_COMPLETIONS="${OMB_COMPLETIONS[*]}" \
        OMB_ALIASES="${OMB_ALIASES[*]}" ALIAS_LINES="$alias_lines")"
    if $CHANGED; then NEXT_STEPS+=("Open a new terminal to see the new prompt"); fi
    report_changed "Updated (backup: ~/.bashrc.$APP_ID.bak)"
}

# Writes the fastfetch config (per user) and its rings logo and taglines (shared) (a config without the Managed by
# line is the user's and is kept). Colours: $1 outer ring, $2 inner ring, $3 centre; the ff
# function in ~/.bashrc gives them the desktop accent.
write_fastfetch() {
    step "System summary (fastfetch)"
    local ff_dir="$HOME/.config/fastfetch" changed=false
    if [[ -f $ff_dir/config.jsonc ]] && ! grep -qF "Managed by $APP_NAME" "$ff_dir/config.jsonc"; then
        info "Your own ~/.config/fastfetch/config.jsonc was kept"
        return 0
    fi
    put_file "$SYSTEM_DIR/data/fastfetch-logo.txt" < <(render shell/fastfetch-logo.txt)
    if $CHANGED; then changed=true; fi
    put_file "$SYSTEM_DIR/data/taglines.txt" < <(render branding/taglines.txt)
    if $CHANGED; then changed=true; fi
    put_user_file "$ff_dir/config.jsonc" < <(render shell/fastfetch.jsonc NAME="$APP_NAME" \
        VERSION="$APP_VERSION" LOGO="$SYSTEM_DIR/data/fastfetch-logo.txt" TAGLINES="$SYSTEM_DIR/data/taglines.txt")
    if $changed; then CHANGED=true; fi
    report_changed "Written to ~/.config/fastfetch/"
}
