# shellcheck shell=bash
# shellcheck disable=SC2034  # LOG, SUDO_PID, CURRENT... are read by cleanup and on_error (kinobu.sh)
# What every block uses: messages, the log, running commands quietly, files, apt and sudo.

STATE_DIR="$HOME/.local/state/$APP_ID"      # logs and GNOME settings backups
CONFIG_DIR="$HOME/.config/$APP_ID"          # the default agent and the installed version
LAUNCHER="$BIN_DIR/$APP_ID-launch"          # run by the app shortcuts
NOTIFIER="$BIN_DIR/$APP_ID-notify"          # run by the agents' hooks
SYSTEM_WRITES=true                          # false with --user: only the user's own folder is touched
LOG="" TMP_DIR="" SUDO_PID="" CURRENT="" CURRENT_STEP="" DCONF_BACKUP=""
WARNINGS=() REBOOT_REASONS=() NEXT_STEPS=()
CHANGED=false
# Every download: fails on HTTP errors, gives up on a connection that never answers or stalls
# (under 10 KB/s for a minute, as after a cut in the internet) instead of hanging the setup,
# and tries again three times
CURL=(curl -fsSL --connect-timeout 20 --speed-limit 10240 --speed-time 60 --retry 3 --retry-delay 5 --retry-connrefused)

# ---------------------------------------------------------------------------------------------
# Messages: on screen and in the log
# ---------------------------------------------------------------------------------------------
log()  { if [[ -n $LOG ]]; then printf '%s\n' "$*" >>"$LOG"; fi; }
step() { CURRENT_STEP=$*; printf '\n  %s→%s %s\n' "$C_ACCENT" "$C_RESET" "$*"; log ""; log "→ $*"; }
ok()   { printf '    %s✔%s %s\n' "$C_OK" "$C_RESET" "$*"; log "  ✔ $*"; }
info() { printf '    %s· %s%s\n' "$C_DIM" "$*" "$C_RESET"; log "  · $*"; }
warn() { printf '    %s! %s%s\n' "$C_WARN" "$*" "$C_RESET"; log "  ! $*"; WARNINGS+=("$*"); }
need_reboot() { REBOOT_REASONS+=("$*"); }

# After a put_* or edit_json: the first message when it changed something, the second otherwise.
report_changed() { if $CHANGED; then ok "$1"; else ok "${2:-Already up to date}"; fi; }

# True when $2 (several lines) contains the exact line $1. Used instead of "cmd | grep -q":
# with pipefail, grep -q leaving early makes cmd fail.
has_line() { [[ $'\n'"$2"$'\n' == *$'\n'"$1"$'\n'* ]]; }

