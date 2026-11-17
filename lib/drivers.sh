# shellcheck shell=bash
# Block "drivers": the proprietary drivers Ubuntu recommends for this hardware.

# Installs the proprietary drivers Ubuntu recommends (GPU, Wi-Fi...), whatever the hardware
install_drivers() {
    step "Looking for recommended drivers"
    if ! command -v ubuntu-drivers &>/dev/null; then
        apt_install ubuntu-drivers-common
    fi
    local before after
    before=$(dpkg-query -W -f='${Package}\n' | md5sum)
    # The lookup takes a few seconds: it runs with the live line, its answer goes to a file
    run bash -c 'ubuntu-drivers list >"$1" 2>/dev/null || true' _ "$TMP_DIR/drivers"
    if [[ ! -s $TMP_DIR/drivers ]]; then
        ok "No proprietary drivers needed"
        return 0
    fi
    wait_for_apt
    run sudo -n ubuntu-drivers install
    after=$(dpkg-query -W -f='${Package}\n' | md5sum)
    if [[ $before == "$after" ]]; then
        ok "Recommended drivers already installed"
    else
        ok "Drivers installed"
        need_reboot "new drivers"
        if [[ "$(mokutil --sb-state 2>/dev/null)" == *enabled* ]]; then
            info "Secure Boot is on: if a blue 'Enroll MOK' screen appears on reboot, accept it"
        fi
    fi
}
