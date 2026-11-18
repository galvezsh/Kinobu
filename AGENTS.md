# AGENTS.md — Kinobu

Context for AI agents working on this repository. Humans: read [README.md](README.md) (what it is and why) and [GUIDE.md](GUIDE.md) (how it works). This file records how to work here, why things are the way they are and the traps already found.

## 1. What this project is

**Kinobu 0.2 (in development)** by **Alberto Gálvez (agalvezsh)**, AGPL-3.0-or-later. One idempotent Bash script (`kinobu.sh` plus `lib/`, about 2,700 lines, and the files it installs in `files/`) that turns a fresh **Ubuntu 26.04 LTS desktop (GNOME on Wayland, amd64)** into an agentic workstation. Inspired by Omarchy, on a stable base and a traditional desktop.

It is the successor of **Orkestr OS**, rebuilt from scratch in November 2026: the blocks, the installed apps and most facts below come from it. There is no migration from Orkestr. Kinobu must stay **generic**: no dependency on specific hardware, on files of the author's machine or on personal data.

**State:** installed and updated for real only on the author's computer (2026-11-18); the rest in simulation. See [ROADMAP.md](ROADMAP.md) before assuming something works on a real system.

## 2. Working with the author

- The author speaks **Spanish**: talk to them in Spanish. **Everything in the repository is in English.**
- They work **step by step**: explain, propose and wait for a go-ahead before anything beyond a small change.
- The setup is for people **new to the terminal and to Linux**: plain words on screen, no jargon, a tidy and good-looking output.
- They want a **clear hierarchy** in what is installed and **functions grouped by purpose**.
- They set up git and sign commits themselves: do not `git init`, commit or push unless asked.
- **Never run `kinobu.sh --install`, `--update` or a block against the author's real system.** Use the tests (§7).
- Verify facts (installer URLs, file formats, config paths) against official sources, and say what was and was not verified.

## 3. Layout

| Path | Purpose |
|---|---|
| `kinobu.sh` | Configuration (name, version, prefix), the modes and the flow of a run |
| `lib/ui.sh` | Colours, the wordmark, status lines, `ui_checklist` (the full-screen list) |
| `lib/check.sh` | The system check; sets `HAS_V3`, `HAS_KVM`, `HAS_DGPU` |
| `lib/blocks.sh` | `BLOCKS`, titles, descriptions, `BLOCK_FN`, `block_fn`, `block_desc` |
| `lib/software.sh` | `SOFTWARE` (the catalogue), the menus, `chosen`, `planned`, `offered` |
| `lib/core.sh` | Messages, the log, `run`, `download`, sudo, `put_*`, `render`, apt, `install_system`, `run_plan`, `finish_run` |
| `lib/apps.sh`, `ai.sh`, `drivers.sh`, `services.sh`, `user.sh`, `desktop.sh`, `shortcuts.sh`, `context.sh` | One block each (`apps.sh` has `apt` too; `ai.sh` has Willow). Each starts with its own configuration |
| `lib/look.sh` | Part of the `desktop` block: installs the theme engine, Seasons, the themes and the icon and cursor packs (`LOOK_PACKS`), and applies each user's look |
| `lib/update.sh` | `UPDATE_BLOCKS`, `UPDATE_FN`, `UPDATE_DESC` and the update functions |
| `files/` | Everything installed as a file: `apt/`, `shell/`, `desktop/`, `apps/`, `i18n/`, `agents/`, `skill/`, `subagents/`, `services/`, `branding/`. `@NAME@` marks are filled by `render` |
| `tools/branding.py` | Draws the rings and the wordmark: `files/branding/{logo,wordmark}.txt`, `files/shell/fastfetch-logo.txt` and `assets/kinobu-{dark,light}.svg` |
| `tools/logo.py` | Draws the vector logo: `assets/logo{,-small}{,-light}.svg` |
| `assets/` | The README banner and the logo |
| `files/themes/` | The factory themes (one folder each, `theme.toml`) and `templates/` (the palette layer of the GTK CSS). The engine is `files/apps/kinobu_theme.py`, the app `files/apps/seasons.py` |
| `tests/` | `run.sh`, `pty-run.py`, `approve-focus.py`, `themes-apply.sh`, `desktop-shots.sh` with `scenes/`, and `stubs/` |
| `docs/` | Designs of what is not built yet: `themes.md` |
| `README.md`, `GUIDE.md`, `ROADMAP.md`, `CHANGELOG.md` | Human documentation. Update the changelog with every change and keep the roadmap in line |
| `CLAUDE.md` | `@AGENTS.md` |

