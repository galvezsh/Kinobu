# Changelog

What changed in each version of Kinobu. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). To bring a computer set up by an earlier version to the latest one, run `bash kinobu.sh --update` (your look is kept).

## [Unreleased] — 0.1, in development

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
- **A design for themes** in `docs/themes.md` (not built yet): families of one or two variants that change the mode, the accent, the app colours in depth, the icons, the cursor, the window buttons, the wallpapers and the terminal.
- **New branding**: the rings logo, the wordmark with the rings as its O, and a fastfetch summary with a tagline that changes on every run and follows your accent colour.

### Changed

- **Agents**: only Claude Code, until its integration is complete; other agents will be added one by one. Codex and Antigravity CLI were integrated during 0.1 and taken out again (installer, skill link, note, subagent and hooks). Cursor CLI, opencode and Hermes Agent are not installed or integrated either; Cursor and the Antigravity IDE stay as editors.
- **Catalogue**: 33 choices in four menus. GNOME Boxes and MKVToolNix are gone and virt-manager sits next to Docker.
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
