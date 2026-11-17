# shellcheck shell=bash
# The quick system check that runs first. It asks for no password and changes nothing.

# Reads one KEY from /etc/os-release.
os_release() {
    local key value
    while IFS='=' read -r key value; do
        if [[ $key == "$1" ]]; then value=${value#\"}; echo "${value%\"}"; return 0; fi
    done </etc/os-release
}

# True when one of Ubuntu's servers answers (a single address may be slow, so several are tried).
online() {
    local host
    for host in archive.ubuntu.com/443 security.ubuntu.com/443 connectivity-check.ubuntu.com/80 archive.ubuntu.com/80; do
        if timeout 3 bash -c ": </dev/tcp/$host" 2>/dev/null; then return 0; fi
    done
    return 1
}

# Requirements: any ✖ stops the setup. The reasons are collected in CHECK_FAILS.
check_requirements() {
    local groups name version arch free session
    ui_section "System"

    if ((EUID == 0)); then
        ui_fail "Regular user" "running as root"
        CHECK_FAILS+=("Run $APP_NAME as your normal user, without sudo. It asks for your password when it needs it.")
    else
        ui_ok "Regular user" "$USER"
    fi

    groups=" $(id -nG) "
    if [[ $ACTION == user ]]; then
        if [[ -f $SYSTEM_DIR/src/kinobu.sh ]]; then
            ui_ok "$APP_NAME on this computer" "$(cat "$SYSTEM_DIR/version" 2>/dev/null)"
        else
            ui_fail "$APP_NAME on this computer" "not installed"
            CHECK_FAILS+=("$APP_NAME is not installed on this computer yet: an administrator must run bash kinobu.sh --install first.")
        fi
    elif [[ $groups == *" sudo "* || $groups == *" admin "* ]]; then
        ui_ok "Administrator rights"
    else
        ui_fail "Administrator rights" "$USER cannot use sudo"
        CHECK_FAILS+=("Your user is not an administrator. Ask one to run: sudo usermod -aG sudo $USER (then log out and in).")
    fi

    name=$(os_release ID) version=$(os_release VERSION_ID)
    if [[ $name != ubuntu ]]; then
        ui_fail "Ubuntu $SUPPORTED_UBUNTU LTS" "this is $(os_release PRETTY_NAME)"
        CHECK_FAILS+=("$APP_NAME is made for Ubuntu $SUPPORTED_UBUNTU LTS.")
    elif [[ $version != "$SUPPORTED_UBUNTU" ]]; then
        ui_warn "Ubuntu $SUPPORTED_UBUNTU LTS" "this is $version: not tested, some steps may fail"
    else
        ui_ok "Ubuntu $SUPPORTED_UBUNTU LTS"
    fi

    arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
    if [[ $arch == amd64 ]]; then
        ui_ok "64-bit Intel or AMD processor"
    else
        ui_fail "64-bit Intel or AMD processor" "this is $arch"
        CHECK_FAILS+=("$APP_NAME only supports 64-bit Intel and AMD computers (amd64).")
    fi

    session=${XDG_SESSION_TYPE:-}
    if [[ ${XDG_CURRENT_DESKTOP:-} == *GNOME* && -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; then
        ui_ok "GNOME desktop session" "${session^}"
    else
        ui_fail "GNOME desktop session" "not found"
        CHECK_FAILS+=("Open a terminal inside the GNOME desktop and run $APP_NAME there (not over SSH or a text console).")
    fi

    free=$(df --output=avail -BG / | tail -n 1 | tr -dc '0-9')
    if [[ $ACTION == user ]]; then
        ui_ok "Free disk space" "$free GB free"
    elif ((free >= MIN_FREE_GB)); then
        ui_ok "Free disk space" "$free GB free, $MIN_FREE_GB GB needed"
    else
        ui_fail "Free disk space" "$free GB free, $MIN_FREE_GB GB needed"
        CHECK_FAILS+=("Free at least $MIN_FREE_GB GB on the system disk.")
    fi

    if online; then
        ui_ok "Internet connection"
    else
        ui_fail "Internet connection" "Ubuntu's servers cannot be reached"
        CHECK_FAILS+=("Connect to the internet and try again.")
    fi
}

# Hardware facts: they stop nothing, they only decide what the setup offers.
# shellcheck disable=SC2034  # HAS_V3, HAS_KVM and HAS_DGPU are read by the setup blocks
check_hardware() {
    local text gpu
    ui_section "Hardware"

    HAS_V3=false
    text=$(/lib64/ld-linux-x86-64.so.2 --help 2>/dev/null || true)
    if [[ $text == *"x86-64-v3 (supported"* ]]; then
        HAS_V3=true
        ui_fact "Optimised packages (x86-64-v3)" "supported"
    else
        ui_fact "Optimised packages (x86-64-v3)" "not supported: standard packages will be used"
    fi

    HAS_KVM=false
    text=$(</proc/cpuinfo)
    if [[ -e /dev/kvm ]]; then
        HAS_KVM=true
        ui_fact "Hardware virtualisation" "available"
    elif [[ $text == *" vmx"* || $text == *" svm"* ]]; then
        ui_fact "Hardware virtualisation" "turned off: enable Intel VT-x or AMD-V in the BIOS for virtual machines"
    else
        ui_fact "Hardware virtualisation" "not available: virtual machines will be slow"
    fi

    HAS_DGPU=false
    gpu=$(lspci 2>/dev/null | grep -E 'VGA|3D|Display' | grep -E "$DISCRETE_GPU" | head -n 1 || true)
    if [[ -n $gpu ]]; then
        HAS_DGPU=true
        gpu=${gpu#*: }; gpu=${gpu% (rev*}; gpu=${gpu/ Corporation/}
        ui_fact "Dedicated graphics card" "$gpu"
    else
        ui_fact "Dedicated graphics card" "none: integrated graphics"
    fi

    text=$(mokutil --sb-state 2>/dev/null || true)
    if [[ $text == *enabled* ]]; then
        ui_fact "Secure Boot" "on: new drivers may ask you to set a password at the next restart"
    elif [[ -d /sys/firmware/efi ]]; then
        ui_fact "Secure Boot" "off"
    else
        ui_fact "Secure Boot" "not used (legacy BIOS)"
    fi
}

# Runs both parts and prints the verdict. Returns 1 when a requirement is missing.
check_system() {
    local reason
    CHECK_FAILS=()
    check_requirements
    check_hardware
    echo
    if ((${#CHECK_FAILS[@]})); then
        printf '  %s%s✖ This computer is not ready yet:%s\n' "$C_ERR" "$C_BOLD" "$C_RESET"
        for reason in "${CHECK_FAILS[@]}"; do printf '    · %s\n' "$reason"; done
        echo
        return 1
    fi
    printf '  %s%s✔ Everything is in order.%s\n\n' "$C_OK" "$C_BOLD" "$C_RESET"
}
