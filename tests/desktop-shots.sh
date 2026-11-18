#!/bin/bash
# Screenshots of a real GNOME desktop that is not yours: a headless GNOME Shell with a fake home,
# to look at themes and apps without touching the real settings.
#
# Usage: bash tests/desktop-shots.sh SCENE OUT_DIR
#   SCENE is a bash file sourced inside the session. It can use:
#     start COMMAND...   start an app (closed by its own PID, never by name)
#     stop               close every app started so far
#     shot NAME          save OUT_DIR/NAME.png
#     $KINOBU            the repository; the session's HOME is a fresh temporary folder
#
# Why it is safe: the fake home is set BEFORE dbus-run-session, so the bus and every service it
# starts (dconf-service among them) use it. With a private bus alone, dconf-service inherits the
# real home and writes the real settings. The real database is compared before and after.
set -u

if [[ ${1:-} == --inside ]]; then
    shift
    scene=$1 out=$2
    gsettings set org.gnome.desktop.notifications show-banners false
    gsettings set org.gnome.shell welcome-dialog-last-shown-version '999'
    gnome-shell --headless --wayland --no-x11 --virtual-monitor 1440x900 --wayland-display=kinobu-shots \
        >"$out/shell.log" 2>&1 &
    shell=$!
    for _ in $(seq 1 40); do
        gdbus introspect --session --dest org.gnome.Shell --object-path /org/gnome/Shell >/dev/null 2>&1 && break
        sleep 0.5
    done
    sleep 2
    gnome-extensions enable shots@kinobu.test   # unsafe mode: the screenshot call needs it
    sleep 1
    export WAYLAND_DISPLAY=kinobu-shots
    pids=()
    # shellcheck disable=SC2329  # used by the scene
    start() { "$@" >>"$out/apps.log" 2>&1 & pids+=($!); }
    stop() {   # a bare `wait` would wait for the shell itself: only the apps started here
        if ((${#pids[@]})); then kill "${pids[@]}" 2>/dev/null; wait "${pids[@]}" 2>/dev/null; fi
        pids=()
        sleep 1
    }
    # shellcheck disable=SC2329  # used by the scene
    shot() {
        gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
            --method org.gnome.Shell.Eval "Main.overview.hide()" >/dev/null
        sleep 1
        gdbus call --session --dest org.gnome.Shell.Screenshot --object-path /org/gnome/Shell/Screenshot \
            --method org.gnome.Shell.Screenshot.Screenshot false false "$out/$1.png" >/dev/null
    }
    # shellcheck disable=SC1090  # the scene is the caller's
    . "$scene"
    stop
    kill "$shell"
    wait "$shell" 2>/dev/null
    exit 0
fi

scene=$(realpath "${1:?Usage: desktop-shots.sh SCENE OUT_DIR}")
out=$(realpath -m "${2:?Usage: desktop-shots.sh SCENE OUT_DIR}")
KINOBU=$(realpath "$(dirname "$0")/..")
mkdir -p "$out"
fake=$(mktemp -d) run=$(mktemp -d)   # the runtime folder apart, or Files lists it in the home
ext="$fake/.local/share/gnome-shell/extensions/shots@kinobu.test"
mkdir -p "$ext"
# Ptyxis starts each shell in a scope of the user's service manager: only that is shared
ln -s "$XDG_RUNTIME_DIR/systemd" "$run/systemd"
cat >"$ext/metadata.json" <<'EOF'
{"uuid": "shots@kinobu.test", "name": "Screenshots (Kinobu tests)", "description": "Test sessions only", "shell-version": ["50"]}
EOF
cat >"$ext/extension.js" <<'EOF'
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
export default class Shots extends Extension {
    enable() { Main.messageTray.bannerBlocked = true; global.context.unsafe_mode = true; }
    disable() {}
}
EOF

before=$(mktemp)
dconf dump / >"$before"
env -i PATH="$PATH" LANG="${LANG:-C.UTF-8}" KINOBU="$KINOBU" HOME="$fake" \
    XDG_CONFIG_HOME="$fake/.config" XDG_DATA_HOME="$fake/.local/share" XDG_CACHE_HOME="$fake/.cache" \
    XDG_STATE_HOME="$fake/.local/state" XDG_RUNTIME_DIR="$run" XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=ubuntu:GNOME \
    timeout 600 dbus-run-session -- bash "$0" --inside "$scene" "$out" >/dev/null 2>&1
# Services the session started may outlive its bus (gvfs, wsdd): stop the ones with the fake
# home, found by their environment, never by name
for env in /proc/[0-9]*/environ; do
    if { tr '\0' '\n' <"$env"; } 2>/dev/null | grep -qx "HOME=$fake"; then
        pid=${env#/proc/}
        kill "${pid%/environ}" 2>/dev/null || true
    fi
done
# The document portal mounts a folder in the fake runtime folder: unmount it first
fusermount3 -uz "$run/doc" 2>/dev/null || true
sleep 1
rm -rf "$fake" "$run" 2>/dev/null || true
# Your own desktop may change a setting meanwhile (a window size, the weather): the changes are
# listed, so a test that leaked can be told apart from your own use
changes=$(diff <(cat "$before") <(dconf dump /) | grep '^[<>]' || true)
rm -f "$before"
if [[ -n $changes ]]; then
    echo "!!! The real settings changed during the session (yours, or a leak):" >&2
    echo "$changes" >&2
fi
ls "$out"/*.png 2>/dev/null
