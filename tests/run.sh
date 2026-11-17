#!/usr/bin/env bash
# Kinobu's tests: syntax, lint, the command line and the block picker. Nothing touches the system.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")/.." || exit 1
fails=0
check() { if "${@:2}"; then echo "  ✔ $1"; else echo "  ✖ $1"; fails=$((fails + 1)); fi; }
has()   { [[ $1 == *"$2"* ]]; }
lacks() { [[ -n $1 && $1 != *"$2"* ]]; }

echo "Syntax and lint"
check "bash -n" bash -n kinobu.sh lib/*.sh tests/run.sh
if command -v shellcheck >/dev/null; then
    check "shellcheck" shellcheck -x -S style kinobu.sh lib/*.sh tests/run.sh
elif command -v uvx >/dev/null; then
    check "shellcheck (uvx)" uvx --quiet --from shellcheck-py shellcheck -x -S style kinobu.sh lib/*.sh tests/run.sh
else
    echo "  · shellcheck not available, skipped"
fi

check "installed Python files compile" python3 -m py_compile files/apps/*.py files/agents/*.py tools/*.py
check "installed scripts parse" bash -n files/apps/kinobu-launch files/agents/kinobu-notify files/shell/bashrc.sh
# shellcheck disable=SC2016  # the checks below run their own shell
check "translations are valid JSON" bash -c 'for f in files/i18n/*.json; do jq -e . "$f" >/dev/null || exit 1; done'
check "nothing still says Orkestr" bash -c '! grep -rIqi orkestr kinobu.sh lib files tools'
check "no removed agent left" bash -c '! grep -rIqiE "opencode|hermes|cursor-agent" kinobu.sh lib files/skill files/agents files/subagents files/apps'

if [[ -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; then
    check "approval window: no button starts with the keyboard focus" has "$(timeout 20 python3 tests/approve-focus.py files/apps/approve.py 2>/dev/null)" "focus: NoneType"
fi

echo "Command line"
out=$(bash kinobu.sh 2>&1);            check "no option shows the help"   has "$out" "Usage"
out=$(bash kinobu.sh --help 2>&1);     check "--help"                     has "$out" "--install"
out=$(bash kinobu.sh -v 2>&1);         check "--version"                  has "$out" "Kinobu 0."
out=$(bash kinobu.sh --nope 2>&1);     check "unknown option is refused"  has "$out" "Unknown option"
out=$(bash kinobu.sh -i -u 2>&1);      check "two modes are refused"      has "$out" "only one option"

echo "System check"
out=$(bash kinobu.sh --check 2>&1);    check "prints the requirements"    has "$out" "Administrator rights"
out=$(XDG_CURRENT_DESKTOP=none bash kinobu.sh --install 2>&1); code=$?
check "a missing requirement stops the setup" test "$code" -eq 1
check "and says what to do" has "$out" "Open a terminal inside the GNOME desktop"
out=$(HOME=$(mktemp -d) bash kinobu.sh --update 2>&1)
check "--update refuses a computer not set up" has "$out" "was not set up"

ENTER=$'\r' DOWN=$'\x1b[B'
run() { python3 tests/pty-run.py "$@"; }             # keys... -- command
after() { sed -n "/$1/,\$p" <<<"$2"; }                # the output from a line on

echo "Software menus (--install in a pty)"
out=$(run "@Press Enter" "$ENTER" "@Applications" "$ENTER" "@Development" "$ENTER" "@AI agents" "$ENTER" "@Extra tools" "$ENTER" "@Press Enter to start," q -- bash kinobu.sh --install)
plan=$(after "Your software" "$out")
check "the preselected software is taken"   has "$plan" "Google Chrome, Mission Center"
check "only Claude Code is preselected"     has "$plan" "Claude Code"
check "the removed agents are not offered"  lacks "$out" "Antigravity CLI"
check "nothing extra is preselected"        has "$plan" "nothing selected"
check "no shell errors on screen"           lacks "$out" "kinobu/lib/"
check "no shell errors (any path)"          lacks "${out,,}" "/lib/software.sh"
check "removed software is not offered"     lacks "$out" "Hermes"
out=$(run "@Press Enter" "$ENTER" "@Applications" " " "$ENTER" "@Development" "$ENTER" "@AI agents" "$ENTER" "@Extra tools" "$ENTER" "@Press Enter to start," q -- bash kinobu.sh --install)
check "Space ticks an app"                  has "$(after "Your software" "$out")" "Helium, Google Chrome"
out=$(run "@Press Enter" "$ENTER" "@Applications" " " "$ENTER" "@Development" b "@Applications" "$ENTER" "@Development" "$ENTER" "@AI agents" "$ENTER" "@Extra tools" "$ENTER" "@Press Enter to start," q -- bash kinobu.sh --install)
check "B goes back and keeps the ticks"     has "$(after "Your software" "$out")" "Helium, Google Chrome"
out=$(run "@Press Enter" "$ENTER" "@Applications" "$ENTER" "@Development" q -- bash kinobu.sh --install)
check "Q quits the menus"                   has "$out" "Cancelled"
out=$(run "@Press Enter" q -- bash kinobu.sh --install)
check "Q quits before the menus"            has "$out" "Cancelled"

echo "Block picker (--manual in a pty)"
out=$(run "@Press Enter" "$ENTER" "@Blocks to run" "$DOWN" " " "$DOWN" " " "$ENTER" "@Press Enter to start," q -- bash kinobu.sh --manual)
plan=${out##*1049l}                                   # what is printed after the last menu
check "unticked blocks are left out"        lacks "$plan" "Applications"
check "ticked blocks are kept"              has "$plan" "Agent context"
check "no menus without apps and ai"        lacks "$plan" "Your software"
out=$(run "@Press Enter" "$ENTER" "@Blocks to run" a " " "$ENTER" "@Press Enter to start," q -- bash kinobu.sh --manual)
check "only the first block is planned"     lacks "${out##*1049l}" "Drivers"
out=$(run "@Press Enter" "$ENTER" "@Blocks to run" a "$DOWN" "$DOWN" " " "$ENTER" "@AI agents" "$ENTER" "@Extra tools" "$ENTER" "@Press Enter to start," q -- bash kinobu.sh --manual)
check "only ai: the agent and local AI menus" has "$(after "Your software" "$out")" "Claude Code"
out=$(run "@Press Enter" "$ENTER" "@Blocks to run" q -- bash kinobu.sh --manual)
check "Q cancels"                           has "$out" "Cancelled"

echo "The setup itself (stubbed: sudo, curl and friends run nothing)"
stubs=$PWD/tests/stubs
if [[ $(PATH=$stubs:$PATH command -v sudo) != "$stubs/sudo" ]]; then
    echo "  ✖ the sudo stub is not first in PATH: setup tests skipped"; fails=$((fails + 1))
else
    home=$(mktemp -d) record=$(mktemp) profile=$(mktemp) prefix=$(mktemp -d)
    echo "user-db:kinobutest" >"$profile"      # its own dconf database: the real settings stay out of it
    real_config=$HOME/.config
    rm -f "$real_config/dconf/kinobutest"
    setup() { HOME=$home KINOBU_PREFIX=$prefix XDG_CONFIG_HOME=$real_config DCONF_PROFILE=$profile PATH=$stubs:$PATH KINOBU_TEST_SUDO=$record run "@Press Enter to choose" "$ENTER" "@Applications" "$ENTER" "@Development" "$ENTER" "@AI agents" "$ENTER" "@Extra tools" "$ENTER" "@Press Enter to start," "$ENTER" -- bash kinobu.sh --install; }
    out=$(setup); done_cmds=$(<"$record")
    check "runs to the end"                     has "$out" "✔ Done"
    check "upgrades Ubuntu"                     has "$done_cmds" "full-upgrade"
    check "turns on the optimised packages"     has "$out" "Faster packages for this processor"
    check "adds the source of a chosen app"     has "$out" "Visual Studio Code"
    check "adds no source nobody chose"         lacks "$done_cmds" "docker"
    check "writes a log"                        test -n "$(ls "$home/.local/state/kinobu/"*.log 2>/dev/null)"
    check "no shell errors on screen"           lacks "$out" "/lib/"
    : >"$record"
    out=$(KINOBU_TEST_FAIL=full-upgrade setup)
    check "a failure stops the setup"           lacks "$out" "✔ Done"
    check "and says where and how to go on"     has "$out" "Something failed"
    check "with the way to try again"           has "$out" "To try again"
    : >"$record"
    out=$(HOME=$home KINOBU_PREFIX=$prefix PATH=$stubs:$PATH KINOBU_TEST_SUDO=$record bash -c '
        set -Eeuo pipefail; source ./kinobu.sh; ui_init
        LOG=$(mktemp) TMP_DIR=$(mktemp -d)
        has_cmd() { return 1; }; is_installed() { return 1; }      # nothing is installed yet
        install_zen() { :; }
        PLAN=(ai) CHOSEN=(claude ollama lmstudio)
        install_ai_tools; printf "%s\n" "${NEXT_STEPS[@]}"' 2>&1)
    done_cmds=$(<"$record")
    check "ai: runs every chosen installer"     has "$done_cmds" "claude.ai/install.sh"
    check "ai: no installer for removed agents" lacks "$done_cmds" "chatgpt.com/codex"
    check "ai: Ollama too"                      has "$done_cmds" "ollama.com"
    check "ai: LM Studio from its .deb"         has "$done_cmds" "lmstudio.ai"
    check "ai: uv always"                       has "$done_cmds" "astral.sh/uv"
    check "ai: tells how to sign in"            has "$out" "Open Claude Code once to sign in"
    : >"$record"
    out=$(HOME=$home KINOBU_PREFIX=$prefix PATH=$stubs:$PATH KINOBU_TEST_SUDO=$record bash -c '
        set -Eeuo pipefail; source ./kinobu.sh; ui_init
        LOG=$(mktemp) TMP_DIR=$(mktemp -d)
        has_cmd() { return 1; }; install_zen() { :; }
        PLAN=(ai) CHOSEN=(claude); install_ai_tools' 2>&1)
    check "ai: only what was chosen"            lacks "$(<"$record")" "ollama"
    rm -rf "$home" "$record" "$profile" "$prefix" "$real_config/dconf/kinobutest"
fi

echo "The whole setup (fake HOME, its own dconf database, stubs: the real system is not touched)"
real_config=$HOME/.config
if [[ $(PATH=$stubs:$PATH command -v sudo) != "$stubs/sudo" ]]; then
    echo "  ✖ the sudo stub is not first in PATH: skipped"; fails=$((fails + 1))
else
    home=$(mktemp -d) record=$(mktemp) profile=$(mktemp) prefix=$(mktemp -d)
    share=$prefix/share/kinobu
    echo "user-db:kinobutest" >"$profile"
    rm -f "$real_config/dconf/kinobutest"
    real_before=$(dconf read /org/gnome/desktop/wm/keybindings/close; dconf read /org/gnome/shell/favorite-apps)
    whole() {   # whole install|update|user [HOME]: every block; sudo and the voice assistant are left out
        HOME=${2:-$home} KINOBU_PREFIX=$prefix XDG_CONFIG_HOME=$real_config DCONF_PROFILE=$profile PATH=$stubs:$PATH KINOBU_TEST_SUDO=$record NO_COLOR=1 bash -c '
            set -Eeuo pipefail; source ./kinobu.sh; ui_init
            trap "on_error \$LINENO" ERR; trap cleanup EXIT
            sudo_start() { :; }; install_zen() { :; }
            ACTION=$1 CHOSEN=(chrome missioncenter vscode intellij pycharm claude) HAS_V3=true WELCOME="" RUN_KIND=setup
            case $ACTION in
                update) RUN_KIND=update; PLAN=("${UPDATE_BLOCKS[@]}") ;;
                user)   SYSTEM_WRITES=false; CHOSEN=(claude)
                        if [[ -f $CONFIG_DIR/version ]]; then RUN_KIND=update; PLAN=(user desktop shortcuts context)
                        else PLAN=(ai user desktop shortcuts context); fi ;;
                *)      PLAN=("${BLOCKS[@]}") ;;
            esac
            run_plan' _ "$1" 2>&1
    }
    isolated() { DCONF_PROFILE=$profile dconf read "$1"; }
    out=$(whole install)
    check "every block runs to the end"         has "$out" "✔ Done"
    check "no block is skipped"                 lacks "$out" "not written yet"
    echo " System (shared by every user)"
    check "a copy of Kinobu and its command"    test -s "$share/src/kinobu.sh" -a -x "$prefix/bin/kinobu"
    check "the launcher and the notifier"       test -x "$prefix/bin/kinobu-launch" -a -x "$prefix/bin/kinobu-notify"
    check "cheat sheet, tour, approval window"  test -s "$share/programs/keys.py" -a -s "$share/programs/welcome.py" -a -s "$share/programs/approve.py" -a -s "$share/programs/kinobu-notice.py"
    check "translations and the skill"          test -s "$share/i18n/es.json" -a -s "$share/skills/kinobu/SKILL.md"
    check "a tidy system folder"                test "$(find "$share" -mindepth 1 -maxdepth 1 -printf "%f\n" | sort | tr "\n" " ")" = "data i18n programs skills src version "
    check "the login entry for other users"     grep -q "kinobu-launch user-setup" "$prefix/etc/xdg/autostart/kinobu-user.desktop"
    check "the installed version"               test "$(cat "$share/version")" = "$(bash kinobu.sh -v | cut -d" " -f2)"
    # shellcheck disable=SC2016
    check "no template mark left unfilled"      bash -c '! grep -rIqE "@[A-Z_]{3,}@" "$1/bin" "$1/share/kinobu" --exclude-dir=src' _ "$prefix"
    check "its Python files compile"            python3 -m py_compile "$share"/programs/*.py
    check "its scripts parse"                   bash -n "$prefix/bin/kinobu-launch" "$prefix/bin/kinobu-notify"
    check "nothing of Kinobu's programs in HOME" test ! -e "$home/.local/bin/kinobu-launch" -a ! -e "$home/.local/share/kinobu/keys.py"
    echo " User (in their own folder)"
    check ".bashrc gets the Kinobu block"       grep -q ">>> kinobu >>>" "$home/.bashrc"
    check "fastfetch config points to the system logo" grep -q "$share/data/fastfetch-logo.txt" "$home/.config/fastfetch/config.jsonc"
    check "the skill is linked into Claude Code" test "$(readlink "$home/.claude/skills/kinobu")" = "$share/skills/kinobu"
    check "the note is in the agent's instructions" grep -q "kinobu:begin" "$home/.claude/CLAUDE.md"
    check "the subagent for Claude Code"        test -s "$home/.claude/agents/kinobu-system.md"
    check "Claude Code's hooks call the system notifier" test "$(jq -r '.hooks.Stop[0].hooks[0].command' "$home/.claude/settings.json")" = "$prefix/bin/kinobu-notify claude done"
    check "nothing for the removed agents"      test ! -e "$home/.cursor" -a ! -e "$home/.hermes" -a ! -e "$home/.config/opencode" -a ! -e "$home/.codex" -a ! -e "$home/.gemini" -a ! -e "$home/.agents"
    check "the calculator is pinned in the dock" has "$(isolated /org/gnome/shell/favorite-apps)" "org.gnome.Calculator.desktop"
    check "the three folders open the app grid" has "$(isolated /org/gnome/shell/app-picker-layout)" "[{'System': <{'position': <0>}>, 'Settings': <{'position': <1>}>, 'Utilities': <{'position': <2>}>"
    check "the Settings folder has a translated name" test -s "$home/.local/share/desktop-directories/Kinobu-Settings.directory"
    check "the weather city comes from the time zone" has "$(isolated /org/gnome/shell/weather/locations)" "uint32"
    check "shortcuts run the system launcher"   has "$(isolated /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/kinobu-0/command)" "$prefix/bin/kinobu-launch terminal"
    check "the user's version is recorded"      test "$(cat "$home/.config/kinobu/version")" = "$(cat "$share/version")"
    echo " Again, and --update"
    out=$(whole install)
    check "a second run works"                  has "$out" "✔ Done"
    check "and duplicates nothing in .bashrc"   test "$(grep -c ">>> kinobu >>>" "$home/.bashrc")" -eq 1
    check "nor in the hooks"                    test "$(jq '.hooks.Stop | length' "$home/.claude/settings.json")" -eq 1
    check "the tour opens only the first time"  lacks "$out" "welcome tour is open"
    out=$(whole update)
    check "--update runs to the end"            has "$out" "✔ Done"
    check "--update leaves the look alone"      lacks "$out" "Dock favourites"
    echo " Another user of the same computer (--user)"
    other=$(mktemp -d)
    rm -f "$real_config/dconf/kinobutest"       # the second user starts with untouched settings
    : >"$record"; sleep 1; touch "$record"
    out=$(whole user "$other")
    check "--user runs to the end"              has "$out" "✔ Done"
    check "it asks for no password"             lacks "$(<"$record")" "sudo"
    check "it changes nothing on the system"    test "$(find "$prefix" -type f -newer "$record" | wc -l)" -eq 0
    check "the new user gets the shell block"   grep -q ">>> kinobu >>>" "$other/.bashrc"
    check "the skill, linked to the system one" test "$(readlink "$other/.claude/skills/kinobu")" = "$share/skills/kinobu"
    check "the hooks and the note"              test -s "$other/.claude/settings.json" -a -s "$other/.claude/CLAUDE.md"
    check "the shortcuts"                       has "$(isolated /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/kinobu-0/command)" "kinobu-launch terminal"
    check "and is marked as up to date"         test "$(cat "$other/.config/kinobu/version")" = "$(cat "$share/version")"
    check "the welcome tour opens for them"     has "$out" "welcome tour"
    out=$(whole user "$other")
    check "later it only refreshes (look kept)" lacks "$out" "Dock favourites"
    real_after=$(dconf read /org/gnome/desktop/wm/keybindings/close; dconf read /org/gnome/shell/favorite-apps)
    check "the real GNOME settings were not touched" test "$real_before" = "$real_after"
    rm -rf "$home" "$other" "$record" "$profile" "$prefix" "$real_config/dconf/kinobutest"
fi

echo
if ((fails)); then echo "$fails test(s) failed"; exit 1; fi
echo "All tests passed"