# ---------------------------------------------------------------------------------------------
# Running commands: their output goes to the log, the screen shows one live line
# ---------------------------------------------------------------------------------------------
# Shows a spinner while process $1 runs, with the last line of the log, or with the size of
# file $2 when given (downloads).
watch_pid() {
    local pid=$1 file=${2:-} frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0 text
    ui_size
    while kill -0 "$pid" 2>/dev/null; do
        if [[ -n $file ]]; then
            text="$(($(stat -c %s "$file" 2>/dev/null || echo 0) / 1048576)) MB downloaded"
        else
            text=$(tail -c 600 "$LOG" 2>/dev/null | tr '\r' '\n' | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' | grep -v -e '^[[:space:]]*$' -e '^\$ ' | tail -n 1 || true)
            text=${text:-working…}
        fi
        printf '\r\e[K    %s%s%s %s%s%s' "$C_ACCENT" "${frames:i++ % ${#frames}:1}" "$C_RESET" "$C_DIM" "${text:0:$((UI_COLS - 8))}" "$C_RESET"
        sleep 0.1
    done
    printf '\r\e[K'
}

# run COMMAND...: runs it with its output in the log. Never wrap a function that sets variables
# (it runs in the background).
run() {
    local pid status=0
    log "\$ $*"
    if [[ ! -t 1 ]]; then
        "$@" >>"$LOG" 2>&1 </dev/null || status=$?
        return "$status"
    fi
    "$@" >>"$LOG" 2>&1 </dev/null &
    pid=$!
    watch_pid "$pid"
    wait "$pid" || status=$?
    return "$status"
}

# Downloads a file, showing how much has arrived: download URL DEST [resume]. With "resume", a
# DEST left by a cut download goes on from where it stopped instead of starting again.
download() {
    local pid status=0 args=("${CURL[@]}")
    log "\$ download $1"
    if [[ ${3:-} == resume ]]; then args+=(-C -); fi
    if [[ ! -t 1 ]]; then
        "${args[@]}" "$1" -o "$2" 2>>"$LOG" || status=$?
        return "$status"
    fi
    "${args[@]}" "$1" -o "$2" 2>>"$LOG" &
    pid=$!
    watch_pid "$pid" "$2"
    wait "$pid" || status=$?
    return "$status"
}

# ---------------------------------------------------------------------------------------------
# sudo: asked once, kept alive, never asked again in the middle of a command
# ---------------------------------------------------------------------------------------------
root() { sudo -n "$@"; }

sudo_start() {
    info "Your password is asked once; nothing is shown while you type it."
    # shellcheck disable=SC2024  # stdin from the terminal on purpose (password prompt)
    sudo -v </dev/tty || die "Administrator rights are needed to set this computer up."
    (
        trap - ERR; set +e
        while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 50; done
    ) 2>/dev/null &
    SUDO_PID=$!
    ok "Administrator rights granted"
}

# ---------------------------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------------------------
# Writes stdin to a system file only when its content changes and sets CHANGED.
# Feed it with <<< or < <(...), never with a pipe (a pipe runs it in a subshell).
put_file() {
    local dest=$1 mode=${2:-0644} tmp
    tmp=$(mktemp -p "$TMP_DIR")
    cat >"$tmp"
    CHANGED=false
    if ! $SYSTEM_WRITES; then return 0; fi          # --user: system files are someone else's job
    if [[ -r $dest ]]; then
        if cmp -s "$tmp" "$dest"; then return 0; fi
    elif [[ -e $dest ]] && root cmp -s "$tmp" "$dest"; then
        return 0
    fi
    sys "$dest" install -D -m "$mode" "$tmp" "$dest"
    CHANGED=true
}

# True when PATH can be written without sudo: the nearest folder that exists above it accepts
# writes (a prefix of the user's own, as in the tests).
writable() {
    local dir=$1
    while [[ ! -e $dir ]]; do dir=$(dirname "$dir"); done
    if [[ ! -d $dir ]]; then dir=$(dirname "$dir"); fi
    [[ -w $dir ]]
}

# sys TARGET COMMAND...: runs a command on system files, with sudo only when TARGET needs it.
sys() {
    local target=$1
    shift
    if writable "$target"; then "$@"; else root "$@"; fi
}

# Installs Kinobu itself for every user: a copy of this folder, the kinobu command and the
# login entry that sets up new users and brings the others up to date after an update.
install_system() {
    local src="$SYSTEM_DIR/src" autostart=/etc/xdg/autostart
    if ! $SYSTEM_WRITES; then return 0; fi
    if [[ $PREFIX != /usr/local ]]; then autostart="$PREFIX/etc/xdg/autostart"; fi
    if [[ $ROOT_DIR != "$src" ]]; then
        sys "$SYSTEM_DIR" mkdir -p "$SYSTEM_DIR"
        sys "$SYSTEM_DIR" rm -rf "$src.new"
        sys "$SYSTEM_DIR" mkdir -p "$src.new"
        sys "$SYSTEM_DIR" cp -r "$ROOT_DIR/kinobu.sh" "$ROOT_DIR/lib" "$ROOT_DIR/files" "$ROOT_DIR/LICENSE" "$src.new/"
        sys "$SYSTEM_DIR" chmod -R u=rwX,go=rX "$src.new"
        sys "$SYSTEM_DIR" rm -rf "$src"
        sys "$SYSTEM_DIR" mv "$src.new" "$src"
    fi
    put_file "$BIN_DIR/$APP_ID" 0755 <<<"#!/bin/sh"$'\n'"exec bash \"$src/kinobu.sh\" \"\$@\""
    put_file "$autostart/$APP_ID-user.desktop" < <(render apps/user-setup.desktop LAUNCHER)
    ok "$APP_NAME is installed for every user of this computer"
}

# Same for a file in $HOME (no sudo).
put_user_file() {
    local dest=$1 tmp
    tmp=$(mktemp -p "$TMP_DIR")
    cat >"$tmp"
    if cmp -s "$tmp" "$dest"; then
        CHANGED=false
    else
        mkdir -p "$(dirname "$dest")"
        cat "$tmp" >"$dest"
        CHANGED=true
    fi
}

# Adds or replaces a marked block in a user file; keeps a backup when it changes
put_block() {
    local file=$1 begin=$2 end=$3 content=$4 new="$TMP_DIR/block"
    mkdir -p "$(dirname "$file")"
    touch "$file"
    awk -v b="$begin" -v e="$end" '$0 == b {skip=1} !skip {print} $0 == e {skip=0}' "$file" >"$new"
    if [[ -s $new && -n $(tail -c1 "$new") ]]; then echo >>"$new"; fi
    printf '%s\n%s\n%s\n' "$begin" "$content" "$end" >>"$new"
    if cmp -s "$new" "$file"; then
        CHANGED=false
    else
        if [[ -s $file ]]; then cp "$file" "$file.$APP_ID.bak"; fi
        cat "$new" >"$file"
        CHANGED=true
    fi
}

# Writes a dconf key only when the value differs
dconf_set() {
    if [[ "$(dconf read "$1")" != "$2" ]]; then dconf write "$1" "$2"; fi
}

# True when an app's launcher (.desktop) is present: APT, snap or the user's own
has_app() {
    local dir
    for dir in /usr/share/applications "$PREFIX/share/applications" /var/lib/snapd/desktop/applications "$HOME/.local/share/applications"; do
        if [[ -f $dir/$1 ]]; then return 0; fi
    done
    return 1
}

# Items of a GVariant string array, one per line: ['a', 'b'] -> a, b
from_gvariant() { grep -o "'[^']*'" <<<"$1" | tr -d "'" || true; }

# GVariant string array from arguments: ['a', 'b']
to_gvariant() {
    local out="" item
    for item in "$@"; do out+="'$item', "; done
    echo "[${out%, }]"
}

# Downloads an APT signing key (dearmored unless the destination ends in .asc).
put_key() {
    local url=$1 dest=$2
    "${CURL[@]}" "$url" -o "$TMP_DIR/key" 2>>"$LOG" || return 1
    if [[ $dest == *.asc ]]; then
        put_file "$dest" <"$TMP_DIR/key"
    else
        gpg --dearmor <"$TMP_DIR/key" >"$TMP_DIR/key.gpg" 2>>"$LOG" || return 1
        put_file "$dest" <"$TMP_DIR/key.gpg"
    fi
}

# Applies a jq filter to a user JSON file (created if missing); writes and backs it up only when
# the content changes and sets CHANGED. Extra arguments go to jq (--arg, --argjson...).
edit_json() {
    local file=$1 filter=$2 src new="$TMP_DIR/edit.json"
    shift 2
    CHANGED=false
    if [[ -s $file ]] && ! jq -e . "$file" >/dev/null 2>&1; then
        warn "${file/#$HOME/\~} is not plain JSON (comments?): left untouched"
        return 0
    fi
    src=$file
    if [[ ! -s $file ]]; then src="$TMP_DIR/empty.json"; echo '{}' >"$src"; fi
    jq "$@" "$filter" "$src" >"$new"
    if [[ -s $file ]] && cmp -s <(jq -S . "$file") <(jq -S . "$new"); then return 0; fi
    mkdir -p "$(dirname "$file")"
    if [[ -s $file ]]; then cp "$file" "$file.$APP_ID.bak"; fi
    cat "$new" >"$file"
    CHANGED=true
}

# Prints a file from files/ with its @MARKS@ filled in. Each argument is a variable NAME (its
# value fills @NAME@) or NAME=value.
render() {
    local file=$1 text arg
    text=$(<"$ROOT_DIR/files/$file")
    shift
    for arg in "$@"; do
        if [[ $arg == *=* ]]; then
            text=${text//"@${arg%%=*}@"/"${arg#*=}"}
        else
            if [[ ! -v $arg ]]; then echo "render $file: $arg is not set" >&2; fi
            text=${text//"@$arg@"/"${!arg-}"}
        fi
    done
    printf '%s\n' "$text"
}

# ---------------------------------------------------------------------------------------------
# apt
# ---------------------------------------------------------------------------------------------
APT_LOCKS=(/var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock /var/cache/apt/archives/lock)

# PID of the process holding an apt or dpkg lock, empty if none (read from /proc/locks: no sudo).
apt_lock_holder() {
    local file inode pid
    for file in "${APT_LOCKS[@]}"; do
        inode=$(stat -c %i "$file" 2>/dev/null) || continue
        pid=$(awk -v i="$inode" '$2 != "->" { split($6, f, ":"); if (f[3] == i) { print $5; exit } }' \
            /proc/locks 2>/dev/null)
        if [[ -n $pid ]]; then echo "$pid"; return 0; fi
    done
}

# Waits calmly while another program (usually Ubuntu's automatic updates) is using apt.
wait_for_apt() {
    local pid name what waited=0 limit=3600
    pid=$(apt_lock_holder)
    if [[ -z $pid ]]; then return 0; fi
    name=$(ps -o comm= -p "$pid" 2>/dev/null) || true
    case $name in
        unattended-upgr* | apt.systemd.dai*) what="Ubuntu is installing its automatic updates in the background" ;;
        packagekitd) what="The Software app is installing or updating something" ;;
        *) what="Another program (${name:-PID $pid}) is installing software" ;;
    esac
    info "$what."
    info "Nothing is wrong: $APP_NAME waits for it and goes on by itself (a slow connection makes it longer)."
    while pid=$(apt_lock_holder); [[ -n $pid ]]; do
        if ((waited >= limit)); then die "The system is still busy after $((limit / 60)) minutes (${name:-PID $pid}): try again later."; fi
        sleep 5
        waited=$((waited + 5))
        if ((waited % 300 == 0)); then info "Still waiting ($((waited / 60)) min)…"; fi
    done
    ok "The system is free, going on"
}

