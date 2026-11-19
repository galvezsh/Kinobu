# Changelog

What changed in each version of Kinobu. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). To bring a computer set up by an earlier version to the latest one, run `bash kinobu.sh --update` (your look is kept).

## [0.2] — 2026-11-18

Kinobu's look and its own apps: themes with palettes and Seasons to choose them, wallpapers from Wallhaven, Willow (formerly Zen) with three powers and safe actions, Kinobu Agent, and the first real install and update on the author's computer. Run `bash kinobu.sh --update`: your theme is kept and moved to its palettes on its own.

### Added

- **Themes and Seasons.** The `kinobu-theme` engine and eight factory themes: Kinobu (on Everforest), Tokyo Night, Catppuccin (with Dracula), Nord, Gruvbox, Rosé Pine, Windows and macOS (design in `docs/themes.md`). Applying one changes the light or dark mode, GNOME's accent, the colours of every libadwaita app (Files, Settings…), the icons, the cursor, the window buttons and the terminal palette, and checks the contrast of its colours first. **Seasons**, the app to choose them, shows a preview of each theme drawn from its own colours, and has sections for icons, cursors, fonts and wallpapers. What you pick there is saved in `~/.config/kinobu/look.toml` and stays when you change themes; Kinobu's updates never change that file. A new user starts with the Kinobu theme.
- **Icon packs, cursors and fonts for the themes**, for every user: Papirus, Numix Circle, elementary, Kora; Bibata, Breeze, Phinger, Catppuccin, Nordzy, macOS and WhiteSur cursors; Inter and JetBrains Mono. From Ubuntu when it has them, otherwise ready-made downloads with a fixed version and checksum.
- **Screenshots of a real, separate desktop for tests** (`tests/desktop-shots.sh`), and tests that apply themes without touching your settings.
- **Themes have palettes instead of a dark and a light variant.** Each palette is dark or light and has a pair of the other mode for GNOME's dark-style switch. New ones: Tokyo Night Storm and Moon, Catppuccin Macchiato and Frappé, Rosé Pine Moon, Gruvbox Dark Hard, and Kinobu's Night. Seasons shows a round button per palette; `kinobu-theme set <id> --palette P | --mode dark|light`; `kinobu-do theme ID PALETTE`. Look files and themes from before keep working.
- **Every theme brings four wallpapers** from Wallhaven (forests for Kinobu, neon cities for Tokyo Night, snowy peaks for Nord…), downloaded when the theme is applied. Always four, one per workspace and repeated in order when there are more; *On every workspace* puts one everywhere, and changing one makes the four your own. `kinobu-theme pick wallpapers PATH`.
- **Seasons speaks every language**: all its texts and the themes' descriptions are translated into Spanish, German, French, Italian and Portuguese. The banner about your own picks is gone (the Follow the theme switches say it).
- **Wallpapers from Wallhaven in Seasons.** *Find wallpapers on Wallhaven…* opens a window with a search box and random pictures, each theme's suggestion (a forest for Kinobu, a neon city for Tokyo Night…) and the popular ones. A click shows a picture large; *Use* downloads it to `~/Pictures/Wallhaven` and sets it on one workspace or all of them. Every category, safe-for-work and wide pictures; no account.
- **At least two dark and two light palettes in every theme**: Kinobu's Birch, Tokyo Night Light, Gruvbox Light Hard, Rosé Pine Dawn Bright, Nord's Deep and Bright, and Soft and Deep for Windows and macOS. **Dracula is now part of Catppuccin** (Dracula and Alucard palettes, blended with Catppuccin's greys); a look on Dracula moves there on its own. Eight themes.
- **Seasons: a "Follow the theme" switch** in Icons, Cursors, Fonts and Wallpapers. Off keeps what the theme gives now as your own choice; on goes back to the theme's.
- **The dock's Show Apps button shows Kinobu's logo** instead of Ubuntu's (a symbolic version of the logo, drawn by `tools/logo.py`).
- **Seasons says when a theme's wallpapers are downloading** (the first time a theme is applied it can take a while): a notice stays until they are in, the pointer shows it is working, and the four are downloaded at once.
- **The login screen has Kinobu's background** instead of Ubuntu's plain grey: the wordmark large, blurred and dimmed on a dark gradient, the same for every user. Built from Ubuntu's own theme and chosen through its `gdm-theme.gresource` alternative, so Ubuntu's files are never changed; apt rebuilds it when Ubuntu updates its theme, and `sudo kinobu-login-screen --remove` brings the grey back. Adds the small `libgio-2.0-dev-bin` package.
- **Willow can be stopped while it speaks**: a stop button next to the microphone while it talks, Esc (a second Esc closes the window) or Super+Shift+Space again. The voice stops at once, the whole answer stays in the window and Willow listens again.
- **Super+F1 opens the welcome tour** (Sprout), shown in Trail and the tour itself; the tour leaves the app grid. GNOME's Help shortcut is released (Yelp is not installed).

### Changed

- **Agents**: only Claude Code, until its integration is complete; other agents will be added one by one. Codex and Antigravity CLI were integrated during 0.1 and taken out again (installer, skill link, note, subagent and hooks). Cursor CLI, opencode and Hermes Agent are not installed or integrated either; Cursor and the Antigravity IDE stay as editors.
- **Catalogue**: 33 choices in four menus. GNOME Boxes and MKVToolNix are gone and virt-manager sits next to Docker.
- **The voice assistant is called Willow** (it was Zen); it is the same app. Underneath it is `voice`: app ID `os.kinobu.Voice`, `kinobu-launch voice`, `voice.py`, `~/.config/kinobu/voice.json` and `~/.local/share/kinobu/voice/`.
- **Kinobu Agent** (`kinobu-agent`): the read-only subagent that investigates the system for your agent.
- **Willow takes safe actions** through `kinobu-do` (volume, microphone, brightness, night light, Do Not Disturb, dark or light mode, theme, music, Settings pages, Wi-Fi, Bluetooth, reminders), looks at the screen when asked (GNOME asks once for permission), reads Kinobu's skill only when unsure and runs read-only checks in the background on a stronger model. Its settings offer three levels of power (Quick: Haiku at low effort, the default; Smart: Haiku at high effort; Strong: Sonnet at medium effort) and an optional line on how it should talk; by default it is a friendly, direct mate with a touch of humour. It keeps nothing about the user between talks.
- **Kinobu's apps have names of their own**, in English and the same in every language: **Sprout** (welcome tour), **Trail** (shortcuts, Super+K), **Echo** (notifications), **Gate** (approval window) and **Willow** (voice assistant). Their app IDs and commands stay technical.
- **GNOME Tweaks is no longer installed**: Seasons covers the look, and it is easy to break the desktop with Tweaks by accident.
- **The look comes from the theme**: the fixed Yaru purple, Tokyo Night terminal and the wallpaper folder next to the script are gone.
- **Kinobu's own palettes were redone for contrast** (Forest, Night, Meadow): the old ones looked foggy, with text at 7.4 in dark and 4.9 in light. `kinobu-theme validate --strict` holds every factory palette to text 7, secondary text 4.5 and accent 3, and the tests run it.
- **The app grid only puts the three folders first**; the apps follow as GNOME or the user arranges them. Kinobu's folder apps are taken out of other folders first, so GNOME no longer drops the Settings folder.
- **Gate's "In terminal" takes you to the agent's terminal**, on whatever workspace it is; before, it only closed the window like its cross.

### Fixed

- **An agent that is already installed opens with Super+Shift+Enter even when it was not ticked** in the menu (unticking means "do not install it"). Found in the first real install.
- **Gate no longer flashes on every command in Claude Code's auto mode**: it waits a few seconds, and opens only when the automatic check leaves the decision to the user.
- **GTK 3 apps read the theme's border colours**: the stylesheet used a colour form only GTK 4 understands, and GTK 3 apps logged a parsing error.
- **Applying a theme from another workspace no longer copies the first wallpaper onto it.** The per-workspace wallpapers extension took the desktop's wallpaper, which Kinobu set to the first one, as the user's pick for the workspace on screen; now Kinobu only writes the extension's list and restarts it, and the extension shows the right wallpaper itself.
- **The skill describes virt-manager as Kinobu sets it up** (the `libvirt` group) and no longer mentions GNOME Boxes.

## [0.1] — 2026-11-17

Kinobu is the successor of Orkestr OS, rebuilt from scratch. It does the same job, with a new name, a tidier inside and a setup that is easier to follow. A computer set up with Orkestr cannot be migrated: Kinobu is installed on a fresh Ubuntu.

### Added

- **A quick check before anything else**, with the KINOBU wordmark: requirements that stop the setup with a plain explanation, and hardware facts that only inform. It asks for no password.
- **Full-screen menus** drawn by Kinobu instead of `whiptail`: sections, a short description of each app, progress dots, B to go back and Q to quit.
- **A last confirmation**: your software, the numbered list of what is going to happen and one question.
- **A clean screen**: the output of apt, snap and the downloads goes to the log; the screen shows each step and a single live line.
- **Two layers.** Kinobu's own programs are installed once in the system (`/usr/local`), in `programs/`, `skills/`, `i18n/`, `data/` and `src/`; each user keeps only what is personal.
- **`kinobu --user`** and a login entry: a new user, and every other user after an update, gets their part at their next login, without a password.
- **Modes**: no option shows the help; `--install`, `--update`, `--manual` (choose the blocks in a list), `--check` and `--user`.
- **Python as a system base**: `pip`, `venv` and the `python` command are always installed.
- **Tests in the repository**: `bash tests/run.sh` covers the command line, the check, the menus and a whole simulated setup, update and second user.
- **New branding**: the rings logo, the wordmark with the rings as its O, and a fastfetch summary with a tagline that changes on every run and follows your accent colour.

### Changed

- **Agents**: Claude Code (the only one preselected), Codex and Antigravity CLI. Cursor CLI, opencode and Hermes Agent are no longer installed or integrated; Cursor stays as an editor.
- **Catalogue**: 39 choices in four menus. GNOME Boxes and MKVToolNix are gone and virt-manager sits next to Docker.
- **The voice assistant is called Zen** (it was Axis); it is the same app.
- **An agent's installer that fails no longer stops the setup**: Kinobu warns and goes on. Installers are downloaded to a file and then run, never piped straight from the internet.
- **Weather**: the city comes from the time zone chosen when Ubuntu was installed; location services are not used and no city is fixed in the script.
- **App grid**: the Settings folder has a translated name like System and Utilities, and the grid is arranged at the end of the run.
- **The calculator is pinned in the dock.**
- **The script is split** into a short `kinobu.sh` and one file per part in `lib/`.

### Fixed

- **Approval window**: it opened with the keyboard focus on the Allow button, so a Space or Enter you were typing could approve a command. No button starts with the focus now, and nothing counts in the window's first moment on screen.
- The internet check tried a single server and failed now and then; it tries several.
- A damaged download of llama.cpp (Qwen3-TTS) stopped the setup; it is reported and the setup goes on.
- The search for recommended drivers showed nothing for several seconds; it shows the live line.

### Removed

- `--only`, `--skip`, `--from`, `--list` and `--yes` (use `--manual`).
- `zenity` and the leftovers of Orkestr's older versions.
