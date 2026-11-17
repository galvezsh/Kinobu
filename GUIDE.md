# Kinobu — Guide

How Kinobu works inside: the modes, the blocks, where everything is installed, the agents' integration, the files it touches and how to undo things. For what Kinobu is and why it exists, start with the [README](README.md).

> Kinobu 0.1 is in development and has only been run in simulation. This guide describes what the code does; see the [Roadmap](ROADMAP.md) for what is not verified yet.

## Contents

- [Requirements](#requirements)
- [Modes](#modes)
- [What a run looks like](#what-a-run-looks-like)
- [The blocks](#the-blocks)
- [Software you can choose](#software-you-can-choose)
- [Two layers: the system and each user](#two-layers-the-system-and-each-user)
- [Updating](#updating)
- [AI agents](#ai-agents)
- [Zen, the voice assistant](#zen-the-voice-assistant)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [How the code is organised](#how-the-code-is-organised)
- [Configuration](#configuration)
- [Files it creates or changes](#files-it-creates-or-changes)
- [Safety](#safety)
- [Undoing things](#undoing-things)
- [Tests](#tests)

## Requirements

| | |
|---|---|
| System | Ubuntu 26.04 LTS, amd64 (another Ubuntu version runs with a warning) |
| Desktop | GNOME, run from a terminal in the graphical session |
| User | A regular user with administrator rights (`--user` needs none) |
| Disk | About 25 GB free on `/` |
| Network | An internet connection |

## Modes

One option decides what to do; with none, the help is shown.

| Option | What it does |
|---|---|
| `-i`, `--install` | Checks the computer, asks for your software and sets everything up |
| `-u`, `--update` | Updates a computer already set up; your look is kept |
| `-m`, `--manual` | Lets you choose the blocks to run in a list |
| `-c`, `--check` | Only checks the computer; nothing is changed |
| `--user` | Sets Kinobu up for your user on a computer that already has it; no password |
| `-v`, `--version`, `-h`, `--help` | The version and the help |

## What a run looks like

1. **The check.** The KINOBU wordmark, then a list of requirements (regular user, administrator rights, Ubuntu, 64-bit processor, GNOME session, free space, internet) and of hardware facts that only inform (optimised packages, virtualisation, dedicated graphics card, Secure Boot). A missing requirement stops the run and says what to do. No password is asked.
2. **The menus.** Full-screen lists to tick with the keyboard, one after another: arrows move, Space selects, Enter goes on, B goes back, Q quits.
3. **The confirmation.** Your software, the numbered list of what Kinobu is going to do and one question. Nothing has changed until you press Enter here.
4. **The setup.** Your password once, then each block with its progress dots and its steps. The output of apt, snap and the downloads goes to the log; the screen shows a single live line.
5. **The summary.** What to look at, whether a restart is needed, the next steps for you and where the log is.

If something fails, Kinobu says in which step, shows the last lines of the log and how to try again.

## The blocks

They run in this order. `--update` runs the ones marked, with the function in the last column.

| Block | What it does | `--update` |
|---|---|---|
| `apt` | Turns on Ubuntu's x86-64-v3 package builds when the processor supports them | — |
| `apps` | Adds the software sources of the chosen apps only, updates Ubuntu, installs the base tools and your apps (APT, snap, vendor `.deb`), Handy and the GraalVM JDK, removes what a desktop does not need and sets the default browser | Updates Ubuntu, the snaps, Handy and Java |
| `ai` | Installs the chosen agents and local AI tools with their official installers, `uv` and Zen; the first chosen agent opens with Super+Shift+Enter | Updates the tools that are installed and Zen |
| `drivers` | Installs the drivers Ubuntu recommends for the hardware | — |
| `services` | Lets `ydotool` type dictated text, turns off ModemManager (unless there is a mobile modem) and the OpenVPN system service | — |
| `user` | Oh My Bash, the Nerd Font, Kinobu's block in `~/.bashrc`, the fastfetch summary, the Ptyxis palette and the terminal fonts of VS Code and the JetBrains IDEs | The `~/.bashrc` block and fastfetch |
| `desktop` | GNOME extensions, theme, clock, weather (the city of your time zone), four workspaces, power settings, dock, Geary in the background, the app grid and the GTK app colours | Only the app colours |
| `shortcuts` | The launcher, the shortcut table, the Super+K cheat sheet and the welcome tour | The same: Kinobu's shortcuts always win |
| `context` | The system skill, the read-only subagent, the note and the notifications of every agent | The same |

Always installed: Python (`pip`, `venv`, the `python` command), Node.js, build tools, the GraalVM JDK, Git and GitHub CLI, ripgrep, fd, fastfetch, WireGuard, the GNOME apps (Contacts, Calendar, Weather, Clocks, Calculator, Tweaks, Characters, Geary), Handy and Zen. Firefox always stays.

## Software you can choose

Unticking something never uninstalls it, and a vendor's software source is only added when you pick its app (✅ = preselected).

| Menu | Section | Choices |
|---|---|---|
| Applications | Web browsers | Helium, Google Chrome ✅ |
| | Media | Spotify, VLC |
| | Media creation | OBS Studio, Audacity, HandBrake, Blender, GIMP, Krita |
| | Desktop | Mission Center ✅ |
| Development | Editors | VS Code ✅, Antigravity, Cursor, Android Studio, Eclipse |
| | JetBrains | IntelliJ IDEA ✅, PyCharm ✅, WebStorm, CLion, GoLand, Rider, PhpStorm, RubyMine, RustRover, DataGrip |
| AI agents | Coding agents | Claude Code ✅, Codex, Antigravity CLI |
| Extra tools | Containers and virtual machines | Docker Engine, virt-manager |
| | Local AI | Ollama, LM Studio |
| | Office | LibreOffice, OnlyOffice |

Docker and virt-manager are used with your password: Kinobu keeps you out of the `docker` and `libvirt` groups, which are equivalent to administrator rights without a password.

## Two layers: the system and each user

What is the same for everybody lives in the system; what is personal lives in each user's folder.

**The system** (`/usr/local`, or the folder in `KINOBU_PREFIX`), written once with administrator rights:

| Path | What |
|---|---|
| `bin/kinobu` | Runs the installed copy of Kinobu |
| `bin/kinobu-launch` | Run by the app shortcuts |
| `bin/kinobu-notify` | Run by the agents' hooks |
| `share/kinobu/programs/` | The cheat sheet, the welcome tour, the approval window, the notices and Zen |
| `share/kinobu/skills/` | The system skill |
| `share/kinobu/i18n/` | Every text of Kinobu's windows and notices, one file per language |
| `share/kinobu/data/` | The shortcut table, and the fastfetch logo and taglines |
| `share/kinobu/src/` | A copy of Kinobu itself |
| `share/kinobu/version` | The installed version |
| `/etc/xdg/autostart/kinobu-user.desktop` | Runs at every login (see below) |

**Each user**, without a password: Kinobu's block in `~/.bashrc`, the fastfetch config, the GNOME settings and shortcuts, the agents themselves and, for each agent, the link to the skill, the note, the subagent and the hooks; and Zen's voices and settings.

**Another user.** `kinobu --user` gives a user their part: the first time it lets them choose their agents and applies the desktop; later it only refreshes Kinobu's own files and keeps their look. The login entry compares the user's version (`~/.config/kinobu/version`) with the system's and opens a terminal with `kinobu --user` when they differ, so a new user, and every other user after an update, is brought up to date at their next login.

The agents' hooks only read and run these files, which any user may do: no special permission is needed. Only writing them needs administrator rights, so an agent cannot change the window that approves its own commands.

## Updating

```bash
cd kinobu && git pull
bash kinobu.sh --update
```

It shows no menus and never touches your look: accent colour and theme, wallpapers, terminal palette and font, dock, weather, power settings and extensions stay as you left them. Kinobu never goes back: a copy older than the installed version refuses to run.

## AI agents

Kinobu integrates Claude Code, Codex and Antigravity CLI, installed or not, so an agent you install later is ready too.

- **The skill.** A fixed description of the system in six guides (the system and its safety rules, software, desktop, shortcuts, hardware, agents), linked into each agent's skills folder. Hardware is never written down: the skill tells agents to check it live.
- **The note.** A short block in each agent's global instructions (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.gemini/GEMINI.md`): load the skill before changing the system, work step by step and wait for your go-ahead, work freely inside your folder and ask before `sudo`, and save tokens.
- **The `kinobu-system` subagent.** A read-only investigator the agents can call for diagnoses that need many commands; it returns a short report (cause, fix, check, what needs `sudo`).
- **Notifications.** GNOME notices when an agent finished (tasks of 20 s or more), waits for you or stopped on an error, with a sound; clicking one brings back the agent's terminal.
- **The approval window.** When Claude Code or Codex needs a permission, Kinobu's window asks with Allow, In terminal and Deny. No button starts with the keyboard focus and nothing counts in its first moment on screen, so a key you were typing never answers. Closing it, Esc, "In terminal" or no answer in 45 s leave the question in the agent's terminal: nothing is approved on its own.

Kinobu never changes the agents' own permission settings.

## Zen, the voice assistant

Press **Super+Shift+Space**, speak, and it answers aloud and keeps listening. It listens through Handy, thinks with a small model of your agent in a tiny context of its own, can search the web, read the computer with read-only commands and open apps, and hands real work to your agent in a terminal. Its voices run on your computer: Kokoro, Piper and, with a dedicated graphics card, Qwen3-TTS on Vulkan.

For now Zen only talks to Claude Code; Codex and Antigravity CLI are planned.

## Keyboard shortcuts

Press **Super+K** to see them on screen. The letter is the first letter of the action (**E**xplorer, **B**rowser, **R**un, **Q**uit, **F**ull screen, **L**ock, **D**esktop, **K**eys), and in the terminal the rule is *browser shortcut + Shift*.

| Shortcut | Action |
|---|---|
| Super + Enter | Terminal |
| Super + Shift + Enter | AI agent in a terminal |
| Super + E / B | Files / web browser |
| Super + Space | Dictation (Handy) |
| Super + Shift + Space | Talk to Zen |
| Super + K | The shortcut list |
| Super + Q / F / H / D | Close / full screen / minimise / show desktop |
| Super + N / M / V | Notifications / quick settings / clipboard history |
| Super + Alt + K / A | Mute the microphone / the sound |
| Super + PgUp / PgDn | Previous / next workspace |

Kinobu's shortcuts always win: GNOME defaults and your own shortcuts on the same keys lose them, and the summary tells you which. The whole table is `SHORTCUTS` in `lib/shortcuts.sh`.

## How the code is organised

```text
kinobu.sh          configuration, the modes and the flow of a run
lib/
  ui.sh            colours, the wordmark, status lines, the full-screen list
  check.sh         the system check
  blocks.sh        the list of blocks, their titles and functions
  software.sh      the catalogue and the menus
  core.sh          messages, the log, running commands, files, apt, sudo, the run itself
  apps.sh          blocks apt and apps
  ai.sh            block ai and Zen
  drivers.sh  services.sh  user.sh  desktop.sh  shortcuts.sh  context.sh
  update.sh        --update
files/             everything Kinobu installs as a file; @NAME@ marks are filled by render
tools/             branding.py draws the rings and the wordmark for the terminal and the README
                   banner; logo.py, the vector logo
tests/             the tests and their stand-ins for sudo, curl, git...
assets/            the README banner and the logo
```

Each file in `lib/` starts with its own configuration, then its functions. Blocks are functions that print `step`, `ok`, `info` and `warn` lines; long commands go through `run`, which sends their output to the log. Every block can be repeated: it checks before acting and writes files only when their content changes.

## Configuration

| Where | What |
|---|---|
| `kinobu.sh` | Name, version, supported Ubuntu, free space needed, install prefix |
| `lib/software.sh` | `SOFTWARE`: what the menus offer, one line per app (`menu\|id\|name\|description\|on/off\|source`) |
| `lib/apps.sh` | Packages always installed, packages removed, software sources, GraalVM, Handy settings |
| `lib/ai.sh` | The agents' installers and Zen's voices |
| `lib/user.sh` | Oh My Bash, the Nerd Font, the terminal palette |
| `lib/desktop.sh` | Extensions, accent, power times, workspaces, dock, app grid |
| `lib/shortcuts.sh` | `SHORTCUTS` and the GNOME defaults freed for them |
| `lib/context.sh` | Notifications on or off, the approval window, sounds and waiting times |

## Files it creates or changes

Besides the [system layer](#two-layers-the-system-and-each-user):

| Path | What |
|---|---|
| `/etc/apt/apt.conf.d/99enable-amd64v3` | Optimised package builds |
| `/etc/apt/sources.list.d/` and their keys | Software sources of the chosen apps only |
| `/etc/udev/rules.d/60-uinput-uaccess.rules` | Lets `ydotool` type |
| `/opt/java/graalvm-jdk-<version>/` | The GraalVM JDK |
| `~/.bashrc` | A block between `# >>> kinobu >>>` and `# <<< kinobu <<<` (backup `~/.bashrc.kinobu.bak`) |
| `~/.oh-my-bash/`, `~/.local/share/fonts/NerdFonts/` | Oh My Bash and the Nerd Font |
| `~/.config/fastfetch/config.jsonc` | The system summary (kept if you removed the `Managed by Kinobu` line) |
| `~/.config/gtk-4.0/kinobu.css`, `~/.config/gtk-3.0/kinobu.css` | App colours, imported from a block in each `gtk.css` |
| `~/.claude/`, `~/.codex/`, `~/.gemini/`, `~/.agents/skills/` | The skill link, the note, the subagent and the hooks of each agent |
| `~/.config/kinobu/` | The default agent, your version, Zen's settings |
| `~/.local/share/kinobu/zen/` | Zen's voices and models |
| `~/.local/state/kinobu/` | One log per run and the GNOME settings before each run (last 10) |
| GNOME settings (dconf) | Theme, clock, weather, workspaces, power, extensions, shortcuts, dock, app grid |

## Safety

- **Nothing changes before you confirm**, and every run can be repeated.
- **It never touches disks or partitions.**
- **Your GNOME settings are saved before every run.**
- **It keeps your things:** your own shortcuts on other keys, your extensions, your skills and the rest of your dotfiles.
- **It asks for your password once** and never again in the middle of a command.
- **Kinobu's own programs belong to the system:** agents can run them, not edit them.

## Undoing things

| To undo | Do |
|---|---|
| All GNOME settings | `dconf load / < ~/.local/state/kinobu/dconf-<date>.ini`, then log out and in |
| Shell changes | Remove the `kinobu` block from `~/.bashrc` and `rm -rf ~/.oh-my-bash` |
| App colours | Remove the `kinobu` block from `~/.config/gtk-4.0/gtk.css` and `gtk-3.0/gtk.css` |
| Agent context and notifications | Remove the `kinobu` links, blocks and hook entries in each agent's folder |
| Optimised packages | `sudo rm /etc/apt/apt.conf.d/99enable-amd64v3` |
| Kinobu itself | `sudo rm -rf /usr/local/share/kinobu /usr/local/bin/kinobu* /etc/xdg/autostart/kinobu-user.desktop` |

## Tests

```bash
bash tests/run.sh
```

Syntax and lint, the command line, the check, the menus in a pseudo-terminal and a whole setup, a second run, `--update` and `--user`. The setup tests use a fake home folder, their own GNOME settings database and stand-ins for `sudo`, `curl`, `git` and `systemctl`, so the real system is not touched.
