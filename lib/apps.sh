# shellcheck shell=bash
# Blocks "apt" (optimised packages) and "apps" (repositories, system upgrade, the chosen
# software, Handy, the GraalVM JDK and cleanup).

# ---------------------------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------------------------
# APT packages installed always (the rest is chosen in the menus, see software.sh)
APT_PACKAGES=(
    # Command line essentials
    curl wget git jq unzip fastfetch ripgrep fd-find gh
    # Development: build tools, Node.js and Python as a system-wide base
    build-essential nodejs npm python3-pip python3-venv python-is-python3
    # GNOME apps (they sync with Google, Microsoft... through Settings > Online Accounts)
    gnome-contacts gnome-calendar gnome-weather gnome-clocks gnome-calculator gnome-characters geary
    # GNOME extensions support
    gnome-shell-extensions gnome-shell-ubuntu-extensions gnome-browser-connector
    # System helpers: VPN, AppImages, graphics info, typing on Wayland
    wireguard libfuse2t64 vulkan-tools mesa-utils ydotool
    # What Willow's safe actions use (kinobu-do): music players and screen brightness
    playerctl brightnessctl
    # The themes' icons, cursors and fonts from Ubuntu (Seasons; the others are in lib/look.sh)
    papirus-icon-theme numix-icon-theme-circle elementary-icon-theme bibata-cursor-theme breeze-cursor-theme
    fonts-inter fonts-jetbrains-mono
    # GTK 4 and libadwaita from Python: Kinobu's own windows
    python3-gi gir1.2-gtk-4.0 gir1.2-adw-1
)
APT_REMOVE=(yelp)
# Packages for services a desktop does not use (enterprise login, systemd-networkd, cloud)
APT_PURGE_UNUSED=(sssd networkd-dispatcher cloud-init cloud-init-base)
SNAPS=()                            # snaps installed always ("name [flags]")

# Vendor APT repositories, added only when their app is chosen:
# "software id|name|key URL|keyring|source file in files/apt/"
REPOS=(
    "helium|Helium|https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc|/usr/share/keyrings/helium.gpg|helium.list"
    "spotify|Spotify|https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc|/usr/share/keyrings/spotify.gpg|spotify.list"
    "vscode|Visual Studio Code|https://packages.microsoft.com/keys/microsoft.asc|/usr/share/keyrings/microsoft.gpg|vscode.sources"
    "cursor|Cursor|https://downloads.cursor.com/keys/anysphere.asc|/usr/share/keyrings/anysphere.gpg|cursor.sources"
    "docker|Docker|https://download.docker.com/linux/ubuntu/gpg|/etc/apt/keyrings/docker.asc|docker.sources"
)
# Browsers that can become the default one, in order of preference: "software id|launcher"
BROWSERS=("helium|helium.desktop" "chrome|google-chrome.desktop")

# Java: GraalVM JDK (Oracle tarball, not in APT)
GRAAL_VERSION="25.0.5"
GRAAL_URL="https://gds.oracle.com/download/graal/25/archive/graalvm-jdk-${GRAAL_VERSION}_linux-x64_bin.tar.gz"
GRAAL_SHA256=""                     # optional: verified when set
JAVA_DIR="/opt/java/graalvm-jdk-${GRAAL_VERSION}"

# Handy settings Kinobu sets (only what differs from Handy's own defaults; the transcription
# language follows the desktop language). Microphone and model are chosen in Handy itself.
HANDY_SETTINGS='{
  "clipboard_handling": "copy_to_clipboard",
  "typing_tool": "ydotool",
  "shortcut_activation": "toggle",
  "overlay_style": "none",
  "start_hidden": true,
  "autostart_enabled": true
}'
HANDY_WORDS='["Willow", "Kinobu", "Seasons"]'   # names Handy should hear right; added to the user's own

# ---------------------------------------------------------------------------------------------
# Block: apt
# ---------------------------------------------------------------------------------------------
# Prefers the x86-64-v3 builds of Ubuntu packages when the processor supports them.
# Undo: sudo rm /etc/apt/apt.conf.d/99enable-amd64v3
enable_apt_v3() {
    step "Faster packages for this processor"
    if ${HAS_V3:-false}; then
        put_file /etc/apt/apt.conf.d/99enable-amd64v3 <<<'APT::Architecture-Variants "amd64v3";'
        report_changed "Turned on (installed packages switch on the next upgrade)" "Already turned on"
    else
        info "This processor does not support them: the standard packages are kept"
    fi
}

# ---------------------------------------------------------------------------------------------
# Block: apps
# ---------------------------------------------------------------------------------------------
manage_applications() {
    add_repositories
    upgrade_system
    install_packages
    install_snaps
    install_debs
    install_handy
    configure_handy
    install_graalvm
    remove_unneeded
    set_default_browser
}

