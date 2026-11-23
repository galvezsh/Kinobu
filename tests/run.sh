#!/usr/bin/env bash
# Kinobu's tests: syntax, lint, the command line and the block picker. Nothing touches the system.
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")/.." || exit 1
export KINOBU_NO_DOWNLOAD=1   # the themes' wallpapers are not downloaded from Wallhaven in the tests
fails=0
check() { if "${@:2}"; then echo "  ✔ $1"; else echo "  ✖ $1"; fails=$((fails + 1)); fi; }
has()   { [[ $1 == *"$2"* ]]; }
lacks() { [[ -n $1 && $1 != *"$2"* ]]; }

echo "Syntax and lint"
check "bash -n" bash -n kinobu.sh lib/*.sh tests/run.sh
if command -v shellcheck >/dev/null; then
    check "shellcheck" shellcheck -x -S style kinobu.sh lib/*.sh tests/run.sh tests/themes-apply.sh files/apps/kinobu-do files/apps/kinobu-login-screen files/apps/kinobu-boot-splash
elif command -v uvx >/dev/null; then
    check "shellcheck (uvx)" uvx --quiet --from shellcheck-py shellcheck -x -S style kinobu.sh lib/*.sh tests/run.sh tests/themes-apply.sh files/apps/kinobu-do files/apps/kinobu-login-screen files/apps/kinobu-boot-splash
else
    echo "  · shellcheck not available, skipped"
fi

check "installed Python files compile" python3 -m py_compile files/apps/*.py files/agents/*.py tools/*.py
check "installed scripts parse" bash -n files/apps/kinobu-launch files/apps/kinobu-do files/agents/kinobu-notify files/shell/bashrc.sh
# shellcheck disable=SC2016  # the checks below run their own shell
check "translations are valid JSON" bash -c 'for f in files/i18n/*.json; do jq -e . "$f" >/dev/null || exit 1; done'
check "nothing still says Orkestr" bash -c '! grep -rIqi orkestr kinobu.sh lib files tools'
# The skills describe what is: no versions that go stale, no plans; and they stay short
check "the skills name no versions or plans" bash -c '! grep -rIqiE "kinobu [0-9]|@APP_VERSION@|graalvm-jdk-[0-9]|planned|for now|later version" files/skills files/agents/note.md'
check "the note, loaded in every conversation, stays short" test "$(wc -w <files/agents/note.md)" -le 220
# shellcheck disable=SC2016  # the check runs its own shell
check "the skills' main files stay short" bash -c '[[ $(wc -w <files/skills/kinobu/SKILL.md) -le 600 && $(wc -w <files/skills/kinobu-dev/SKILL.md) -le 800 ]]'
check "every app speaks every language (all texts of en.json in each file)" python3 -I -c '
import json, glob, sys
en = json.load(open("files/i18n/en.json"))
sys.exit(any(k not in json.load(open(f)).get(sec, {}) for f in glob.glob("files/i18n/*.json") for sec in en for k in en[sec]))'
check "no removed agent left" bash -c '! grep -rIqiE "opencode|hermes|cursor-agent" kinobu.sh lib files/skills files/agents files/subagents files/apps'

# Opens the real Gate for a moment on the desktop: only when asked, so it never surprises anyone
if [[ ${KINOBU_TEST_WINDOWS:-} == 1 && -n ${WAYLAND_DISPLAY:-}${DISPLAY:-} ]]; then
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
out=$(HOME=$(mktemp -d) KINOBU_PREFIX=$(mktemp -d) bash kinobu.sh --update 2>&1)
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
        install_voice() { :; }
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
        has_cmd() { return 1; }; install_voice() { :; }
        PLAN=(ai) CHOSEN=(claude); install_ai_tools' 2>&1)
    check "ai: only what was chosen"            lacks "$(<"$record")" "ollama"
    out=$(HOME=$home KINOBU_PREFIX=$prefix PATH=$stubs:$PATH KINOBU_TEST_SUDO=$record bash -c '
        set -Eeuo pipefail; source ./kinobu.sh; ui_init
        LOG=$(mktemp) TMP_DIR=$(mktemp -d)
        install_voice() { :; }
        PLAN=(ai) CHOSEN=(); install_ai_tools' 2>&1)
    check "ai: an installed agent opens even if unticked" test "$(cat "$home/.config/kinobu/agent" 2>/dev/null)" = "$stubs/claude"
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
    look_keys() { for k in gtk-theme icon-theme cursor-theme accent-color color-scheme font-name; do dconf read "/org/gnome/desktop/interface/$k"; done; dconf read /org/gnome/desktop/wm/preferences/button-layout; }
    real_before=$(dconf read /org/gnome/desktop/wm/keybindings/close; dconf read /org/gnome/shell/favorite-apps; look_keys)
    whole() {   # whole install|update|user [HOME]: every block; sudo and the voice assistant are left out
        HOME=${2:-$home} KINOBU_PREFIX=$prefix XDG_CONFIG_HOME=$real_config DCONF_PROFILE=$profile PATH=$stubs:$PATH KINOBU_TEST_SUDO=$record NO_COLOR=1 bash -c '
            set -Eeuo pipefail; source ./kinobu.sh; ui_init
            trap "on_error \$LINENO" ERR; trap cleanup EXIT
            sudo_start() { :; }; install_voice() { :; }
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
    if [[ $out != *"✔ Done"* ]]; then printf '%s\n' "$out" | tail -n 25 >&2; fi
    check "every block runs to the end"         has "$out" "✔ Done"
    check "no block is skipped"                 lacks "$out" "not written yet"
    echo " System (shared by every user)"
    check "a copy of Kinobu and its command"    test -s "$share/src/kinobu.sh" -a -x "$prefix/bin/kinobu"
    check "the launcher and the notifier"       test -x "$prefix/bin/kinobu-launch" -a -x "$prefix/bin/kinobu-notify"
    check "cheat sheet, tour, approval window"  test -s "$share/programs/keys.py" -a -s "$share/programs/welcome.py" -a -s "$share/programs/approve.py" -a -s "$share/programs/kinobu-notice.py"
    check "translations and the skill"          test -s "$share/i18n/es.json" -a -s "$share/skills/kinobu/SKILL.md"
    check "Seasons, the theme engine and the themes" test -s "$share/programs/seasons.py" -a -s "$share/programs/kinobu_wallhaven.py" -a -x "$prefix/bin/kinobu-theme" -a -s "$share/themes/kinobu/theme.toml" -a -s "$prefix/share/applications/os.kinobu.Themes.desktop"
    check "the engine knows where the system is" grep -q "SYSTEM_DIR = \"$share\"" "$share/programs/kinobu_theme.py"
    check "a tidy system folder"                test "$(find "$share" -mindepth 1 -maxdepth 1 -printf "%f\n" | sort | tr "\n" " ")" = "data i18n programs skills src themes version "
    check "the login entry for other users"     grep -q "kinobu-launch user-setup" "$prefix/etc/xdg/autostart/kinobu-user.desktop"
    check "the installed version"               test "$(cat "$share/version")" = "$(bash kinobu.sh -v | cut -d" " -f2)"
    # shellcheck disable=SC2016
    check "no template mark left unfilled"      bash -c '! grep -rIqE "@[A-Z_]{3,}@" "$1/bin" "$1/share/kinobu" --exclude-dir=src --exclude-dir=theme-templates' _ "$prefix"
    check "its Python files compile"            python3 -m py_compile "$share"/programs/*.py
    check "its scripts parse"                   bash -n "$prefix/bin/kinobu-launch" "$prefix/bin/kinobu-notify"
    check "nothing of Kinobu's programs in HOME" test ! -e "$home/.local/bin/kinobu-launch" -a ! -e "$home/.local/share/kinobu/keys.py"
    echo " User (in their own folder)"
    check ".bashrc gets the Kinobu block"       grep -q ">>> kinobu >>>" "$home/.bashrc"
    check "fastfetch config points to the system logo" grep -q "$share/data/fastfetch-logo.txt" "$home/.config/fastfetch/config.jsonc"
    check "the skill is linked into Claude Code" test "$(readlink "$home/.claude/skills/kinobu")" = "$share/skills/kinobu"
    check "the skill for developing programs is linked too" test "$(readlink "$home/.claude/skills/kinobu-dev")" = "$share/skills/kinobu-dev"
    # shellcheck disable=SC2016  # the check runs its own shell
    check "the skills and the note have every mark filled" bash -c '! grep -rqE "@[A-Z_]+@" "$1/skills" "$2/.claude/CLAUDE.md"' _ "$share" "$home"
    check "the note gives the system's language"  grep -qE "system.s language: [A-Za-z]+ \(" "$home/.claude/CLAUDE.md"
    check "Claude Code answers concisely by default" test "$(jq -r .outputStyle "$home/.claude/settings.json")" = "Concise"
    check "Claude Code's verbose mode is off"   test "$(jq -r .verbose "$home/.claude/settings.json")" = "false"
    check "Ptyxis opens only the window asked for (no session restore)" test "$(isolated /org/gnome/Ptyxis/restore-session)" = "false"
    check "the note is in the agent's instructions" grep -q "kinobu:begin" "$home/.claude/CLAUDE.md"
    check "the subagent for Claude Code"        test -s "$home/.claude/agents/kinobu-agent.md"
    check "Claude Code's notices run in the background, Gate in front" test "$(jq -r '[.hooks.Stop[0].hooks[0].async, .hooks.Notification[0].hooks[0].async, (.hooks.PermissionRequest[0].hooks[0].async // false)] | map(tostring) | join(" ")' "$home/.claude/settings.json")" = "true true false"
    check "Claude Code is told to reread CONTEXT.md after compacting" test "$(jq -r '.hooks.SessionStart[0].matcher' "$home/.claude/settings.json")" = "compact"
    check "Claude Code's hooks call the system notifier" test "$(jq -r '.hooks.Stop[0].hooks[0].command' "$home/.claude/settings.json")" = "$prefix/bin/kinobu-notify claude done"
    check "nothing for the removed agents"      test ! -e "$home/.cursor" -a ! -e "$home/.hermes" -a ! -e "$home/.config/opencode" -a ! -e "$home/.codex" -a ! -e "$home/.gemini" -a ! -e "$home/.agents"
    check "the calculator is pinned in the dock" has "$(isolated /org/gnome/shell/favorite-apps)" "org.gnome.Calculator.desktop"
    check "the three folders open the app grid" has "$(isolated /org/gnome/shell/app-picker-layout)" "[{'System': <{'position': <0>}>, 'Settings': <{'position': <1>}>, 'Utilities': <{'position': <2>}>"
    check "only the folders are placed, not the apps" lacks "$(isolated /org/gnome/shell/app-picker-layout)" "<3>"
    keys=$(DCONF_PROFILE=$profile dconf dump /org/gnome/settings-daemon/plugins/media-keys/)
    check "Super+F1 opens the welcome tour"     has "$keys" "binding='<Super>F1'
command='$prefix/bin/kinobu-launch welcome'"
    check "GNOME's Help shortcut is released"   has "$keys" "help=@as []"
    check "the tour is not in the app grid"     grep -q '^NoDisplay=true' "$prefix/share/applications/os.kinobu.Welcome.desktop"
    check "the login screen: its command, its picture and apt's hook" test -x "$prefix/bin/kinobu-login-screen" -a -s "$share/data/login-background.jpg"
    check "the session sounds, the login entry and the goodbye service" test -s "$share/data/sounds/login.oga" -a -s "$share/data/sounds/logout.oga" -a -s "$prefix/etc/xdg/autostart/kinobu-login-sound.desktop" -a -s "$prefix/lib/systemd/user/kinobu-logout-sound.service"
    check "the goodbye service is turned on for every user" has "$(<"$record")" "systemctl --global enable kinobu-logout-sound.service"
    check "the boot screen: its command and its frames"   test -x "$prefix/bin/kinobu-boot-splash" -a -s "$share/data/plymouth/kinobu.plymouth" -a -s "$share/data/plymouth/throbber-0090.png"
    check "the boot screen is set up with sudo, only when needed" has "$(<"$record")" "kinobu-boot-splash --if-needed"
    # shellcheck disable=SC2016  # the check runs its own shell
    check "the login screen is built with sudo, and rebuilt by apt" bash -c '[[ $(<"$1") == *"kinobu-login-screen --if-needed"* && $(<"$1") == *"99kinobu-login-screen"* ]]' _ "$record"
    check "the dock's Show Apps button gets Kinobu's logo" test -s "$prefix/share/icons/Yaru/scalable/actions/view-app-grid-ubuntu-symbolic.svg" -a -s "$prefix/share/icons/hicolor/scalable/actions/view-app-grid-ubuntu-symbolic.svg"
    check "the Settings folder has a translated name" test -s "$home/.local/share/desktop-directories/Kinobu-Settings.directory"
    check "the weather city comes from the time zone" has "$(isolated /org/gnome/shell/weather/locations)" "uint32"
    check "shortcuts run the system launcher"   has "$(isolated /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/kinobu-0/command)" "$prefix/bin/kinobu-launch terminal"
    if [[ -d /usr/share/pixmaps/faces ]]; then
        check "a user with no account picture gets one of GNOME's" has "$(<"$record")" "SetIconFile /usr/share/pixmaps/faces/"
    fi
    check "the user's version is recorded"      test "$(cat "$home/.config/kinobu/version")" = "$(cat "$share/version")"
    echo " The look"
    check "a new user starts with the Kinobu theme" grep -q '^theme = "kinobu"' "$home/.config/kinobu/look.toml"
    check "the apps get the theme's colours"    grep -q "prefers-color-scheme" "$home/.config/gtk-4.0/kinobu.css"
    check "GNOME's accent follows the theme"    has "$(isolated /org/gnome/desktop/interface/accent-color)" "green"
    # shellcheck disable=SC2016  # the check runs its own shell
    check "a pack that fails its checksum is not installed" bash -c '[[ $1 == *"did not match its checksum"* && ! -e $2/share/icons/kora ]]' _ "$out" "$prefix"
    check "GNOME Tweaks is not installed"       lacks "$(<"$record")" "gnome-tweaks"
    echo " Again, and --update"
    out=$(whole install)
    check "a second run works"                  has "$out" "✔ Done"
    check "and duplicates nothing in .bashrc"   test "$(grep -c ">>> kinobu >>>" "$home/.bashrc")" -eq 1
    check "nor in the hooks"                    test "$(jq '.hooks.Stop | length' "$home/.claude/settings.json")" -eq 1
    check "the tour opens only the first time"  lacks "$out" "welcome tour is open"
    HOME=$home XDG_CONFIG_HOME=$real_config DCONF_PROFILE=$profile python3 -I "$share/programs/kinobu_theme.py" set nord >/dev/null 2>&1
    : >"$record"
    out=$(KINOBU_TEST_ICON=/etc/hostname whole update)
    check "--update runs to the end"            has "$out" "✔ Done"
    # shellcheck disable=SC2016  # the check runs its own shell
    check "a picture already there is kept"     bash -c '[[ $1 == *"Yours is kept"* && $(<"$2") != *SetIconFile* ]]' _ "$out" "$record"
    # shellcheck disable=SC2016  # the check runs its own shell
    check "--update keeps the theme you chose"  bash -c '[[ $(grep "^theme" "$1") == "theme = \"nord\"" ]]' _ "$home/.config/kinobu/look.toml"
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
    if [[ -d /usr/share/pixmaps/faces ]]; then
        check "and an account picture of their own" has "$(<"$record")" "SetIconFile /usr/share/pixmaps/faces/"
    fi
    check "and their own look, the Kinobu theme" grep -q '^theme = "kinobu"' "$other/.config/kinobu/look.toml"
    out=$(whole user "$other")
    check "later it only refreshes (look kept)" lacks "$out" "Dock favourites"
    real_after=$(dconf read /org/gnome/desktop/wm/keybindings/close; dconf read /org/gnome/shell/favorite-apps; look_keys)
    check "the real GNOME settings were not touched" test "$real_before" = "$real_after"
    rm -rf "$home" "$other" "$record" "$profile" "$prefix" "$real_config/dconf/kinobutest"
fi

echo "Gate, the approval window (a stand-in window, no sound)"
gate=$(mktemp -d); mkdir -p "$gate/programs"
printf '#!/usr/bin/env python3\nimport os\nopen(os.environ["MARK"], "w").close()\n' >"$gate/programs/approve.py"
sed -e "s|@PROGRAMS_DIR@|$gate/programs|g; s|@SYSTEM_DIR@|$gate|g; s|@WAIT@|45|; s|@MIN@|20|; s|@APPROVALS@|dialog|; s|@SOUND@|false|" \
    files/agents/kinobu-notify >"$gate/notify"
ask() {   # ask MODE SECONDS: a permission request the agent cancels after SECONDS
    MARK=$gate/$1 WAYLAND_DISPLAY=test XDG_RUNTIME_DIR=$gate timeout "$2" bash "$gate/notify" claude permission \
        <<<"{\"permission_mode\": \"$1\", \"tool_name\": \"Bash\", \"tool_input\": {\"command\": \"ls\"}, \"session_id\": \"t\"}" >/dev/null 2>&1
}
ask auto 1.5; ask default 1.5
check "auto mode: Gate waits, so a request approved at once never shows it" test ! -e "$gate/auto"
check "other modes: Gate opens straight away"         test -e "$gate/default"
rm -rf "$gate"

echo "Agent notices (Claude Code's hook input; a stand-in notice that writes what it would show)"
nt=$(mktemp -d); mkdir -p "$nt/programs"; cp -r files/i18n "$nt/i18n"
printf '#!/usr/bin/env python3\nimport os, sys\nwith open(os.environ["SHOWN"], "a") as f: f.write(" | ".join(sys.argv[1:]) + "\\n")\n' >"$nt/programs/kinobu-notice.py"
sed -e "s|@PROGRAMS_DIR@|$nt/programs|g; s|@SYSTEM_DIR@|$nt|g; s|@WAIT@|45|; s|@MIN@|0|; s|@APPROVALS@|dialog|; s|@SOUND@|false|" \
    files/agents/kinobu-notify >"$nt/notify"
hook() {   # hook EVENT JSON: what the notice says (or prints) for that hook
    : >"$nt/shown"
    SHOWN=$nt/shown LANGUAGE=en XDG_RUNTIME_DIR=$nt bash "$nt/notify" claude "$1" <<<"$2" 2>/dev/null
    sleep 0.3; cat "$nt/shown"
}
check "an API error is said plainly"            has "$(hook failed '{"error": "server_error", "session_id": "a"}')" "The servers are busy"
check "an expired session is said plainly"      has "$(hook failed '{"error": "authentication_failed", "session_id": "b"}')" "sign in to the agent again"
check "an unknown error shows the agent's text" has "$(hook failed '{"error": "unknown", "last_assistant_message": "API Error: odd", "session_id": "c"}')" "API Error: odd"
check "an MCP server asking for a link notifies" has "$(hook waiting '{"notification_type": "elicitation_url_dialog", "message": "x", "session_id": "d"}')" "open a link"
check "a background agent waiting notifies"     has "$(hook waiting '{"notification_type": "agent_needs_input", "session_id": "e"}')" "background agent needs your answer"
check "finished says what still runs"           has "$(hook "done" '{"last_assistant_message": "Done.", "background_tasks": [{"id": "1", "status": "running"}, {"id": "2", "status": "running"}], "session_id": "f"}')" "2 tasks are still running"
check "after a compaction the agent rereads CONTEXT.md" has "$(hook compacted '{"source": "compact"}')" "CONTEXT.md"
rm -rf "$nt"

echo "Session sounds (the launcher with stand-ins for gsettings and pw-play)"
snd=$(mktemp -d); mkdir -p "$snd/data/sounds" "$snd/bin"; cp files/branding/sounds/*.oga "$snd/data/sounds/"
sed "s|@SYSTEM_DIR@|$snd|g; s|@BIN_DIR@|$snd/bin|g; s|@PROGRAMS_DIR@|$snd|g" files/apps/kinobu-launch >"$snd/launch"
# shellcheck disable=SC2016  # the stand-ins expand their own variables
printf '#!/bin/sh\necho "$SOUNDS"\n' >"$snd/bin/gsettings"
# shellcheck disable=SC2016  # the stand-ins expand their own variables
printf '#!/bin/sh\necho "$1" >"$PLAYED"\n' >"$snd/bin/pw-play"
chmod +x "$snd/bin/"*
# shellcheck disable=SC2016  # the stand-in expands its own variable
printf '#!/bin/sh\n[ -e "$SINK" ]\n' >"$snd/bin/wpctl"; chmod +x "$snd/bin/wpctl"
sound() { rm -f "$snd/played"; SOUNDS=$1 PLAYED=$snd/played SINK=$snd/sink KINOBU_SOUND_SETTLE=0 PATH=$snd/bin:$PATH bash "$snd/launch" sound "$2" >/dev/null 2>&1; cat "$snd/played" 2>/dev/null; }
: >"$snd/sink"   # a default output exists (the login sound waits for it)
check "the login sound plays"                     has "$(sound true login)" "$snd/data/sounds/login.oga"
check "the goodbye plays"                         has "$(sound true logout)" "$snd/data/sounds/logout.oga"
check "both stay silent with the alert sounds off" test -z "$(sound false login)$(sound false logout)"
check "only Kinobu's two sounds can be played"    test -z "$(sound true ../../etc/passwd)"
rm -f "$snd/sink"; ( sleep 0.6; : >"$snd/sink" ) &
check "the login sound waits until there is a sound output" has "$(sound true login)" "$snd/data/sounds/login.oga"
rm -rf "$snd"

echo "Willow's safe actions (kinobu-do, in a fake home: nothing of the desktop is changed)"
kd_home=$(mktemp -d)
kd() { HOME=$kd_home bash files/apps/kinobu-do "$@" 2>&1; }
# shellcheck disable=SC2016  # the check runs its own shell
check "it keeps nothing about the user"               bash -c '[[ $(HOME=$1 bash files/apps/kinobu-do remember x) != Remembered* && ! -e $1/.config/kinobu/willow.md ]]' _ "$kd_home"
# shellcheck disable=SC2016  # the check runs its own shell
check "values out of range are refused"                bash -c '[[ $(HOME=$1 bash files/apps/kinobu-do volume 300) == Error:* && $(HOME=$1 bash files/apps/kinobu-do remind 0 x) == Error:* ]]' _ "$kd_home"
check "only known Settings pages open"                 has "$(kd settings nothing)" "unknown page"
check "an unknown action shows the help"               has "$(kd fly)" "kinobu-do remind MINUTES TEXT"
rm -rf "$kd_home"

echo "Themes (kinobu-theme and Seasons)"
check "every factory theme is valid and reads well (contrast)" bash -c "python3 -I files/apps/kinobu_theme.py validate --strict >/dev/null"
# shellcheck disable=SC2016  # the check runs its own shell
# shellcheck disable=SC2016  # the check runs its own shell
check "every palette's terminal colours read on its background (4.5)" python3 -I -c '
import sys; sys.path.insert(0, "files/apps"); import kinobu_theme as k
bad = [f"{t}/{p} {c}" for t in k.theme_ids() for p in k.load(t)["palettes"]
       for c, v in k.terminal_colours(k.load(t), p).items()
       if c in k.ANSI_TEXT and k.contrast(v, k.terminal_colours(k.load(t), p)["Background"]) < 4.5]
sys.exit(1 if bad else 0)'
# The user's own themes: a copy, its colours changed, the factory ones and unreadable text refused
own_home=$(mktemp -d)
own() { HOME=$own_home DCONF_PROFILE=/nonexistent python3 -I files/apps/kinobu_theme.py "$@" 2>&1; }
own new "Mí Otoño" --from kinobu >/dev/null
own new "Mí Otoño" --from nord >/dev/null
own colour mi-otono forest accent=#5e81ac background=#2A2421 >/dev/null
check "a copy of a theme is yours, under its own name"       grep -q '^name = "Mí Otoño"' "$own_home/.config/kinobu/themes/mi-otono/theme.toml"
check "a second copy with the same name gets its own id"     test -f "$own_home/.config/kinobu/themes/mi-otono-2/theme.toml"
check "its colours change in its palette, GNOME's accent follows" bash -c "sed -n '/^\[palettes.forest\]/,/^\[palettes.night\]/p' '$own_home/.config/kinobu/themes/mi-otono/theme.toml' | grep -q 'accent = \"#5E81AC\"' && grep -q 'gnome_accent = \"slate\"' '$own_home/.config/kinobu/themes/mi-otono/theme.toml'"
check "the copy is still a valid theme"                      bash -c "HOME=$own_home python3 -I files/apps/kinobu_theme.py validate mi-otono >/dev/null"
check "the factory themes are not changed in place"          has "$(own colour kinobu forest accent=#000000)" "make your own copy first"
check "colours with unreadable text are refused"             has "$(own colour mi-otono forest foreground=#2A2421)" "hard to read"
own buttons mi-otono left >/dev/null
check "your theme can put the window buttons on the left"   grep -q '^button_layout = "close,minimize,maximize:appmenu"' "$own_home/.config/kinobu/themes/mi-otono/theme.toml"
own delete mi-otono-2 >/dev/null
check "deleting your theme sends it to the Trash"            test -d "$own_home/.local/share/Trash/files/mi-otono-2"
rm -rf "$own_home"

check "the GTK 3 stylesheet uses only colours GTK 3 reads" bash -c '! python3 -I files/apps/kinobu_theme.py css kinobu --gtk3 | grep -qE "rgba?\([0-9.]+ [0-9.]+ [0-9.]+"'
# shellcheck disable=SC2016  # the check runs its own shell
check "a palette and its pair share one stylesheet" bash -c '[[ $(python3 -I files/apps/kinobu_theme.py css kinobu | grep -c "prefers-color-scheme") -ge 3 ]]'
# shellcheck disable=SC2016  # the check runs its own Python
# shellcheck disable=SC2016  # the check runs its own Python
check "Seasons has every text in every language" python3 -I -c '
import json, glob, sys
en = set(json.load(open("files/i18n/en.json"))["seasons"])
for f in glob.glob("files/i18n/*.json"):
    if set(json.load(open(f)).get("seasons", {})) != en: sys.exit(f)'
# shellcheck disable=SC2016  # the check runs its own Python
check "every factory theme has four Wallhaven wallpapers and a description in every language" python3 -I -c '
import sys, json, glob, os; sys.path.insert(0, "files/apps"); import kinobu_theme as k
texts = [json.load(open(f))["seasons"] for f in glob.glob("files/i18n/*.json")]
for tid in os.listdir("files/themes"):
    if tid == "templates": continue
    t = k.load(tid)
    assert len(k.theme_wallhaven(t, "dark")) == 4, tid
    assert all(f"theme.{tid}" in s for s in texts), tid'
check "no translation file repeats a key" python3 -I -c '
import json, glob, sys
def pairs(p):
    keys = [k for k, _ in p]
    if len(keys) != len(set(keys)): sys.exit(1)
    return dict(p)
for f in glob.glob("files/i18n/*.json"): json.load(open(f), object_pairs_hook=pairs)'
if command -v glib-compile-resources >/dev/null && [[ -f /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource ]]; then
    ls_tmp=$(mktemp -d); mkdir -p "$ls_tmp/data"; cp files/branding/login-background.jpg "$ls_tmp/data/"
    sed "s|@SYSTEM_DIR@|$ls_tmp|g" files/apps/kinobu-login-screen >"$ls_tmp/kls"
    bash "$ls_tmp/kls" --build "$ls_tmp/out.gresource" >/dev/null 2>&1
    # shellcheck disable=SC2016  # the check runs its own shell
    check "the login screen theme is Ubuntu's with Kinobu's picture" bash -c '[[ $(gresource extract "$1" /org/gnome/shell/theme/gdm.css) == *"kinobu-login.jpg"* ]] && gresource extract "$1" /org/gnome/shell/theme/kinobu-login.jpg | cmp -s - files/branding/login-background.jpg' _ "$ls_tmp/out.gresource"
    rm -rf "$ls_tmp"
fi
bs_tmp=$(mktemp -d); mkdir -p "$bs_tmp/data/plymouth"; cp files/branding/plymouth/* "$bs_tmp/data/plymouth/"
sed "s|@SYSTEM_DIR@|$bs_tmp|g" files/apps/kinobu-boot-splash >"$bs_tmp/kbs"
bash "$bs_tmp/kbs" --build "$bs_tmp/out" >/dev/null 2>&1
# shellcheck disable=SC2016  # the check runs its own shell
check "the boot screen theme: two-step, its folder and 90 frames that loop" bash -c 'grep -qx "ModuleName=two-step" "$1/kinobu.plymouth" && grep -qx "ImageDir=/usr/share/plymouth/themes/kinobu" "$1/kinobu.plymouth" && [[ $(ls "$1"/throbber-*.png | wc -l) -eq 90 && -f $1/animation-0001.png ]]' _ "$bs_tmp/out"
# shellcheck disable=SC2016  # the check runs its own shell
check "the boot screen keeps the maker's logo, with Kinobu's when there is none" bash -c '[[ $(grep -c "^UseFirmwareBackground=true" "$1/kinobu.plymouth") -eq 3 && -f $1/bgrt-fallback.png ]]' _ "$bs_tmp/out"
if [[ -d /usr/share/plymouth/themes/spinner ]]; then
    check "the boot screen takes Ubuntu's pictures for a disk password" test -f "$bs_tmp/out/lock.png" -a -f "$bs_tmp/out/entry.png" -a -f "$bs_tmp/out/bullet.png"
fi
rm -rf "$bs_tmp"
# shellcheck disable=SC2016  # the check runs its own Python
check "Wallhaven: every category, safe and wide pictures are asked for and kept" python3 -I -c '
import sys, json; sys.path.insert(0, "files/apps"); import kinobu_wallhaven as w
asked = []
def fake(url):
    asked.append(url)
    items = [{"id": "aaa111", "purity": "sfw", "path": "https://w.wallhaven.cc/full/aa/wallhaven-aaa111.jpg", "thumbs": {"large": "https://th.wallhaven.cc/lg/aa/aaa111.jpg"}, "resolution": "3840x2160"},
             {"id": "bbb222", "purity": "sketchy", "path": "https://w.wallhaven.cc/full/bb/wallhaven-bbb222.jpg"},
             {"id": "ccc333", "purity": "sfw", "path": "http://example.com/x.jpg"}]
    return json.dumps({"data": items, "meta": {"current_page": 1, "last_page": 3, "seed": "AbC123"}}).encode(), "application/json"
w._get = fake
found, nxt = w.search("forest", "relevance", colour="#336600", atleast="2560x1440")
u = asked[0]
assert all(p in u for p in ("purity=100", "categories=111", "ratios=landscape", "q=forest", "colors=336600", "atleast=2560x1440")), u
assert [p["id"] for p in found] == ["aaa111"] and nxt == (2, "AbC123"), (found, nxt)
w.search(colour="notacolour", seed="x; rm"); assert "colors" not in asked[1] and "seed" not in asked[1], asked[1]
'
fake=$(mktemp -d)
real_before=$(dconf dump / | sha256sum)
# shellcheck disable=SC2016  # $XDG_RUNTIME_DIR belongs to the inner shell
out=$(env -i PATH="$PATH" LANG=C.UTF-8 HOME="$fake" KINOBU_TEST_HOME="$fake" KINOBU_NO_DOWNLOAD=1 XDG_CONFIG_HOME="$fake/.config" XDG_DATA_HOME="$fake/.local/share" \
    XDG_CACHE_HOME="$fake/.cache" XDG_STATE_HOME="$fake/.local/state" XDG_RUNTIME_DIR="$fake/run" \
    bash -c 'mkdir -m 700 -p "$XDG_RUNTIME_DIR"; dbus-run-session -- tests/themes-apply.sh' 2>&1)
check "apply: a light palette is light, in GNOME and Ptyxis" has "$out" "kinobu-light scheme='prefer-light'"
check "apply: --mode light picks the theme's light palette" has "$out" "kinobu-light-palette=kinobu meadow light"
check "apply: a palette is chosen by name"                has "$out" "palette-storm=tokyo-night storm dark css=3 bg=window-bg-color: #24283B"
check "apply: a mode moves to the palette's pair"         has "$out" "mode-light=tokyo-night day light scheme='prefer-light'"
check "apply: an unknown palette is refused, with the list" has "$out" "has no palette 'nothing' (it has: night, storm, moon, day, light)"
check "kinobu-do style dark goes to the pair"             has "$out" "now=tokyo-night night dark"
check "a look on Dracula moves to Catppuccin's Alucard (light)" has "$out" "dracula-moved=catppuccin alucard light"
check "a look file from before palettes keeps its mode"   has "$out" "old-look=nord snow-storm light file-palette=1 file-variant=0"
check "apply: GNOME's accent and Yaru follow the theme"   has "$out" "accent='green' icons='Yaru-olive'"
check "apply: Ptyxis gets the theme's palette and follows the mode" has "$out" "palette='kinobu-kinobu' style='system'"
check "apply: gtk.css imports Kinobu's stylesheet once"   has "$out" "gtk4-import=1"
check "apply: macOS puts the window buttons on the left"  has "$out" "buttons='close,minimize,maximize:appmenu'"
check "apply: a missing icon pack falls back to Yaru"     has "$out" "missing-pack icons='Yaru-blue'"
check "apply: the palette and its pair join in one Ptyxis palette" has "$out" "macos-palette-file=yes"
check "apply: fastfetch and the setup get the theme's accent for each mode" has "$out" "terminal-accent-dark=yes"
check "apply: … and for the light mode"                    has "$out" "terminal-accent-light=yes"
check "apply: the theme in use is remembered"             has "$out" "macos light"
check "apply: an unknown theme is refused"                has "$out" "No theme called"
check "your picks stay when the theme changes"           has "$out" "picks-kept icons='Adwaita' cursor='Adwaita'"
check "your picks are saved in your look file"           has "$out" "look-file=1"
# shellcheck disable=SC2016  # the check runs its own shell
check "'theme' goes back to the theme's icons"            bash -c '[[ $1 == *"back-to-theme icons="* && $1 != *"back-to-theme icons='"'"'Adwaita"* ]]' _ "$out"
check "the icons in use are linked into the home folder" has "$out" "home-link=/usr/share/icons/Yaru-olive-dark"
check "links no longer in use go, the user's own stay"   has "$out" "old-link-gone=yes own-link-kept=yes"
check "changing one wallpaper makes the four your own"      has "$out" "one-wallpaper=4"
check "one wallpaper on every workspace"                 has "$out" "everywhere=4"
check "there are four wallpapers, not more"              has "$out" "there are 4 wallpapers"
check "older apps get your cursor too (~/.icons/default)" has "$out" "default-cursor=Inherits=Adwaita"
if [[ -d /usr/share/icons/Papirus ]]; then
    check "Papirus' folders take the theme's colour"           has "$out" "folders-violet='Papirus-Dark-kinobu-violet'"
    check "… linked to Papirus' own coloured folders"         has "$out" "folder-link=/usr/share/icons/Papirus/48x48/places/folder-violet.svg"
    check "… one at a time: another theme's colour replaces it" has "$out" "folders-nord='Papirus-Dark-kinobu-nordic' violet-gone=yes"
    check "… and no folders of Kinobu's over another pack"   has "$out" "none-left=0"
fi
check "the login and logout sounds are Kinobu's by default" has "$out" "sound-default=login.oga"
check "a session sound can be turned off"                  has "$out" "sound-off=[]"
check "your own sound is a copy, kept when the theme changes" has "$out" "sound-own=$fake/.local/share/kinobu/sounds/login/bell.ogg logout-kept=[]"
check "a file that is not a sound is refused"              has "$out" "not a sound Kinobu can play"
check "your own sound comes back after Kinobu's"            has "$out" "sound-own-again=bell.ogg"
check "apply: the real settings were not touched"         test "$real_before" = "$(dconf dump / | sha256sum)"
rm -rf "$fake"

echo
if ((fails)); then echo "$fails test(s) failed"; exit 1; fi
echo "All tests passed"
