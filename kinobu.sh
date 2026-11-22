#!/usr/bin/env bash
# =============================================================================
#
#   Kinobu — the agentic Ubuntu desktop
#
#   Version : 0.3.2 (in development)
#   Author  : Alberto Gálvez (agalvezsh)
#   License : AGPL-3.0-or-later (see LICENSE)
#
#   Turns a fresh Ubuntu 26.04 LTS desktop (GNOME on Wayland) into a ready-to-use
#   workstation for working with AI. Run it from its folder, as your normal user:
#
#     bash kinobu.sh --install     set this computer up
#     bash kinobu.sh --update      update a computer already set up
#     bash kinobu.sh --manual      choose which blocks to run
#     bash kinobu.sh --check       only check this computer
#     kinobu --user                set Kinobu up for another user of a computer already set up
#
#   The code lives in lib/ (one file per part) and what it installs in files/.
#
# =============================================================================
set -Eeuo pipefail

# =============================================================================
# Configuration — edit here
# =============================================================================
APP_NAME="Kinobu"
APP_ID="kinobu"
APP_VERSION="0.3.2"
SUPPORTED_UBUNTU="26.04"
MIN_FREE_GB=25                              # free space the full setup needs on /
DISCRETE_GPU='NVIDIA|Radeon (RX|Pro)|Arc'   # lspci names of dedicated graphics cards
PREFIX="${KINOBU_PREFIX:-/usr/local}"       # where Kinobu installs itself for every user
SYSTEM_DIR="$PREFIX/share/$APP_ID"          # what every user shares: programs/, skills/, i18n/, data/, src/
PROGRAMS_DIR="$SYSTEM_DIR/programs"         # Kinobu's own apps (Trail, Sprout, Gate, Willow, Seasons)
BIN_DIR="$PREFIX/bin"                       # its commands: kinobu, kinobu-launch, kinobu-notify, kinobu-theme
DATA_DIR="$HOME/.local/share/$APP_ID"       # each user's own data (the voice assistant's voices)

# =============================================================================
# Parts
# =============================================================================
ROOT_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
if [[ ! -d $ROOT_DIR/lib || ! -d $ROOT_DIR/files ]]; then
    echo "✖ lib/ and files/ must be next to kinobu.sh: get the whole folder (git clone)." >&2
    exit 1
fi
# shellcheck source=lib/ui.sh
source "$ROOT_DIR/lib/ui.sh"
# shellcheck source=lib/blocks.sh
source "$ROOT_DIR/lib/blocks.sh"
# shellcheck source=lib/check.sh
source "$ROOT_DIR/lib/check.sh"
# shellcheck source=lib/software.sh
source "$ROOT_DIR/lib/software.sh"
# shellcheck source=lib/core.sh
source "$ROOT_DIR/lib/core.sh"
# shellcheck source=lib/apps.sh
source "$ROOT_DIR/lib/apps.sh"
# shellcheck source=lib/ai.sh
source "$ROOT_DIR/lib/ai.sh"
# shellcheck source=lib/drivers.sh
source "$ROOT_DIR/lib/drivers.sh"
# shellcheck source=lib/services.sh
source "$ROOT_DIR/lib/services.sh"
# shellcheck source=lib/user.sh
source "$ROOT_DIR/lib/user.sh"
# shellcheck source=lib/desktop.sh
source "$ROOT_DIR/lib/desktop.sh"
# shellcheck source=lib/look.sh
source "$ROOT_DIR/lib/look.sh"
# shellcheck source=lib/shortcuts.sh
source "$ROOT_DIR/lib/shortcuts.sh"
# shellcheck source=lib/context.sh
source "$ROOT_DIR/lib/context.sh"
# shellcheck source=lib/update.sh
source "$ROOT_DIR/lib/update.sh"