## 4. How a run works

`main`: `ui_init` → `parse_args` (sets `ACTION`: help, version, check, install, update, manual, user) → banner → `check_system` → the menus (`ask_software`) → `confirm_start` → `run_plan`.

`run_plan`: log and temp folder → no-downgrade guard → `sudo_start`, `backup_settings`, `bootstrap`, `install_system` (the last three and sudo only when `SYSTEM_WRITES`) → each block of `PLAN` through `block_fn` → `finish_run` (app grid, welcome tour, versions, next steps) → `print_summary`.

- `RUN_KIND` is `setup` or `update` and chooses between `BLOCK_FN` and `UPDATE_FN`. `--user` on a user already set up is an update.
- `SYSTEM_WRITES=false` (`--user`) makes `put_file` a no-op and skips everything that needs sudo.
- Two layers: `PREFIX` (`/usr/local`, or `KINOBU_PREFIX`), `SYSTEM_DIR=$PREFIX/share/kinobu` with `programs/`, `skills/`, `i18n/`, `data/`, `src/`, `themes/`, `version`; `BIN_DIR=$PREFIX/bin`. Per user: `CONFIG_DIR`, `DATA_DIR`, `STATE_DIR`.
- The login entry runs `kinobu-launch user-setup`, which opens `kinobu --user` when `$SYSTEM_DIR/version` and `~/.config/kinobu/version` differ.

## 5. Conventions and helpers (follow them)

- `set -Eeuo pipefail`; `on_error` prints the block, the step and the last lines of the log; `cleanup` leaves the full-screen list, stops the sudo keep-alive and removes the temp folder.
- Output: `step` (→), `ok` (✔), `info` (·), `warn` (!, collected for the summary), `die`, `need_reboot`, `NEXT_STEPS+=(...)`. Write for someone who has never used Linux.
- **`run COMMAND...`** sends a command's output to the log and shows the live line. It runs in the background: never wrap a function that sets variables. `download URL DEST` shows the megabytes.
- **`root COMMAND`** is `sudo -n`: sudo is asked once (`sudo_start`) and never in the middle of a command. **`sys TARGET COMMAND`** uses sudo only when `TARGET` is not writable (tests use a prefix of their own).
- **`put_file DEST [MODE]`** (system) and **`put_user_file DEST`** write stdin only when the content changes and set `CHANGED`. Feed them with `<<<` or `< <(...)`, **never with a pipe** (a pipe runs them in a subshell and `CHANGED` is lost). `put_block FILE BEGIN END CONTENT` for managed blocks; `edit_json FILE FILTER` for JSON.
- **`render FILE [NAME | NAME=value]...`** prints `files/FILE` with its `@NAME@` marks filled. A variable used only through `render` needs a `# shellcheck disable=SC2034` with the reason.
- **Never `if cmd | grep -q …`** with pipefail: grep leaves early and the pipeline fails. Use `has_line LINE "$(cmd)"` or `[[ "$(cmd)" == *text* ]]`.
- Prefer `if …; then …; fi` over `cond && action`: a false `&&` as the last statement of a function trips `set -e`. Command substitutions that may fail need `|| true`.
- Idempotency: check before acting, write only on change, never duplicate blocks, respect what is the user's.
- Never touch disks or partitions. Never add the user to the `docker` or `libvirt` groups. Never change the agents' permission settings (the one exception is the read-only subagent's `permissionMode: auto` in Claude Code).
- Never put the user's e-mail address or other personal data in a request, a `User-Agent` or a test.
- Do not kill processes with `pkill -f PATTERN` from a command whose own text contains the pattern: it kills its own shell.