# Non-interactive apt-get: waits for other apt users and keeps modified config files.
apt_get() {
    wait_for_apt
    run sudo -n env DEBIAN_FRONTEND=noninteractive apt-get -y -q \
        -o DPkg::Lock::Timeout=600 \
        -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@"
}

is_installed() { [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" == installed ]]; }

has_candidate() {
    local policy
    policy=$(LC_ALL=C apt-cache policy "$1" 2>/dev/null)
    [[ $policy == *"Candidate:"* && $policy != *"Candidate: (none)"* ]]
}

# Installs only what is missing; packages the repositories do not have are reported, not fatal.
apt_install() {
    local pkg missing=() unavailable=()
    for pkg in "$@"; do
        if is_installed "$pkg"; then continue; fi
        if has_candidate "$pkg"; then missing+=("$pkg"); else unavailable+=("$pkg"); fi
    done
    if ((${#unavailable[@]})); then warn "Not available in the repositories: ${unavailable[*]}"; fi
    if ((${#missing[@]})); then
        apt_get install "${missing[@]}"
        ok "Installed: ${missing[*]}"
    else
        ok "All $# packages already installed"
    fi
}

# Installs a vendor .deb from a URL (apt resolves its dependencies): install_deb URL NAME
install_deb() {
    download "$1" "$TMP_DIR/$2.deb"
    apt_get install "$TMP_DIR/$2.deb"
}

# ---------------------------------------------------------------------------------------------
# The run: one block after another
# ---------------------------------------------------------------------------------------------
# Saves every GNOME setting before anything changes; keeps the last 10.
backup_settings() {
    local backups
    if ! command -v dconf >/dev/null; then return 0; fi
    DCONF_BACKUP="$STATE_DIR/dconf-$RUN_ID.ini"
    dconf dump / >"$DCONF_BACKUP" 2>/dev/null || true
    ok "Your GNOME settings were saved first"
    backups=("$STATE_DIR"/dconf-*.ini)
    if ((${#backups[@]} > 10)); then rm -f "${backups[@]:0:${#backups[@]}-10}"; fi
}

# The small tools the blocks themselves need.
bootstrap() {
    local pkg missing=()
    for pkg in curl ca-certificates gnupg jq; do
        if ! is_installed "$pkg"; then missing+=("$pkg"); fi
    done
    if ((${#missing[@]})); then
        apt_get update
        apt_get install "${missing[@]}"
        ok "Installed the tools $APP_NAME needs: ${missing[*]}"
    fi
}

# Progress dots, the block's title and what it does.
block_header() {   # block_header INDEX TOTAL BLOCK
    local i dots=""
    for ((i = 1; i <= $2; i++)); do
        if ((i <= $1)); then dots+="${C_ACCENT}●${C_RESET} "; else dots+="${C_DIM}○${C_RESET} "; fi
    done
    printf '\n\n  %s  %s%s%s%s\n  %s%s%s\n' "$dots" "$C_BOLD" "$C_ACCENT" "${BLOCK_TITLE[$3]}" "$C_RESET" "$C_DIM" "$(block_desc "$3")" "$C_RESET"
    log ""; log "━━ $1/$2 ${BLOCK_TITLE[$3]} ━━"
}

# Runs the blocks of PLAN in order, with the software in CHOSEN.
run_plan() {
    local block fn i=0 previous
    mkdir -p "$STATE_DIR"
    RUN_ID=$(date +%Y%m%d-%H%M%S)
    LOG="$STATE_DIR/$RUN_ID.log"
    TMP_DIR=$(mktemp -d)
    log "$APP_NAME $APP_VERSION · $(date) · blocks: ${PLAN[*]} · software: ${CHOSEN[*]:-none}"
    # Never go back: an older copy would undo what newer versions fixed
    previous=$(cat "$CONFIG_DIR/version" 2>/dev/null || true)
    if [[ -n $previous ]] && dpkg --compare-versions "$APP_VERSION" lt "$previous" 2>/dev/null; then
        die "This copy of $APP_NAME is $APP_VERSION, but this computer has $previous: get the latest one (git pull) and run it again."
    fi
    CURRENT=start
    step "Getting ready"
    if $SYSTEM_WRITES; then sudo_start; fi
    backup_settings
    if $SYSTEM_WRITES; then
        bootstrap
        install_system
    fi
    for block in "${PLAN[@]}"; do
        i=$((i + 1))
        CURRENT=$block CURRENT_STEP=""
        block_header "$i" "${#PLAN[@]}" "$block"
        fn=$(block_fn "$block")
        if [[ -z $fn ]]; then
            echo; info "This part is not written yet: skipped"
            continue
        fi
        "$fn"
    done
    finish_run
    CURRENT="" CURRENT_STEP=""
    print_summary
}

# What closes a run: the app grid (last, so nothing installed afterwards moves it), the welcome
# tour after the first full setup, the installed version and the next steps for the user.
finish_run() {
    local first=false
    if [[ ! -f $CONFIG_DIR/version ]]; then first=true; fi
    if [[ $RUN_KIND == setup ]] && planned desktop; then
        CURRENT=desktop
        arrange_app_grid
    fi
    if [[ $ACTION != manual && $RUN_KIND == setup ]] && $first && planned shortcuts; then show_welcome; fi
    # The version on the system, and the one this user is up to date with (compared at login)
    if [[ $ACTION != manual ]]; then
        put_file "$SYSTEM_DIR/version" <<<"$APP_VERSION"
        mkdir -p "$CONFIG_DIR"
        printf '%s\n' "$APP_VERSION" >"$CONFIG_DIR/version"
    fi
    if [[ $ACTION != manual && $RUN_KIND == setup ]]; then
        NEXT_STEPS+=("Connect your Google or Microsoft account in Settings > Online Accounts (mail, contacts, calendar)")
        NEXT_STEPS+=("Handy: open it and download a model (Parakeet Ultra is recommended); the voice assistant listens through it")
    fi
    if planned shortcuts; then NEXT_STEPS+=("Press Super+K to see every keyboard shortcut"); fi
    case ${WELCOME:-} in
        now) NEXT_STEPS+=("The welcome tour is open: a quick look at $APP_NAME (also in the app grid)") ;;
        login) NEXT_STEPS+=("A short welcome tour opens at your next login (also in the app grid)") ;;
    esac
}

print_summary() {
    local text
    printf '\n\n  %s%s✔ Done%s\n' "$C_OK" "$C_BOLD" "$C_RESET"
    if ((${#WARNINGS[@]})); then
        ui_section "To look at"
        for text in "${WARNINGS[@]}"; do printf '    %s!%s %s\n' "$C_WARN" "$C_RESET" "$text"; done
    fi
    if ((${#REBOOT_REASONS[@]})); then
        ui_section "Restart the computer to finish"
        for text in "${REBOOT_REASONS[@]}"; do printf '    · %s\n' "$text"; done
    fi
    if ((${#NEXT_STEPS[@]})); then
        ui_section "Next steps"
        for text in "${NEXT_STEPS[@]}"; do printf '    · %s\n' "$text"; done
    fi
    echo
    if [[ -n $DCONF_BACKUP ]]; then ui_note "Your GNOME settings before this run: ${DCONF_BACKUP/#$HOME/\~}"; fi
    ui_note "Everything that was done is in ${LOG/#$HOME/\~}"
    echo
}
