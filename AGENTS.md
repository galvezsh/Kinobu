# AGENTS.md — Kinobu

Context for AI agents working on this repository. Humans: read [README.md](README.md) (what it is and why) and [GUIDE.md](GUIDE.md) (how it works). This file records how to work here, why things are the way they are and the traps already found.

## 1. What this project is

**Kinobu 0.3.3 (in development)** by **Alberto Gálvez (agalvezsh)**, AGPL-3.0-or-later. One idempotent Bash script (`kinobu.sh` plus `lib/`, about 2,700 lines, and the files it installs in `files/`) that turns a fresh **Ubuntu 26.04 LTS desktop (GNOME on Wayland, amd64)** into an agentic workstation. Inspired by Omarchy, on a stable base and a traditional desktop.

It is the successor of **Orkestr OS**, rebuilt from scratch in November 2026: the blocks, the installed apps and most facts below come from it. There is no migration from Orkestr. Kinobu must stay **generic**: no dependency on specific hardware, on files of the author's machine or on personal data.

**State:** installed and updated for real only on the author's computer (since 2026-11-18; 0.3 on 2026-11-19, 0.3.1 on 2026-11-21, 0.3.2 on 2026-11-22, 0.3.3 on 2026-11-26); the rest in simulation. See [ROADMAP.md](ROADMAP.md) before assuming something works on a real system.

## 2. Working with the author