# Adds the repositories of the chosen apps only.
add_repositories() {
    local entry id name key keyring file count=0
    # shellcheck disable=SC2034  # read by render (files/apt/docker.sources)
    CODENAME=$(os_release UBUNTU_CODENAME)
    step "Software sources for the apps you chose"
    root install -m 0755 -d /etc/apt/keyrings
    for entry in "${REPOS[@]}"; do
        IFS='|' read -r id name key keyring file <<<"$entry"
        if ! chosen "$id"; then continue; fi
        count=$((count + 1))
        if put_key "$key" "$keyring"; then
            put_file "/etc/apt/sources.list.d/$file" < <(render "apt/$file" CODENAME)
            ok "$name"
        else
            warn "The $name source could not be added: $name will not be installed"
        fi
    done
    if ((count == 0)); then ok "None needed"; fi
}

upgrade_system() {
    step "Updating Ubuntu (this can take a while)"
    apt_get update
    apt_get full-upgrade
    ok "Ubuntu is up to date"
}

# The base packages and the chosen apps that come from APT.
install_packages() {
    local id src in_libvirt=false
    local -a wanted=() pkgs=()
    for id in "${CHOSEN[@]}"; do
        src=$(software_source "$id")
        if [[ $src == apt:* ]]; then
            read -ra pkgs <<<"${src#apt:}"
            wanted+=("${pkgs[@]}")
        fi
    done
    # Ubuntu's libvirt packages add every administrator to the libvirt group: remember the state before
    if [[ " $(id -nG) " == *" libvirt "* ]]; then in_libvirt=true; fi

    step "Base tools and your apps"
    apt_install "${APT_PACKAGES[@]}" "${wanted[@]}"
    if chosen docker; then info "Docker: use it as sudo docker (you are kept out of the docker group on purpose)"; fi

    if chosen virtmanager; then
        step "Virtual machines"
        if [[ -e /dev/kvm ]]; then
            ok "Hardware virtualisation is available"
        else
            warn "Virtual machines will be slow: turn on virtualisation (Intel VT-x or AMD-V) in the BIOS"
        fi
        # Like Docker: the libvirt group is close to root, so it is only kept if it was already there
        if ! $in_libvirt && [[ ",$(getent group libvirt | cut -d: -f4)," == *",$USER,"* ]]; then
            root gpasswd -d "$USER" libvirt >/dev/null
            ok "virt-manager will ask for your password (you are kept out of the libvirt group)"
        fi
        # The network that gives the virtual machines internet access, started with the system
        if [[ "$(root virsh -c qemu:///system net-info default 2>/dev/null)" == *Autostart:*yes* ]]; then
            ok "The virtual network starts with the computer"
        elif root virsh -c qemu:///system net-autostart default >/dev/null 2>&1; then
            if [[ "$(root virsh -c qemu:///system net-info default 2>/dev/null)" != *Active:*yes* ]]; then
                root virsh -c qemu:///system net-start default >/dev/null 2>&1 || true
            fi
            ok "The virtual network is turned on"
        else
            warn "The virtual network could not be turned on (virsh net-autostart default)"
        fi
    fi
}

