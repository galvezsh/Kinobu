# AGENTS.md — Kinobu

Context for AI agents working on this repository. Humans: read [README.md](README.md) (what it is and why) and [GUIDE.md](GUIDE.md) (how it works). This file records how to work here, why things are the way they are and the traps already found.

## 1. What this project is

**Kinobu 0.3.1 (in development)** by **Alberto Gálvez (agalvezsh)**, AGPL-3.0-or-later. One idempotent Bash script (`kinobu.sh` plus `lib/`, about 2,700 lines, and the files it installs in `files/`) that turns a fresh **Ubuntu 26.04 LTS desktop (GNOME on Wayland, amd64)** into an agentic workstation. Inspired by Omarchy, on a stable base and a traditional desktop.

It is the successor of **Orkestr OS**, rebuilt from scratch in November 2026: the blocks, the installed apps and most facts below come from it. There is no migration from Orkestr. Kinobu must stay **generic**: no dependency on specific hardware, on files of the author's machine or on personal data.

**State:** installed and updated for real only on the author's computer (since 2026-11-18; 0.3 on 2026-11-19, 0.3.1 on 2026-11-21); the rest in simulation. See [ROADMAP.md](ROADMAP.md) before assuming something works on a real system.

## 2. Working with the author

- The author speaks **Spanish**: talk to them in Spanish. **Everything in the repository is in English.**
- They work **step by step**: explain, propose and wait for a go-ahead before anything beyond a small change.
- The setup is for people **new to the terminal and to Linux**: plain words on screen, no jargon, a tidy and good-looking output.
- They want a **clear hierarchy** in what is installed and **functions grouped by purpose**.
- **Keep the documentation up to date with every change, without being asked.** The author asks for changes and does not repeat that the documents must follow: that is part of every change, in the same piece of work, never "later". Before saying a change is done, go through this list and update what it touches:

  | File | Update it when |
  |---|---|
  | `CHANGELOG.md` | Always: one line per change a user would notice, under the version in development (Added, Changed, Fixed, Removed) |
  | `ROADMAP.md` | An item is done (tick it, then it goes to the changelog), a new task or idea comes up, or a plan changes |
  | `GUIDE.md` | How something works or is used changes: an app, a shortcut, a setting, a mode, a file Kinobu writes |
  | `README.md` | What Kinobu is or offers changes, its state, or the version |
  | `AGENTS.md` | A decision and its reason (§6), a trap or a verified fact (§8), the layout (§3), a convention or a test |
  | `files/skills/*/` | What an agent on an installed computer must know changes (`kinobu`: the system; `kinobu-dev`: developing programs) |
  | `docs/` | The design of something not built yet changes |

  Then tell the author in the answer which documents were updated, and which were not because nothing in them changed. If a change is only in the repository, say so too: the author's computer gets it when they run `bash kinobu.sh --update` themselves.
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
| `files/` | Everything installed as a file: `apt/`, `shell/`, `desktop/`, `apps/`, `i18n/`, `agents/`, `skills/`, `subagents/`, `services/`, `branding/`. `@NAME@` marks are filled by `render` |
| `tools/branding.py` | Draws the rings and the wordmark: `files/branding/{logo,wordmark}.txt` (the reduced logo, two rings), `files/shell/fastfetch-logo.txt` (the full logo, four rings, 21 rows: fewer rows blur the thin rings) and `assets/kinobu-{dark,light}.svg` |
| `tools/logo.py` | Draws the vector logo: `assets/logo{,-small}{,-light}.svg` |
| `tools/login_background.py` | Draws the login screen's background: `files/branding/login-background.jpg` (the wordmark blurred on a dark gradient) |
| `tools/plymouth.py` | Draws the boot splash's frames: `files/branding/plymouth/throbber-*.png` (the logo turning, 96 px, under the maker's) and `bgrt-fallback.png`; `--preview FILE.gif` shows the whole screen with this computer's maker logo |
| `assets/` | The README banner and the logo |
| `files/themes/` | The factory themes (one folder each, `theme.toml`) and `templates/` (the palette layer of the GTK CSS). The engine is `files/apps/kinobu_theme.py`, the app `files/apps/seasons.py` |
| `tests/` | `run.sh`, `pty-run.py`, `approve-focus.py`, `themes-apply.sh`, `desktop-shots.sh` with `scenes/`, and `stubs/` |
| `docs/` | Designs of what is not built yet: `themes.md` |
| `README.md`, `GUIDE.md`, `ROADMAP.md`, `CHANGELOG.md` | Human documentation, kept up to date with every change (§2) |
| `CLAUDE.md` | `@AGENTS.md` and `@CONTEXT.md` |
| `CONTEXT.md` | Where the work stands, for agents (English, out of git): read it first, rewrite it after each change worth telling |

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
| Agents' instructions | The note (always loaded) is short and says when to load each skill; the system skill `kinobu` is a short index with guides read on demand; developing programs is a skill of its own, `kinobu-dev`. Skills describe what is: no versions (checked live) and no plans; a test checks it, and the sizes. Claude Code gets the Concise output style unless the user chose one, and `verbose` always off (it only changes what the terminal shows, not the tokens) | Every word of the note is paid in every conversation, the skills only when used; two skills so that programming never loads the system's guides. Versions written into the skill went stale (2026-11-20) |
| Boot splash | The maker's logo kept, with Kinobu's small rings turning under it (as Windows does), on Ubuntu's own two-step module, chosen by hand (`update-alternatives --set`), the start-up image rebuilt only when the frames change | The author wants it familiar and not empty: a large logo alone on black was tried and dropped. Ubuntu's minor updates must never take it back (decided on 2026-11-19); a hand-made choice is the one thing package scripts respect. GRUB stays untouched |
| Look | Themes (`docs/themes.md`): each has palettes, every one dark or light and paired with one of the other mode (the dark-style switch); a theme changes mode, accent, app colours, icons, cursor, window buttons, wallpapers and terminal. Every factory palette passes `kinobu-theme validate --strict` (text 7, secondary text 4.5, accent 3), and the engine makes the terminal's colours legible itself (4.5, text 7), since most Ptyxis palettes, the light ones above all, fall short. Seasons chooses them; its other sections have a "Follow the theme" switch, and the user's picks (icons, cursor, fonts, wallpapers) in `~/.config/kinobu/look.toml` win over the theme's. New users start with the Kinobu theme. Packs: APT when Ubuntu has them, `LOOK_PACKS` (ready-made, pinned, checked) otherwise, all in the system; packs that only ship sources wait for `kinobu-assets`. No GNOME Shell theme; GNOME Tweaks is not installed. Four wallpapers per theme, by Wallhaven id, downloaded by the user when the theme is applied | One look per user over shared packs; the repository holds no pictures (Orkestr's were copyrighted) |
| Always installed | Python (`pip`, `venv`, `python`), Node.js, GraalVM, the GNOME apps, Handy | The author's choice of a professional base |
| App names | A visible name in English, the same in every language and never translated (Sprout, Trail, Echo, Gate, Willow, Seasons); technical app IDs (`os.kinobu.<Function>`) and commands (`kinobu-<function>`, `kinobu-launch <function>`) underneath | Agents, hooks and scripts read the technical names, which say what each app does; a visible name can change by editing the `.desktop` file and the window title. Table in GUIDE |
| Versions | 0.x while in development (0.1 on 2026-11-17, 0.2 on 2026-11-18, 0.3 on 2026-11-19, 0.3.1 on 2026-11-21; a third number for fixes and small additions), 1.0 when published; fruit names from 1.0 | A tree that grows bears fruit |

