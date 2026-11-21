---
name: @APP_ID@
description: >
  REQUIRED before changing anything on this computer, an Ubuntu desktop (GNOME on Wayland)
  set up with @APP_NAME@: installing or removing software, drivers and services, GNOME settings,
  extensions, shortcuts, the look (themes, wallpapers, icons), the AI tools, and questions
  about the hardware (always checked live).
---
<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->

# @APP_NAME@ system skill

Ubuntu with GNOME on Wayland, set up by @APP_NAME@: a shared part in `@SYSTEM_DIR@` and `@BIN_DIR@`
(every user) and each user's own part in their home folder. Its version: `cat @SYSTEM_DIR@/version`.

## Rules (besides your global instructions)

- Never partition, format or write to disks: other systems may live on them. `lsblk` and `df` are fine.
- Delete in `$HOME` with `gio trash <path>`, never `rm -rf`.
- Software: Ubuntu's repositories first, then snap, then the vendor's official package.
- `gsettings` and `dconf` as the user, never with sudo; they need the graphical session.
- Wayland: `ydotool` and `wl-copy`/`wl-paste`, not `xdotool` or `xclip`.
- Never edit @APP_NAME@'s own files (`@SYSTEM_DIR@`, `@BIN_DIR@`) or the blocks marked `@APP_ID@`
  in dotfiles: updates rewrite them. Make lasting changes outside them.
- No personal data (e-mail, tokens) in a `User-Agent` or in requests to web services.

## Guides: read only the one you need

| Guide | For |
|---|---|
| [software.md](software.md) | installing, removing and updating; repositories; Docker, virtual machines, Java, IDEs |
| [desktop.md](desktop.md) | GNOME settings, workspaces, extensions, dock, accounts, dictation, shell, power |
| [look.md](look.md) | themes (Seasons), icons, cursors, fonts, wallpapers, terminal colours, login and boot screens |
| [shortcuts.md](shortcuts.md) | the keyboard shortcuts |
| [hardware.md](hardware.md) | checking the hardware and drivers |
| [agents.md](agents.md) | the AI tools, the read-only investigator, notifications, Willow |

## @APP_NAME@'s apps

The user may call them by name; open them with `@LAUNCHER@ <command>`.

| Name | What it is | Command |
|---|---|---|
| Sprout | the welcome tour (Super+F1) | `welcome` |
| Trail | the shortcuts on screen (Super+K) | `keys` |
| Seasons | themes, icons, cursors, fonts and wallpapers | `themes` |
| Willow | the voice assistant (Super+Shift+Space) | `voice` |
| Echo | the agents' notifications (no window) | — |
| Gate | the window that approves an agent's permission request | — |

## Investigating the system

Anything that needs many commands or long output (logs, drivers, services, why something
fails) fills your context: hand it to the read-only `kinobu-agent` subagent if your tool has it,
and keep only its report. The loop is in [agents.md](agents.md).

## @APP_NAME@ itself

- Updating it: `bash kinobu.sh --update` in @APP_NAME@'s project folder (after `git pull`); the
  installed `kinobu --update` re-applies the copy it already has. Never suggest `--install` to
  keep things up to date: it re-applies the whole look.
- Logs of each run and the GNOME settings saved before it (last 10): `~/.local/state/@APP_ID@/`.
  Restore settings with `dconf load / < <file>`, then log out and in.
