# shellcheck shell=bash
# Block "services": typing for dictation (ydotool) and services a desktop does not need.

# Lets ydotool type for Handy and switches off services a desktop does not use
configure_services() {
    step "ydotool (types dictated text on Wayland)"
    put_file /etc/udev/rules.d/60-uinput-uaccess.rules \
        <<<'KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", OPTIONS+="static_node=uinput"'
    if $CHANGED; then
        root udevadm control --reload-rules
        root udevadm trigger --subsystem-match=misc --sysname-match=uinput || true
    fi
    ydotool_retry
    if systemctl --user enable --now ydotool.service 2>/dev/null; then
        ok "ydotool running (Handy types through it)"
    else
        warn "Could not start ydotool.service (it starts after a reboot)"
    fi

    step "ModemManager"
    # Only needed for mobile broadband modems (built-in WWAN, SIM dongles).
    # Phone hotspots and USB/Bluetooth tethering do not use it.
    if [[ -n "$(ls -A /sys/class/wwan 2>/dev/null)" ]] || compgen -G '/sys/class/net/wwan*' >/dev/null; then
        ok "Mobile broadband modem found: kept"
    elif [[ "$(systemctl is-enabled ModemManager.service 2>/dev/null)" == masked ]]; then
        ok "Already disabled"
    elif systemctl cat ModemManager.service &>/dev/null; then
        root systemctl mask --now ModemManager.service
        ok "Disabled (undo: sudo systemctl unmask --now ModemManager)"
    else
        ok "Not installed"
    fi

    step "OpenVPN system service"
    # Only starts tunnels from /etc/openvpn; NetworkManager VPNs do not need it
    if systemctl is-enabled --quiet openvpn.service 2>/dev/null; then
        root systemctl disable --now openvpn.service
        ok "Disabled"
    else
        ok "Not active"
    fi
}

# ydotool starts at login, sometimes before GNOME gives the user /dev/uinput: its unit retries
# every 100 ms and gives up after 5 failures. A user drop-in makes it retry every 2 s instead.
ydotool_retry() {
    put_user_file "$HOME/.config/systemd/user/ydotool.service.d/$APP_ID-retry.conf" < <(render services/ydotool-retry.conf)
    if $CHANGED; then systemctl --user daemon-reload 2>/dev/null || true; fi
    report_changed "Calm retries at login (~/.config/systemd/user/ydotool.service.d/)" "Login retries already calm"
}