install_snaps() {
    local id src entry name opts
    local -a snaps=("${SNAPS[@]}")
    for id in "${CHOSEN[@]}"; do
        src=$(software_source "$id")
        if [[ $src == snap:* ]]; then snaps+=("${src#snap:}"); fi
    done
    if ((${#snaps[@]} == 0)); then return 0; fi
    step "Apps from the Snap Store"
    for entry in "${snaps[@]}"; do
        read -r name opts <<<"$entry"
        if snap list "$name" &>/dev/null; then
            ok "$name already installed"
        else
            # shellcheck disable=SC2086  # opts holds space-separated flags
            run sudo -n snap install "$name" $opts
            ok "$name installed"
        fi
    done
}

# Vendor .deb files that add their own repository, so apt keeps them updated.
install_debs() {
    local id src pkg url
    for id in "${CHOSEN[@]}"; do
        src=$(software_source "$id")
        if [[ $src != deb:* ]]; then continue; fi
        read -r pkg url <<<"${src#deb:}"
        step "$(software_name "$id")"
        if is_installed "$pkg"; then
            ok "Already installed"
        else
            install_deb "$url" "$id"
            ok "Installed (it keeps itself updated with the system)"
        fi
    done
}

# Handy is always there: dictation on Super+Space and the ears of the voice assistant.
install_handy() {
    local latest version="" url="" current
    step "Handy (dictation that stays on this computer)"
    latest=$(curl -fsSL https://api.github.com/repos/cjpais/Handy/releases/latest 2>>"$LOG" \
        | jq -r '(.tag_name | ltrimstr("v")) + " " + ([.assets[] | select(.name | endswith("_amd64.deb")) | .browser_download_url][0] // "")' 2>>"$LOG" \
        || true)
    read -r version url <<<"$latest"
    current=$(dpkg-query -W -f='${Version}' handy 2>/dev/null || true)
    if [[ -z $url ]]; then
        if [[ -n $current ]]; then
            warn "Could not check for a newer Handy ($current kept)"
        else
            warn "Handy could not be downloaded: get it from https://github.com/cjpais/Handy/releases"
        fi
        return 0
    fi
    if [[ -n $current ]] && dpkg --compare-versions "$current" ge "$version"; then
        ok "Up to date ($current)"
        return 0
    fi
    install_deb "$url" handy
    ok "Handy $version installed"
}

# Applies HANDY_SETTINGS to Handy's settings store. A running Handy would write its old
# settings back, so it is stopped around the change.
configure_handy() {
    local store="$HOME/.local/share/com.pais.handy/settings_store.json" lang running=false
    if ! is_installed handy; then return 0; fi
    lang=${LANG%%[_.]*}
    if [[ -z $lang || $lang == C || $lang == POSIX ]]; then lang=auto; fi
    if pgrep -x handy >/dev/null; then running=true; pkill -x handy || true; sleep 1; fi
    # shellcheck disable=SC2016  # $s and $lang are jq variables
    edit_json "$store" '.settings = ((.settings // {}) + $s + {selected_language: $lang})
        | .settings.custom_words = ((.settings.custom_words // []) + $words | unique)' \
        --argjson s "$HANDY_SETTINGS" --arg lang "$lang" --argjson words "$HANDY_WORDS"
    if $running; then (setsid handy </dev/null >/dev/null 2>&1 &); fi
    report_changed "Set up: types what you say, starts hidden with the computer, language $lang" "Already set up"
}

# Installs the GraalVM JDK into /opt/java (Oracle tarball).
install_graalvm() {
    step "Java (GraalVM JDK $GRAAL_VERSION)"
    if [[ -x $JAVA_DIR/bin/java ]]; then
        ok "Already installed"
        return 0
    fi
    download "$GRAAL_URL" "$TMP_DIR/graalvm.tar.gz"
    if [[ -n $GRAAL_SHA256 ]]; then
        sha256sum -c --quiet - <<<"$GRAAL_SHA256  $TMP_DIR/graalvm.tar.gz" || die "The GraalVM download is damaged (checksum mismatch)"
    fi
    # Unpack next to the target and rename at the end, so an interrupted run never leaves a
    # half-unpacked JDK that looks installed
    root rm -rf "$JAVA_DIR.partial"
    root mkdir -p "$JAVA_DIR.partial"
    run sudo -n tar -xzf "$TMP_DIR/graalvm.tar.gz" -C "$JAVA_DIR.partial" --strip-components=1
    root mv "$JAVA_DIR.partial" "$JAVA_DIR"
    ok "Installed in $JAVA_DIR"
}

remove_unneeded() {
    local pkg
    local -a remove=() purge=()
    step "Removing what a desktop does not need"
    for pkg in "${APT_REMOVE[@]}"; do
        if is_installed "$pkg"; then remove+=("$pkg"); fi
    done
    for pkg in "${APT_PURGE_UNUSED[@]}"; do
        # A configured sssd means an enterprise login: never remove it then
        if [[ $pkg == sssd && -e /etc/sssd/sssd.conf ]]; then
            info "sssd is configured (enterprise login): kept"
            continue
        fi
        if is_installed "$pkg"; then purge+=("$pkg"); fi
    done
    if ((${#remove[@]})); then apt_get remove "${remove[@]}"; fi
    if ((${#purge[@]})); then apt_get purge "${purge[@]}"; fi
    apt_get autoremove --purge
    apt_get clean
    if ((${#remove[@]} + ${#purge[@]})); then ok "Removed: ${remove[*]} ${purge[*]}"; else ok "Nothing to remove"; fi
}

# The first chosen browser that is installed becomes the default; Firefox stays otherwise.
set_default_browser() {
    local entry id desktop
    step "Default web browser"
    for entry in "${BROWSERS[@]}"; do
        IFS='|' read -r id desktop <<<"$entry"
        if ! chosen "$id" || [[ ! -f /usr/share/applications/$desktop ]]; then continue; fi
        if xdg-settings set default-web-browser "$desktop" 2>>"$LOG"; then
            ok "$(software_name "$id") (Firefox stays installed)"
        else
            warn "$(software_name "$id") could not be made the default browser: choose it in Settings > Apps"
        fi
        return 0
    done
    ok "Firefox (no other browser chosen)"
}
