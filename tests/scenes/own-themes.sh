# A scene for tests/desktop-shots.sh: the user's own themes in Seasons (the card's menu, Duplicate
# and the colour editor), with a copy of Kinobu's theme made and changed from the command line.
# shellcheck shell=bash disable=SC2154  # start, stop, shot and $KINOBU come from desktop-shots.sh
cd "$KINOBU" || exit 1
k() { python3 files/apps/kinobu_theme.py "$@" >/dev/null; }
k set kinobu
k new "Autumn" --from kinobu
k colour autumn forest accent=#D08770 background=#2A2421 view=#231E1B sidebar=#2F2925 card=#38302B
start python3 files/apps/seasons.py; sleep 4; shot own-gallery; stop
start python3 files/apps/seasons.py --edit autumn; sleep 4; shot own-editor; stop
start python3 files/apps/seasons.py --edit nord; sleep 4; shot own-duplicate; stop
k set autumn
start python3 files/apps/seasons.py; sleep 4; shot own-applied; stop
mkdir -p ~/.local/share/icons && cp -r /usr/share/icons/DMZ-Black ~/.local/share/icons/My-Cursor 2>/dev/null \
    && sed -i 's/^Name=.*/Name=My Cursor/' ~/.local/share/icons/My-Cursor/index.theme
start python3 files/apps/seasons.py --page cursors; sleep 4; shot own-cursors; stop
