# A scene for tests/desktop-shots.sh: Seasons, then Files and a terminal in a few palettes.
# shellcheck shell=bash disable=SC2154  # start, stop, shot and $KINOBU come from desktop-shots.sh
cd "$KINOBU" || exit 1
mkdir -p ~/Documents ~/Pictures ~/Music ~/Projects ~/Downloads
touch ~/notes.md ~/budget.ods
listing='printf "\e[32mkinobu\e[0m:\e[34m~/Projects\e[0m$ ls --color\n\e[34mDocuments\e[0m  \e[34mPictures\e[0m  \e[31merror.log\e[0m  \e[33mnotes.md\e[0m  \e[35mlogo.svg\e[0m  \e[36mlink\e[0m\n"; sleep 60'

look() {   # look NAME THEME [PALETTE]: apply a theme, then Files and a terminal, one at a time
    python3 files/apps/kinobu_theme.py set "$2" ${3:+--palette "$3"} >/dev/null
    start nautilus --new-window "$HOME"; sleep 4; shot "$1-files"; stop
    start ptyxis --new-window -- bash -c "$listing"; sleep 3; shot "$1-terminal"; stop
}

python3 files/apps/kinobu_theme.py set kinobu >/dev/null
start python3 files/apps/seasons.py; sleep 4; shot seasons; stop
start python3 files/apps/seasons.py --page icons; sleep 4; shot seasons-icons; stop
look kinobu-forest kinobu forest
look kinobu-night kinobu night
look kinobu-meadow kinobu meadow
look tokyo-storm tokyo-night storm
look catppuccin-latte catppuccin latte
look nord nord
look macos-light macos light