- The author speaks **Spanish**: talk to them in Spanish. **Everything in the repository is in English.**
- They work **step by step**: explain, propose and wait for a go-ahead before anything beyond a small change.
- The setup is for people **new to the terminal and to Linux**: plain words on screen, no jargon, a tidy and good-looking output.
- They want a **clear hierarchy** in what is installed and **functions grouped by purpose**.
- **Keep the documentation up to date with every change, without being asked.** The author asks for changes and does not repeat that the documents must follow: that is part of every change, in the same piece of work, never "later". Before saying a change is done, go through this list and update what it touches:

  | File | Update it when |
  |---|---|
  | `CHANGELOG.md` | Always: one line per change a user would notice, under the version in development (Added, Changed, Fixed, Removed). It holds only the current version: when a new one opens, the old entry is replaced (git and the GitHub releases keep the history) |
  | `ROADMAP.md` | Only what is left: a finished item is deleted (it goes to the changelog), a dropped one too (its reason to §6); a new task or idea comes up, or a plan changes |
  | `GUIDE.md` | How something works or is used changes: an app, a shortcut, a setting, a mode, a file Kinobu writes |
  | `README.md` | What Kinobu is or offers changes, its state, or the version |
  | `AGENTS.md` | A decision and its reason (§6), a trap or a verified fact (`docs/facts.md`), the layout (§3), a convention or a test |
  | `files/skills/*/` | What an agent on an installed computer must know changes (`kinobu`: the system; `kinobu-dev`: developing programs; `kinobu-council`: debating decisions) |
  | `docs/` | The design of something not built yet changes, or a fact is verified (`facts.md`) |

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
| `tools/login_sound.py` | Draws Kinobu's login and logout sounds from code (no recordings): `--kinobu` writes `files/branding/sounds/{login,logout}.oga` (variants `chord-tinkle-celesta` and `chord-close-amen-4`, chosen by ear); `--all DIR` writes every variant to listen to |
| `assets/` | The README banner and the logo |
| `files/themes/` | The factory themes (one folder each, `theme.toml`) and `templates/` (the palette layer of the GTK CSS). The engine is `files/apps/kinobu_theme.py`, the app `files/apps/seasons.py` |
| `tests/` | `run.sh`, `pty-run.py`, `approve-focus.py`, `themes-apply.sh`, `desktop-shots.sh` with `scenes/`, and `stubs/` |
| `docs/` | Designs of what is not built yet (`themes.md`) and the verified facts (`facts.md`) |
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
- **`run COMMAND...`** sends a command's output to the log and shows the live line. It runs in the background: never wrap a function that sets variables. `download URL DEST [resume]` shows the megabytes. Every download goes through `CURL` (`lib/core.sh`: gives up under 10 KB/s for 60 s, 20 s to connect, 3 retries): never a bare `curl`. `fetch` (`lib/ai.sh`) keeps a cut `.part` and goes on from it (`-C -`; a server without ranges, curl's error 33, starts again).
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
| Two layers | Own programs in `/usr/local`, personal files in `$HOME`, `kinobu --user` and a login entry | Other users of the computer get Kinobu and its updates (as Omarchy 4 does with `/usr/share`, `/etc/skel` and per-user migrations). No numbered migrations: the blocks can be repeated, so re-applying the user's part is enough. Willow's voices and models, the GNOME extensions, the Nerd Font and Oh My Bash stay in each user's part (2026-11-26, the author's call: the copies for several users are not worth the change) |
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
| Agents' instructions | The note (always loaded) is short and says when to load each skill; the system skill `kinobu` is a short index with guides read on demand; developing programs is a skill of its own, `kinobu-dev`, built on specs before code (spec-driven development: `specs.md`, a guide read before writing a spec). Skills describe what is: no versions (checked live) and no plans; a test checks it, and the sizes. Claude Code gets the Concise output style unless the user chose one, and `verbose` always off (it only changes what the terminal shows, not the tokens) | Every word of the note is paid in every conversation, the skills only when used; two skills so that programming never loads the system's guides. Specs (2026-11-26, the author's call) replace coding from a loose request: the agent works from written, agreed, checkable intent, reads only the active spec and the task, and a new conversation carries on from them. Today's docs through WebFetch, noted in the plan, instead of MCP servers per language or a docs subagent (2026-11-26: no upkeep, no third party, nothing more loaded in every conversation); `kinobu-dev`'s SKILL.md may grow to 1000 words for it. The council (`kinobu-council`, 2026-11-26) after the LLM council method: advisors that see only a neutral brief, so they do not inherit the conversation's agreement; quick (three advisors and a chair) by default and thorough on request, advisors on `sonnet` and the chair on the main model, claims marked checked or assumed, no subagent files of its own (nothing more loaded in every conversation than its description), only when the user asks or accepts the offer; its text is Kinobu's own. Versions written into the skill went stale (2026-11-20) |
| Boot splash | The maker's logo kept, with Kinobu's small rings turning under it (as Windows does), on Ubuntu's own two-step module, chosen by hand (`update-alternatives --set`), the start-up image rebuilt only when the frames change | The author wants it familiar and not empty: a large logo alone on black was tried and dropped. Ubuntu's minor updates must never take it back (decided on 2026-11-19); a hand-made choice is the one thing package scripts respect. GRUB stays untouched |
| Session sounds | Kinobu's own, drawn by code, quiet (peak about -10 dB); login through an autostart entry, logout through a user service stopped before PipeWire; both off with GNOME's alert sounds. Each user can turn either off or use a file of their own in Seasons > Sounds (copied into `~/.local/share/kinobu/sounds`, cut at 10 s / 4 s; `kinobu-launch sound` asks `kinobu-theme sound` and falls back to Kinobu's) | The author chose them by ear on 2026-11-22; the choice in Seasons added on 2026-11-23 (a copy, so moving the original does not silence it: the author's call). Ubuntu's login sound is off by default and Settings cannot change it; GNOME has no logout sound at all, so a service that plays as the session stops is the only place for it |
| Look | Themes (`docs/themes.md`): each has palettes, every one dark or light and paired with one of the other mode (the dark-style switch); a theme changes mode, accent, app colours, icons, cursor, window buttons, wallpapers and terminal. Every factory palette passes `kinobu-theme validate --strict` (text 7, secondary text 4.5, accent 3), and the engine makes the terminal's colours legible itself (4.5, text 7), since most Ptyxis palettes, the light ones above all, fall short. Seasons chooses them; its other sections have a "Follow the theme" switch, and the user's picks (icons, cursor, fonts, wallpapers) in `~/.config/kinobu/look.toml` win over the theme's. New users start with the Kinobu theme. Packs: APT when Ubuntu has them, `LOOK_PACKS` (ready-made, pinned, checked) otherwise, all in the system; packs that only ship sources wait for `kinobu-assets`. No GNOME Shell theme; GNOME Tweaks is not installed. Papirus' folders take the theme's colour through a hidden icon theme of the user's (links over Papirus), automatic only, never `papirus-folders` (it changes `/usr/share` for every user with sudo). Four wallpapers per theme, by Wallhaven id, downloaded by the user when the theme is applied | One look per user over shared packs; the repository holds no pictures (Orkestr's were copyrighted) |
| Other users | Kinobu is installed on accounts that already exist: each one gets their part through `kinobu --user` (the login entry opens it), with the same blocks as the setup; no system defaults (dconf system database) and nothing in `/etc/skel`. A user with no account picture gets one of GNOME's at random (AccountsService, their own call, no sudo) | Decided on 2026-11-23 for stability and to reuse tested code: `/etc/skel/.bashrc` is a conffile of Ubuntu's `bash` package (apt would ask on its updates), system defaults reach every user who never changed a setting and would be a second copy of the settings, and extensions and theme files are per user anyway |
| Always installed | Python (`pip`, `venv`, `python`), Node.js, GraalVM, the GNOME apps, Handy | The author's choice of a professional base |
| App names | A visible name in English, the same in every language and never translated (Sprout, Trail, Echo, Gate, Willow, Seasons); technical app IDs (`os.kinobu.<Function>`) and commands (`kinobu-<function>`, `kinobu-launch <function>`) underneath | Agents, hooks and scripts read the technical names, which say what each app does; a visible name can change by editing the `.desktop` file and the window title. Table in GUIDE |
| Versions | 0.x while in development (0.1 on 2026-11-17, 0.2 on 2026-11-18, 0.3 on 2026-11-19, 0.3.1 on 2026-11-21, 0.3.2 on 2026-11-22, 0.3.3 on 2026-11-26; a third number for fixes and small additions), 1.0 when published; fruit names from 1.0 | A tree that grows bears fruit |

## 7. Tests

`bash tests/run.sh` must stay green, ShellCheck included (`uvx --from shellcheck-py shellcheck -x -S style`).

- **Stubs** (`tests/stubs/`, first in `PATH`): `sudo` (records the command, runs nothing), `curl` (writes `: stub` to `-o` files), `gdbus` (AccountsService: the picture is `$KINOBU_TEST_ICON`, calls recorded, nothing sent), `git`, `systemctl`, `gnome-extensions`, `xdg-settings`, `pkill`, `pgrep`, `setsid`, `fc-list`, `claude`, `uv`.
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

In [docs/facts.md](docs/facts.md): read the entry you need before changing that part, and add new facts there (with the date and how they were checked). Topics: Installers; Skills folders; Hooks; GNOME 50 shows no buttons in notifications; Google Chrome's `.deb` adds its own repository; Oh My Bash's installer replaces `~/.bashrc`; GNOME custom keybinding commands get no shell or `~` expansion; `gsettings`/`dconf` need the session bus; fastfetch 2.57; libgweather; Ubuntu's automatic updates; Willow; GTK 4.22 / libadwaita 1.9 (Ubuntu); Ptyxis 50.1; Icon and cursor packs; elementary's icons; `python3-gi-cairo` is not installed by default; Ubuntu Dock's Show Apps icon; Wallhaven's API; The login screen (GDM); The boot splash (Plymouth); Session sounds; The workspace-wallpapers extension; Papirus' coloured folders; Account pictures; Screenshots on GNOME 50; Claude Code 2.1.326 flags used by Willow; Omarchy 4.

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
  4. `ROADMAP.md`: delete the version's done items and open the next version.
  5. `AGENTS.md`: the version and state in §1, and the versions row in §6.
  6. `GUIDE.md` and the skill, if anything there still names the old version.
  7. Check that what must reach computers already set up is in a function `UPDATE_FN` runs.
  8. `bash tests/run.sh`, and propose the commit message (the author commits).