## 6. Decisions and why

| Topic | Decision | Reason |
|---|---|---|
| Form | A script, not a `.deb` or an ISO | Kinobu is a layer over Ubuntu, not a distribution; a script is easy to read, change and extend |
| Two layers | Own programs in `/usr/local`, personal files in `$HOME`, `kinobu --user` and a login entry | Other users of the computer get Kinobu and its updates (as Omarchy 4 does with `/usr/share`, `/etc/skel` and per-user migrations). No numbered migrations: the blocks can be repeated, so re-applying the user's part is enough |
| System files and agents | Hooks only read and run them; no special permission | And an agent cannot edit the window that approves its own commands |
| Agents | Only Claude Code for now (preselected); Codex and Antigravity CLI later | One agent complete before the next: each costs an installer, skill, note, subagent, hooks and tests. The code keeps one list per agent (`AGENT_TOOLS` and the maps in `lib/context.sh`) so others can be added back. Cursor and the Antigravity IDE stay as plain editors |
| Modes | No option shows the help; `--install`, `--update`, `--manual`, `--check`, `--user`; no `--yes` | An explicit choice for people new to the terminal |
| One terminal | The check, the menus and the setup in the same window | A second window was tried on paper and dropped: sudo does not carry over and closing it would cut apt |
| Quiet screen | Command output in the log, one live line on screen | The author wants it visual, not a wall of text |
| A failing agent installer | Warns and goes on | A vendor's site being down must not stop the whole setup |
| Weather | City from the time zone (`zone1970.tab` + libgweather) | No location services (privacy), no city fixed in the script |
| App grid | Only the three folders first, with their apps taken out of any other folder; the apps after them as GNOME or the user places them. A `.directory` file gives the Settings folder a translated name; arranged at the end of the run. The welcome tour is not in the grid (Super+F1) | The folders mixed languages and did not stay first in Orkestr. On the first real install GNOME dropped Kinobu's Settings folder: an older folder held two of its apps, and an app lives in one folder only. Ordering the apps was dropped: the user arranges them |
| Approval window | No button has the initial focus; nothing counts for 0.8 s | The window takes the keyboard on purpose; in Orkestr the focus landed on Allow |
| Voice assistant | **Willow**, Kinobu's voice assistant: three powers (Quick: Haiku low effort, default; Smart: Haiku high; Strong: Sonnet medium), `kinobu-do` as its only way to change things, the screen through GNOME's portal, the skill read on demand, read-only background checks on Sonnet. It keeps nothing about the user and never asks for their name; a fixed friendly manner, with an optional line in its settings | Cheap enough for every day; privacy, since Kinobu may be sold and run on private servers; one narrow, auditable command for actions |
| Look | Themes (`docs/themes.md`): each has palettes, every one dark or light and paired with one of the other mode (the dark-style switch); a theme changes mode, accent, app colours, icons, cursor, window buttons, wallpapers and terminal. Every factory palette passes `kinobu-theme validate --strict` (text 7, secondary text 4.5, accent 3). Seasons chooses them; its other sections have a "Follow the theme" switch, and the user's picks (icons, cursor, fonts, wallpapers) in `~/.config/kinobu/look.toml` win over the theme's. New users start with the Kinobu theme. Packs: APT when Ubuntu has them, `LOOK_PACKS` (ready-made, pinned, checked) otherwise, all in the system; packs that only ship sources wait for `kinobu-assets`. No GNOME Shell theme; GNOME Tweaks is not installed. Four wallpapers per theme, by Wallhaven id, downloaded by the user when the theme is applied | One look per user over shared packs; the repository holds no pictures (Orkestr's were copyrighted) |
| Always installed | Python (`pip`, `venv`, `python`), Node.js, GraalVM, the GNOME apps, Handy | The author's choice of a professional base |
| App names | A visible name in English, the same in every language and never translated (Sprout, Trail, Echo, Gate, Willow, Seasons); technical app IDs (`os.kinobu.<Function>`) and commands (`kinobu-<function>`, `kinobu-launch <function>`) underneath | Agents, hooks and scripts read the technical names, which say what each app does; a visible name can change by editing the `.desktop` file and the window title. Table in GUIDE |
| Versions | 0.x while in development (0.1 on 2026-11-17, 0.2 on 2026-11-18), 1.0 when published; fruit names from 1.0 | A tree that grows bears fruit |

## 7. Tests

`bash tests/run.sh` must stay green, ShellCheck included (`uvx --from shellcheck-py shellcheck -x -S style`).

- **Stubs** (`tests/stubs/`, first in `PATH`): `sudo` (records the command, runs nothing), `curl` (writes `: stub` to `-o` files), `git`, `systemctl`, `gnome-extensions`, `xdg-settings`, `pkill`, `pgrep`, `setsid`, `fc-list`, `claude`, `uv`.
- **Fake home** (`HOME=$(mktemp -d)`) and **its own prefix** (`KINOBU_PREFIX`).
- **Its own dconf database**: `DCONF_PROFILE=<file with "user-db:kinobutest">` **and** `XDG_CONFIG_HOME=<the real ~/.config>`. Without both, gsettings writes the real settings. Delete `~/.config/dconf/kinobutest` afterwards; **never run `dconf reset -f /`** to clean up.
- **A private D-Bus is not isolation by itself.** `dbus-run-session` starts services such as `dconf-service` with the environment of the bus, not of the script inside it: set the fake `HOME` and XDG folders **before** it (`env -i HOME=… XDG_CONFIG_HOME=… dbus-run-session -- …`). On 2026-11-17 a test session set them inside and wrote the author's real settings (extensions, notifications, theme, Ptyxis profiles), restored from Orkestr's backup. `tests/run.sh` and `tests/desktop-shots.sh` compare the real database before and after.
- **Never stop test apps by name** (`pkill -x ptyxis` closes the user's own terminals too): keep their PIDs. A bare `wait` also waits for the shell started in the background.
- **Any test that runs blocks must have all three.** A test written when only two blocks existed ran every later block against the real settings database until it was isolated.
- **Menus**: `tests/pty-run.py KEY... -- COMMAND` types keys in a pseudo-terminal; `@TEXT` waits until TEXT is on screen.
- **Whole runs**: source `kinobu.sh`, override `sudo_start` and `install_voice`, set `ACTION`, `RUN_KIND`, `PLAN`, `CHOSEN` and call `run_plan`.
- **Willow for real**: install into a temp prefix with `download` overridden to hard-link the models the machine already has, and `UV_CACHE_DIR`/`UV_PYTHON_INSTALL_DIR` pointing at the real ones.
- **Windows on the real desktop**: `KINOBU_TEST_WINDOWS=1 bash tests/run.sh` also opens the real Gate for a moment (`tests/approve-focus.py`, the keyboard-focus guard); without it that check is skipped, so a plain run never flashes a window.
- **A real desktop, for looking**: `bash tests/desktop-shots.sh SCENE OUT_DIR` runs a headless GNOME Shell with a fake home and takes screenshots (`tests/scenes/themes.sh`: Seasons, Files and a terminal in several themes).
- **Claude Code for real**: a prefix made read-only, the generated `settings.json` passed with `claude -p --settings`, `KINOBU_NOTIFY_MIN_SECONDS=0`, then look for the marks in `$XDG_RUNTIME_DIR/kinobu-notify/`.

## 8. Verified facts

Carried over from Orkestr (October–November 2026); re-check when they may have changed. The Codex and Antigravity CLI facts are kept for when they are integrated again.

- **Installers**: Claude Code `https://claude.ai/install.sh`; Codex `https://chatgpt.com/codex/install.sh` (`CODEX_NON_INTERACTIVE=true`); Antigravity CLI `https://antigravity.google/cli/install.sh` (binary `agy`); Ollama `https://ollama.com/install.sh`; LM Studio `https://lmstudio.ai/download/latest/linux/x64?format=deb` (package `lm-studio`); uv `https://astral.sh/uv/install.sh`. All install in `~/.local/bin` except Ollama and LM Studio.
- **Skills folders**: Claude Code `~/.claude/skills`; Codex `~/.agents/skills` (legacy `~/.codex/skills`); Antigravity `~/.gemini/config/skills`. **Global instructions**: `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`.
- **Hooks**: Claude Code `~/.claude/settings.json` `hooks.{Event}[{matcher, hooks[{type, command, timeout}]}]`; `PermissionRequest` answers `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"|"deny"}}}`. Codex `~/.codex/hooks.json`, same shape, runs hooks once trusted with `/hooks`. Antigravity `~/.gemini/config/hooks.json`.
- **GNOME 50 shows no buttons in notifications**, hence the approval window. A notice tied to an app vanishes when its sender leaves the bus, so notices are sent without one.
- **Google Chrome's `.deb` adds its own repository**: do not write a second source. **Cursor's** source file must match what its package writes.
- **Oh My Bash's installer replaces `~/.bashrc`**: it is cloned instead. Its `powerbash10k` theme needs a Nerd Font.
- **GNOME custom keybinding commands get no shell or `~` expansion**: always absolute paths.
- **`gsettings`/`dconf` need the session bus**; under a fake home they still write the real database unless `DCONF_PROFILE` and `XDG_CONFIG_HOME` are both set.
- **fastfetch 2.57**: the `command` module runs with `/bin/sh`; logo files take `$1`–`$9` colour marks; JSON `\uXXXX` escapes keep Nerd Font icons safe from editors.
- **libgweather**: `GWeather.Location.get_world().find_nearest_city(lat, lon).serialize()` gives the value GNOME Weather stores.
- **Ubuntu's automatic updates** hold the apt lock without warning; `/proc/locks` shows who (no sudo).
- **Willow**: `handy -f FILE.wav --json` transcribes headless; `claude -p` with `--setting-sources ""`, `--strict-mcp-config`, `--disable-slash-commands`, `--no-session-persistence` and `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` keeps the context tiny; Kokoro int8 sounds metallic (use fp32); Qwen3-TTS runs on llama.cpp's Vulkan build.
- **GTK 4.22 / libadwaita 1.9 (Ubuntu)**: the user's `~/.config/gtk-4.0/gtk.css` overrides libadwaita's colour variables, and `@media (prefers-color-scheme: …)` works in it; open apps do not reload it. Ubuntu's libadwaita adds `--yaru-accent-*` variables.
- **Ptyxis 50.1**: `interface-style` defaults to `'dark'`; user palettes in `~/.local/share/org.gnome.Ptyxis/palettes/`; its bundled palettes are read with `gresource extract /usr/bin/ptyxis /org/gnome/Ptyxis/palettes/<name>.palette`.
- **Icon and cursor packs** (2026-11-17): Papirus is in Ubuntu's archive (`apt download` gets the `.deb` without root, `dpkg-deb -x` unpacks it); Fluent and WhiteSur icons only ship sources assembled by their `install.sh`; Bibata cursors ship ready-made `.tar.xz` release files; WhiteSur cursors are ready-made in the repository's `dist/`. X cursor files are read in Python (`Xcur`, image chunks `0xfffd0002`, BGRA premultiplied). GNOME 50's Adwaita icon theme is marked `Hidden` for a reason: its app icons come from AdwaitaLegacy, not installed by default, so it is not offered. An extension's settings schema lives in its own folder (`<extension>/schemas`): `gsettings` and `Gio.Settings` only see it with that folder as a schema source (`--schemadir`, `Gio.SettingsSchemaSource.new_from_directory`).
- **elementary's icons** (Ubuntu's `elementary-icon-theme`): GTK finds its symbolic icons, but some of them (Recent, Trash in Files' sidebar) are drawn blank in GNOME; no theme uses it, it is only offered in Seasons. **Numix Circle** needs `numix-icon-theme` (APT pulls it in). The packages register cursors as `x-cursor-theme` alternatives with low priorities: Adwaita (90) stays the default.
- **`python3-gi-cairo` is not installed by default**: draw with GtkSnapshot. In PyGObject, `Graphene.Rect().init(...)` and `Gsk.RoundedRect().init_from_rect(...)` return unusable copies: initialise the object in place and use it.
- **Ubuntu Dock's Show Apps icon** (2026-11-18): no setting; `appIcons.js` asks for the icon name `view-app-grid-<session mode>-symbolic` (`view-app-grid-ubuntu-symbolic`), which only Yaru ships. Kinobu puts its own in `/usr/local/share/icons/Yaru` (searched before `/usr/share`) and `hicolor` (for the other packs): a folder without `index.theme` only adds icons to the theme of that name, so the theme engine must not take it for a theme.
- **Wallhaven's API** (2026-11-18): `https://wallhaven.cc/api/v1/search` answers without a key for safe pictures; `purity=100`, `categories=100`, `ratios=landscape`, `atleast=WxH`, `colors=` (a fixed list of 29 hex values), `sorting=random|relevance|toplist|date_added|favorites`, `page`, and `seed` for random pages. Each result has `path` (the file), `thumbs.large`, `resolution`, `purity`. 45 requests a minute (429 after).
- **Screenshots on GNOME 50** (2026-11-18): the Shell's screenshot D-Bus API refuses every caller outside its allow-list, `gnome-screenshot` included (it then falls back to X11 and hangs). The screenshot portal (`org.freedesktop.portal.Screenshot`, `interactive: false`) works: GNOME asks once "Allow apps to take screenshots?" and stores the answer (permission store table `screenshot`); `XDG_CURRENT_DESKTOP` must name GNOME or the portal has no backend. Brightness has no public D-Bus setter (only `org.gnome.Shell.Brightness` dimming): `brightnessctl` on laptops.
- **Claude Code 2.1.326 flags used by Willow**: `--effort`, `--tools`, `--allowedTools` (`Read(//absolute/path/**)` rules), `--system-prompt`, `--setting-sources ""`, `--no-session-persistence`, `--input-format/--output-format stream-json`; no `--max-turns`.
- **Omarchy 4** (read on 2026-11-16): packaged in `/usr/share/omarchy`, `/etc/skel` seeds new users, per-user migrations with a notice at login, themes as `colors.toml` plus templates, the active theme in each user's state folder.

## 9. How to change common things

- **Offer an app**: one line in `SOFTWARE` (`lib/software.sh`); a new vendor source also needs a line in `REPOS` and its file in `files/apt/`. Update the table in GUIDE.
- **Add a shortcut**: one line in `SHORTCUTS` (`lib/shortcuts.sh`); `launch:<x>` also needs a `case` in `files/apps/kinobu-launch`; a clash with a GNOME default goes in `SHORTCUT_RELEASES`.
- **Add an agent**: `SOFTWARE`, `AI_INSTALLERS` and `AGENT_TOOLS` (`lib/ai.sh`), then the skills folder, the note, the subagent and the hooks in `lib/context.sh`, its name in `files/agents/kinobu-notify` and a row in `files/skill/agents.md`.
- **Add a text or a language**: `files/i18n/<language>.json` (`en.json` must have every key).
- **Add a block**: its function, then `BLOCKS`, `BLOCK_TITLE`, `BLOCK_DESC`, `BLOCK_FN` and, if it runs on updates, `lib/update.sh`.
- **Change the logo or the wordmark**: `python3 tools/branding.py` rewrites the terminal branding and the README banner; `python3 tools/logo.py`, the vector logo.
- **Release**: bump `APP_VERSION` and the header of `kinobu.sh`, date the entry in `CHANGELOG.md`, update the README line and the roadmap. What must reach computers already set up belongs in a function `UPDATE_FN` runs.