# =============================================================================
# Orchestration
# =============================================================================
usage() {
    cat <<HELP

  ${C_BOLD}${C_ACCENT}$APP_NAME${C_RESET} v$APP_VERSION — the agentic Ubuntu desktop

  ${C_BOLD}Usage${C_RESET}
    bash kinobu.sh <option>

  ${C_BOLD}Options${C_RESET}
    -i, --install    Set this computer up: check it, choose your software, install
    -u, --update     Update a computer already set up (your look is kept)
    -m, --manual     Choose which blocks to run
        --user       Set $APP_NAME up for your user on a computer that already has it
                     (no password needed; it also runs by itself at your first login)
    -c, --check      Only check this computer; nothing is changed
    -v, --version    Show the version
    -h, --help       Show this help

  Run it as your normal user (not with sudo), from a terminal in the GNOME desktop.

HELP
}

# Leaves the full-screen list, stops the sudo keep-alive and removes the temporary files.
cleanup() {
    if ${UI_FULLSCREEN:-false}; then printf '\e[?25h\e[?1049l'; fi
    if [[ -n $SUDO_PID ]]; then kill "$SUDO_PID" 2>/dev/null || true; fi
    if [[ -n $TMP_DIR ]]; then rm -rf "$TMP_DIR"; fi
}

# Says in plain words where it failed, shows the last lines of the log and how to go on.
on_error() {
    local line
    if ((BASH_SUBSHELL > 0)); then return 0; fi
    printf '\r\e[K\n  %s%s✖ Something failed%s' "$C_ERR" "$C_BOLD" "$C_RESET" >&2
    if [[ -n $CURRENT && -n ${BLOCK_TITLE[$CURRENT]:-} ]]; then printf ' in %s%s%s' "$C_BOLD" "${BLOCK_TITLE[$CURRENT]}" "$C_RESET" >&2; fi
    if [[ -n $CURRENT_STEP ]]; then printf ' (%s)' "$CURRENT_STEP" >&2; fi
    printf '\n' >&2
    if [[ -n $LOG && -s $LOG ]]; then
        while IFS= read -r line; do printf '    %s%s%s\n' "$C_DIM" "${line:0:160}" "$C_RESET" >&2; done < <(tail -n 12 "$LOG")
        printf '\n  The whole log: %s\n' "${LOG/#$HOME/\~}" >&2
        printf '  To try again: bash kinobu.sh --install (it only redoes what is missing)\n' >&2
        if [[ $CURRENT == apps ]]; then
            printf '  If the system upgrade stopped halfway, run first: sudo dpkg --configure -a && sudo apt -f install\n' >&2
        fi
    else
        printf '  (line %s of %s)\n' "$1" "${BASH_SOURCE[1]##*/}" >&2
    fi
    printf '\n' >&2
}

# One option decides what to do; with none, the help is shown.
parse_args() {
    ACTION=""
    local arg new
    for arg in "$@"; do
        case $arg in
            -i|--install) new=install ;;
            -u|--update)  new=update ;;
            -m|--manual)  new=manual ;;
            --user)       new=user ;;
            -c|--check)   new=check ;;
            -v|--version) new=version ;;
            -h|--help)    new=help ;;
            *) die "Unknown option: $arg (see bash kinobu.sh --help)" ;;
        esac
        if [[ -n $ACTION && $ACTION != "$new" ]]; then die "Choose only one option (see bash kinobu.sh --help)"; fi
        ACTION=$new
    done
    ACTION=${ACTION:-help}
}

cancelled() { ui_note "Cancelled: nothing was changed."; echo; }

# Waits for Enter before the menus take the screen, so the check can be read. Returns 1 on Q.
wait_enter() {
    local key
    if ! has_tty; then return 0; fi
    printf '  %s%s%s ' "$C_BOLD" "$1" "$C_RESET"
    while true; do
        IFS= read -rsn1 key </dev/tty || key=q
        case $key in
            '') echo; echo; return 0 ;;
            q|Q) echo; echo; return 1 ;;
        esac
    done
}