## 7. Tests

`bash tests/run.sh` must stay green, ShellCheck included (`uvx --from shellcheck-py shellcheck -x -S style`).

- **Stubs** (`tests/stubs/`, first in `PATH`): `sudo` (records the command, runs nothing), `curl` (writes `: stub` to `-o` files), `git`, `systemctl`, `gnome-extensions`, `xdg-settings`, `pkill`, `pgrep`, `setsid`, `fc-list`, `claude`, `uv`.
- **Fake home** (`HOME=$(mktemp -d)`) and **its own prefix** (`KINOBU_PREFIX`).
- **Its own dconf database**: `DCONF_PROFILE=<file with "user-db:kinobutest">` **and** `XDG_CONFIG_HOME=<the real ~/.config>`. Without both, gsettings writes the real settings. Delete `~/.config/dconf/kinobutest` afterwards; **never run `dconf reset -f /`** to clean up.
- **A private D-Bus is not isolation by itself.** `dbus-run-session` starts services such as `dconf-service` with the environment of the bus, not of the script inside it: set the fake `HOME` and XDG folders **before** it (`env -i HOME=… XDG_CONFIG_HOME=… dbus-run-session -- …`). On 2026-11-17 a test session set them inside and wrote the author's real settings (extensions, notifications, theme, Ptyxis profiles), restored from Orkestr's backup. `tests/run.sh` and `tests/desktop-shots.sh` compare the real database before and after.
- **A dconf database name cannot have a dash** (`user-db:kinobu-test`): dconf puts it in a D-Bus object path, the write fails and `Gio.Settings.sync()` waits for ever. Use letters only (`kinobutest`).
- **Never stop test apps by name** (`pkill -x ptyxis` closes the user's own terminals too): keep their PIDs. A bare `wait` also waits for the shell started in the background.
- **Any test that runs blocks must have all three.** A test written when only two blocks existed ran every later block against the real settings database until it was isolated.
- **Menus**: `tests/pty-run.py KEY... -- COMMAND` types keys in a pseudo-terminal; `@TEXT` waits until TEXT is on screen.
- **Whole runs**: source `kinobu.sh`, override `sudo_start` and `install_voice`, set `ACTION`, `RUN_KIND`, `PLAN`, `CHOSEN` and call `run_plan`.
- **Willow for real**: install into a temp prefix with `download` overridden to hard-link the models the machine already has, and `UV_CACHE_DIR`/`UV_PYTHON_INSTALL_DIR` pointing at the real ones.
- **Windows on the real desktop**: `KINOBU_TEST_WINDOWS=1 bash tests/run.sh` also opens the real Gate for a moment (`tests/approve-focus.py`, the keyboard-focus guard); without it that check is skipped, so a plain run never flashes a window.
- **A real desktop, for looking**: `bash tests/desktop-shots.sh SCENE OUT_DIR` runs a headless GNOME Shell with a fake home and takes screenshots (`tests/scenes/themes.sh`: Seasons, Files and a terminal in several themes; `tests/scenes/own-themes.sh`: the user's own themes, the menu, Duplicate and the colour editor).
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
- **The login screen (GDM)** (2026-11-18): GNOME's `gdm` session mode loads `gdm.css` from `/usr/share/gnome-shell/gdm-theme.gresource`, an `update-alternatives` link (Yaru 15, GNOME 10). Ubuntu's grey is `#lockDialogGroup { background-color: #222222 }`. `glib-compile-resources` is in `libgio-2.0-dev-bin`. St reads `background-image: url("resource:///…")` with `background-size: cover`. To look at a built theme without root: `GNOME_SHELL_DATADIR=<folder>` with links to `/usr/share/gnome-shell/*` and the theme replaced (in `--mode=ubuntu` the theme is `theme/Yaru/gnome-shell-theme.gresource`), then an `St.Widget({name: 'lockDialogGroup'})` over the stage. The `gdm` mode loads no extensions, so the test harness cannot capture it directly. The logo under the user list is `org.gnome.login-screen logo`, which Ubuntu sets in `10_ubuntu-settings.gschema.override` (`ubuntu-logo-text-dark.svg`); GDM's own settings database is compiled from `/usr/share/gdm/dconf/*` by `/usr/share/gdm/generate-config` on every start (`ExecStartPre` of `gdm.service`), so a file of Kinobu's there (`95-kinobu-login`, `logo=''`) wins over Ubuntu's default and survives its updates (checked with `dconf compile`; not yet seen on a real login). GRUB is left alone (Secure Boot, the author's decision).
- **The boot splash (Plymouth)** (2026-11-19, Ubuntu 26.04, plymouth 24.004.60): the theme is the `update-alternatives` link `/usr/share/plymouth/themes/default.plymouth`, in automatic mode on Ubuntu's `bgrt` (priority 110, from `plymouth-theme-spinner`, whose postinst registers it again on every update and runs `update-initramfs`). A choice made with `--set` is manual and package updates never change it. The initramfs hook (`/usr/share/initramfs-tools/hooks/plymouth`) copies the theme the alternative points to, by its folder's name under `/usr/share/plymouth/themes`, so a theme must live there. `bgrt` is the `two-step` module with the spinner's pictures and the firmware's logo (`UseFirmwareBackground`, read from `/sys/firmware/acpi/bgrt/`, which any user can read; without one, `bgrt-fallback.png` from the theme's folder). Plymouth does not scale pictures to the resolution: it doubles them only on dense screens (`ply_guess_device_scale`; `DeviceScale=` in `/etc/plymouth/plymouthd.conf` or `PLYMOUTH_FORCE_SCALE` force it), so on a large 4K monitor of ordinary density the logo looks half as big; two-step loops the `throbber-*` frames, and looks for its end animation as `startup-animation-`/`shutdown-animation-`, then `animation-`, then `throbber-` (the strings in `two-step.so`): Kinobu ships one `animation-0001.png` so its throbber frames stay the throbber. Seen on a real start on the author's computer (2026-11-19, 1080p, with the maker's logo); not yet without one, on a 4K screen or with an encrypted disk.
- **The workspace-wallpapers extension** (version 4, 2026-11-19): any change of `org.gnome.desktop.background picture-uri` it did not write itself is saved as the wallpaper of the workspace on screen, and on enable it shows the active workspace's wallpaper and writes `picture-uri` itself. So the theme engine switches it off while it writes the list and `picture-uri` (`PausedExtension`: `DisableExtension`/`EnableExtension` on `org.gnome.Shell.Extensions`, never in the tests). GNOME Shell 50 switches extensions off and on asynchronously (`_onEnabledExtensionsChanged` in `extensionSystem.js` awaits each step and records the enabled list only at its end): an "on" sent right after an "off" can be lost, leaving the extension `enabled` but in state 2 (inactive), one wallpaper on every workspace, and a further `EnableExtension` does nothing (it is already in the list). Hence: wait for state 2 after the "off", one second, "on", wait for state 1, once more if not. Seen on the author's computer on 2026-11-19; the fix checked there (three cycles, about 1 s each). Wayland gives other apps no way to know the active workspace.
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
- **Release (a new version)**, all in the same piece of work:
  1. `APP_VERSION` and the header of `kinobu.sh`.
  2. `CHANGELOG.md`: date the version's entry, with a short summary on top and what to run to update.
  3. `README.md`: the version line and the state note.
  4. `ROADMAP.md`: move the version's done items to "Done in X.Y", and open the next version.
  5. `AGENTS.md`: the version and state in §1, and the versions row in §6.
  6. `GUIDE.md` and the skill, if anything there still names the old version.
  7. Check that what must reach computers already set up is in a function `UPDATE_FN` runs.
  8. `bash tests/run.sh`, and propose the commit message (the author commits).
