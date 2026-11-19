# Kinobu — Guide

How Kinobu works inside: the modes, the blocks, where everything is installed, the agents' integration, the files it touches and how to undo things. For what Kinobu is and why it exists, start with the [README](README.md).

> Kinobu 0.3 is in development: installed and updated on its author's computer, otherwise run in simulation. This guide describes what the code does; see the [Roadmap](ROADMAP.md) for what is not verified yet.

## Contents

- [Requirements](#requirements)
- [Modes](#modes)
- [What a run looks like](#what-a-run-looks-like)
- [The blocks](#the-blocks)
- [Software you can choose](#software-you-can-choose)
- [Two layers: the system and each user](#two-layers-the-system-and-each-user)
- [Updating](#updating)
- [Kinobu's apps](#kinobus-apps)
- [AI agents](#ai-agents)
- [Willow, the voice assistant](#willow-the-voice-assistant)
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
| `ai` | Installs the chosen agents and local AI tools with their official installers, `uv` and Willow; the first chosen agent opens with Super+Shift+Enter | Updates the tools that are installed and Willow |
| `drivers` | Installs the drivers Ubuntu recommends for the hardware | — |
| `services` | Lets `ydotool` type dictated text, turns off ModemManager (unless there is a mobile modem) and the OpenVPN system service | — |
| `user` | Oh My Bash, the Nerd Font, Kinobu's block in `~/.bashrc`, the fastfetch summary, the Ptyxis palette and the terminal fonts of VS Code and the JetBrains IDEs | The `~/.bashrc` block and fastfetch |
| `desktop` | GNOME extensions, clock, weather (the city of your time zone), four workspaces, power settings, dock, Geary in the background, the app grid, the boot splash and the look: Seasons, the themes and their icon and cursor packs, then your theme (Kinobu for a new user) | The themes and their packs; your look is kept |
| `shortcuts` | The launcher, the shortcut table, the Super+K cheat sheet and the welcome tour | The same: Kinobu's shortcuts always win |
| `context` | The system skill, the read-only subagent, the note and the agent's notifications | The same |

Always installed: Python (`pip`, `venv`, the `python` command), Node.js, build tools, the GraalVM JDK, Git and GitHub CLI, ripgrep, fd, fastfetch, WireGuard, the GNOME apps (Contacts, Calendar, Weather, Clocks, Calculator, Characters, Geary), the themes' icons, cursors and fonts (Papirus, Numix Circle, elementary, Kora; Bibata, Breeze, Phinger, Catppuccin, Nordzy, macOS and WhiteSur cursors; Inter, JetBrains Mono), Handy and Willow. Firefox always stays.

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
| AI agents | Coding agents | Claude Code ✅ |
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
| `bin/kinobu-theme` | The theme engine (Seasons uses it; agents and scripts too) |
| `bin/kinobu-login-screen` | Builds the login screen's theme with Kinobu's background (`share/kinobu/login/`) |
| `bin/kinobu-boot-splash` | Installs and chooses the boot splash: the maker's logo with Kinobu's rings turning under it (its frames in `share/kinobu/data/plymouth/`) |
| `share/kinobu/programs/` | Kinobu's apps (Trail, Sprout, Gate, Echo's notices, Willow, Seasons) and the theme engine |
| `share/kinobu/themes/` | The factory themes |
| `share/kinobu/skills/` | The system skill |
| `share/kinobu/i18n/` | Every text of Kinobu's windows and notices, one file per language |
| `share/kinobu/data/` | The shortcut table, the fastfetch logo and taglines, and the themes' templates |
| `share/kinobu/src/` | A copy of Kinobu itself |
| `share/kinobu/version` | The installed version |
| `share/icons/` | Icon and cursor packs that are not in Ubuntu's archive (the others come with APT) |
| `/etc/xdg/autostart/kinobu-user.desktop` | Runs at every login (see below) |

**Each user**, without a password: Kinobu's block in `~/.bashrc`, the fastfetch config, the GNOME settings and shortcuts, the agent itself with its link to the skill, the note, the subagent and the hooks; their look (`~/.config/kinobu/look.toml`); and Willow's voices and settings.

**Another user.** `kinobu --user` gives a user their part: the first time it lets them choose their agents and applies the desktop; later it only refreshes Kinobu's own files and keeps their look. The login entry compares the user's version (`~/.config/kinobu/version`) with the system's and opens a terminal with `kinobu --user` when they differ, so a new user, and every other user after an update, is brought up to date at their next login.

The agents' hooks only read and run these files, which any user may do: no special permission is needed. Only writing them needs administrator rights, so an agent cannot change the window that approves its own commands.

## Updating

```bash
cd kinobu && git pull
bash kinobu.sh --update
```

Run it from the project's folder after `git pull`: the installed `kinobu --update` runs the copy of Kinobu it already has, so it brings nothing new (a self-updating `kinobu --update` is planned for 0.4).

It shows no menus and never touches your look: your theme and what you picked in Seasons (`~/.config/kinobu/look.toml`), your terminal font, dock, weather, power settings and extensions stay as you left them; the themes themselves may improve. Kinobu never goes back: a copy older than the installed version refuses to run.

## Kinobu's apps

Each app has a name you see, the same in every language, and technical names underneath: the app ID that GNOME uses to tie a window to its icon, and the command that shortcuts, hooks, scripts and agents run. Only the visible name is a brand; the technical names say what the app does, so an agent understands them without explanations and a visible name can change without breaking anything.

| Name | What it is | App ID | Command |
|---|---|---|---|
| **Sprout** | The welcome tour (Super+F1; not in the app grid) | `os.kinobu.Welcome` | `kinobu-launch welcome` |
| **Trail** | The keyboard shortcuts on screen (Super+K) | `os.kinobu.Keys` | `kinobu-launch keys` |
| **Echo** | The agents' notifications (no window of its own) | — | `kinobu-notify` |
| **Gate** | The approval window for the agents' permissions | `os.kinobu.Approve` | opened by `kinobu-notify` |
| **Willow** | The voice assistant | `os.kinobu.Voice` | `kinobu-launch voice` |
| **Seasons** | Themes with their palettes (each dark or light), icons, cursors, fonts and wallpapers, each with a "Follow the theme" switch, wallpapers from Wallhaven, and your own themes: duplicate one from its menu and change its colours. Themes, icons and cursors show the system's and yours apart (see [docs/themes.md](docs/themes.md)) | `os.kinobu.Themes` | `kinobu-launch themes`; the engine is `kinobu-theme` |

## AI agents

Kinobu integrates one agent for now, Claude Code, installed or not, so it is ready if you install it later. Other agents will come once this integration is complete.

- **The skill.** A fixed description of the system in six guides (the system and its safety rules, software, desktop, shortcuts, hardware, agents), linked into Claude Code's skills folder (`~/.claude/skills`). Hardware is never written down: the skill tells agents to check it live.
- **The note.** A short block in the agent's global instructions (`~/.claude/CLAUDE.md`): load the skill before changing the system, work step by step and wait for your go-ahead, work freely inside your folder and ask before `sudo`, and save tokens.
- **Kinobu Agent (`kinobu-agent`), the system subagent.** A read-only investigator the agent can call for diagnoses that need many commands; it returns a short report (cause, fix, check, what needs `sudo`).
- **Echo, the notifications.** GNOME notices when an agent finished (tasks of 20 s or more), waits for you or stopped on an error, with a sound; clicking one brings back the agent's terminal.
- **Gate, the approval window.** When Claude Code needs a permission, Gate asks with Allow, In terminal and Deny. No button starts with the keyboard focus and nothing counts in its first moment on screen, so a key you were typing never answers. Closing it, Esc, "In terminal" or no answer in 45 s leave the question in the agent's terminal: nothing is approved on its own. "In terminal" also takes you to that terminal, on whatever workspace it is. In Claude Code's auto mode Gate waits a few seconds first, so it only opens when the automatic check leaves the decision to you.

Kinobu never changes the agents' own permission settings.

## Willow, the voice assistant

Press **Super+Shift+Space**, speak, and it answers aloud and keeps listening. It listens through Handy and thinks with Claude Code in a tiny context of its own, at the power chosen in its settings: **Quick** (Haiku at low effort, the default), **Smart** (Haiku at high effort) or **Strong** (Sonnet at medium effort, slower and about 20 times dearer per token). It talks like a friendly, direct mate with a touch of humour; its settings take an optional line on how you want it to talk. It keeps nothing about you between talks. Its voices run on your computer: Kokoro, Piper and, with a dedicated graphics card, Qwen3-TTS on Vulkan.

What it can do:

- **Answer and look things up**: the web, and the computer with read-only commands.
- **Act, safely**: volume, microphone, brightness, night light, Do Not Disturb, dark or light mode, the theme, music, a page of Settings, Wi-Fi, Bluetooth, reminders and timers. All through `kinobu-do`, the only command that lets it change anything (`kinobu-do help` lists its actions; you can use it too).
- **See your screen** when you ask ("what does this message mean?"). The first time, GNOME asks whether apps may take screenshots: choose Allow. The picture stays in Willow's private folder.
- **Know this computer**: it reads Kinobu's skill only when it is unsure, so it costs nothing the rest of the time.
- **Check things in the background**: for something that needs more care but changes nothing, it asks a stronger model (Sonnet) without opening any window and tells you with a notification when it is ready.
- **Hand over real work**: changing the system, files or code opens Claude Code in a terminal with the task already written.

To **stop it while it speaks** (a long answer, or you want to say something), press the stop button next to the microphone, Esc or Super+Shift+Space again: the voice stops at once, the whole answer stays in the window and Willow listens again.

Each turn costs a fraction of a cent (on a Claude subscription it counts towards its usage instead).

## Keyboard shortcuts

Press **Super+K** to see them on screen. The letter is the first letter of the action (**E**xplorer, **B**rowser, **R**un, **Q**uit, **F**ull screen, **L**ock, **D**esktop, **K**eys), and in the terminal the rule is *browser shortcut + Shift*.

| Shortcut | Action |
|---|---|
| Super + Enter | Terminal |
| Super + Shift + Enter | AI agent in a terminal |
| Super + E / B | Files / web browser |
| Super + Space | Dictation (Handy) |
| Super + Shift + Space | Talk to Willow |
| Super + K | The shortcut list (Trail) |
| Super + F1 | Help: the welcome tour (Sprout) |
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
  ai.sh            block ai and Willow
  drivers.sh  services.sh  user.sh  desktop.sh  shortcuts.sh  context.sh
  look.sh          the themes, Seasons and their packs (part of block desktop)
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
| `lib/ai.sh` | The agents' installers and Willow's voices |
| `lib/user.sh` | Oh My Bash, the Nerd Font, the terminal font |
| `lib/desktop.sh` | Extensions, power times, workspaces, dock, app grid |
| `lib/look.sh` | `LOOK_THEME` (the first theme), `LOOK_PACKS` (icon and cursor packs with their versions and checksums) |
| `files/themes/` | The factory themes, one `theme.toml` each ([docs/themes.md](docs/themes.md)) |
| `lib/shortcuts.sh` | `SHORTCUTS` and the GNOME defaults freed for them |
| `lib/context.sh` | Notifications on or off, the approval window, sounds and waiting times |

## Files it creates or changes

Besides the [system layer](#two-layers-the-system-and-each-user):

| Path | What |
|---|---|
| `/etc/apt/apt.conf.d/99enable-amd64v3` | Optimised package builds |
| `/etc/apt/apt.conf.d/99kinobu-login-screen` | Rebuilds the login screen's theme when Ubuntu updates its own |
| `/usr/share/gdm/dconf/95-kinobu-login` | No distribution logo on the login screen (GDM reads it with Ubuntu's settings on every start) |
| `/usr/share/plymouth/themes/kinobu/` | The boot splash (Plymouth only looks there), chosen by hand as `default.plymouth` |
| `/etc/apt/sources.list.d/` and their keys | Software sources of the chosen apps only |
| `/etc/udev/rules.d/60-uinput-uaccess.rules` | Lets `ydotool` type |
| `/opt/java/graalvm-jdk-<version>/` | The GraalVM JDK |
| `~/.bashrc` | A block between `# >>> kinobu >>>` and `# <<< kinobu <<<` (backup `~/.bashrc.kinobu.bak`) |
| `~/.oh-my-bash/`, `~/.local/share/fonts/NerdFonts/` | Oh My Bash and the Nerd Font |
| `~/.config/fastfetch/config.jsonc` | The system summary (kept if you removed the `Managed by Kinobu` line) |
| `~/.config/kinobu/look.toml` | Your look: the theme and what you picked in Seasons (never changed by updates) |
| `~/.config/gtk-4.0/kinobu.css`, `~/.config/gtk-3.0/kinobu.css` | The theme's app colours, imported from a block in each `gtk.css` |
| `~/.local/share/icons/<pack>`, `~/.icons/default` | Links to the icons and cursor in use, for sandboxed and older apps |
| `~/.claude/` | The skill link, the note, the subagent and the hooks of Claude Code |
| `~/.config/kinobu/` | The default agent, your version, Willow's settings |
| `~/.local/share/kinobu/voice/` | Willow's voices and models |
| `~/.local/state/kinobu/` | One log per run and the GNOME settings before each run (last 10); `terminal-dark` and `terminal-light`, the theme's accent for fastfetch and the setup |
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
| Agent context and notifications | Remove the `kinobu` link, block and hook entries in `~/.claude/` |
| Optimised packages | `sudo rm /etc/apt/apt.conf.d/99enable-amd64v3` |
| Kinobu's login screen | `sudo kinobu-login-screen --remove` (Ubuntu's grey and logo come back), then `sudo rm /etc/apt/apt.conf.d/99kinobu-login-screen` |
| Kinobu's boot splash | `sudo kinobu-boot-splash --remove` (Ubuntu's comes back at the next start) |
| Kinobu itself | `sudo rm -rf /usr/local/share/kinobu /usr/local/bin/kinobu* /etc/xdg/autostart/kinobu-user.desktop` |

## Tests

```bash
bash tests/run.sh
```

Syntax and lint, the command line, the check, the menus in a pseudo-terminal and a whole setup, a second run, `--update` and `--user`. The setup tests use a fake home folder, their own GNOME settings database and stand-ins for `sudo`, `curl`, `git` and `systemctl`, so the real system is not touched.