# The last question before anything changes: what is going to happen, in order.
# Returns 1 if the user quits.
confirm_start() {
    local block i=0
    if ! has_tty; then die "The setup needs a terminal to ask for your confirmation and your password."; fi
    ui_section "What $APP_NAME will do now"
    for block in "${PLAN[@]}"; do
        i=$((i + 1))
        if [[ -n $(block_fn "$block") ]]; then
            printf '   %s%2d%s %-22s %s%s%s\n' "$C_ACCENT" "$i" "$C_RESET" "${BLOCK_TITLE[$block]}" "$C_DIM" "$(block_desc "$block")" "$C_RESET"
        else
            printf '   %s%2d %-22s not written yet: skipped%s\n' "$C_DIM" "$i" "${BLOCK_TITLE[$block]}" "$C_RESET"
        fi
    done
    echo
    if [[ $ACTION == user && $RUN_KIND == update ]]; then
        ui_note "This brings your user up to date with $APP_NAME $APP_VERSION. Your look is kept as it is."
    elif [[ $ACTION == user ]]; then
        ui_note "This gives your user the desktop, the shortcuts and the AI agents of $APP_NAME."
    elif [[ $ACTION == update ]]; then
        ui_note "This updates Ubuntu, your apps, your agents and $APP_NAME itself. Your look is kept as it is."
    else
        ui_note "This changes the computer: it updates Ubuntu, installs your software and sets it up."
    fi
    if $SYSTEM_WRITES; then
        ui_note "It asks for your password once. You can run it again at any time: it only does what is missing."
    else
        ui_note "Only your user is set up: nothing else on the computer changes and no password is asked."
    fi
    echo
    wait_enter "Do you want to continue? Press Enter to start, or Q to quit."
}

# Asks for the software the planned blocks need and prints the choice. Returns 1 if cancelled.
ask_software() {
    if ! planned apps && ! planned ai; then return 0; fi
    if ! choose_software; then return 1; fi
    software_summary
}

main() {
    local -a items=()
    PLAN=() CHOSEN=() WELCOME="" RUN_KIND=setup
    ui_init
    parse_args "$@"
    case $ACTION in
        help)    usage; return 0 ;;
        version) echo "$APP_NAME $APP_VERSION"; return 0 ;;
    esac

    ui_banner
    if ! check_system; then exit 1; fi

    case $ACTION in
        check) ;;
        install)
            PLAN=("${BLOCKS[@]}")
            if ! wait_enter "Press Enter to choose your software, or Q to quit."; then cancelled; return 0; fi
            if ! ask_software; then cancelled; return 0; fi
            if ! confirm_start; then cancelled; return 0; fi
            run_plan ;;
        update)
            if [[ ! -f $SYSTEM_DIR/version ]]; then
                die "This computer was not set up with $APP_NAME yet: run bash kinobu.sh --install"
            fi
            RUN_KIND=update
            PLAN=("${UPDATE_BLOCKS[@]}")
            ui_note "Updating $APP_NAME $(cat "$CONFIG_DIR/version" 2>/dev/null || echo "(an earlier version)") to $APP_VERSION."
            if ! confirm_start; then cancelled; return 0; fi
            run_plan ;;
        user)
            # Another user of a computer already set up: only what lives in their own folder
            SYSTEM_WRITES=false
            if [[ -f $CONFIG_DIR/version ]]; then
                RUN_KIND=update
                PLAN=(user desktop shortcuts context)
            else
                PLAN=(ai user desktop shortcuts context)
                if ! wait_enter "Press Enter to choose your AI agents, or Q to quit."; then cancelled; return 0; fi
                if ! ask_software; then cancelled; return 0; fi
            fi
            if ! confirm_start; then cancelled; return 0; fi
            run_plan ;;
        manual)
            if ! has_tty; then die "--manual needs a terminal to choose the blocks"; fi
            if ! wait_enter "Press Enter to choose the blocks to run, or Q to quit."; then cancelled; return 0; fi
            mapfile -t items < <(block_items)
            if ! ui_checklist "Blocks to run" "Each block is one part of the setup. Untick the ones you want to skip." "" "${items[@]}"; then
                cancelled; return 0
            fi
            if ((${#UI_PICKED[@]} == 0)); then
                ui_note "No block chosen: nothing to do."; echo
                return 0
            fi
            PLAN=("${UI_PICKED[@]}")
            if ! ask_software; then cancelled; return 0; fi
            if ! confirm_start; then cancelled; return 0; fi
            run_plan ;;
    esac
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    trap 'on_error $LINENO' ERR
    trap cleanup EXIT
    main "$@"
fi
