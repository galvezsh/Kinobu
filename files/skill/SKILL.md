---
name: @APP_ID@
description: >
  REQUIRED before changing anything on this computer. It is an Ubuntu desktop
  (GNOME on Wayland) set up with @APP_NAME@. Use it to install or remove software
  (APT, snap, .deb), handle drivers and services, change GNOME settings,
  extensions, keyboard shortcuts or workspaces, manage the AI tools on this
  machine, and answer questions about the hardware (always checked live).
---
<!-- Managed by Kinobu: rewritten on every run and --update. Do not edit it, changes are lost: add your own skills next to this one. -->

# @APP_NAME@ system skill

This computer runs Ubuntu with GNOME on Wayland, configured by @APP_NAME@ @APP_VERSION@.
Hardware, versions and installed apps change over time: **never assume them,
check them live** with the commands in [hardware.md](hardware.md).

## Topic guides

Read the matching guide before starting:

- [software.md](software.md): installing, removing and updating software, repositories, Docker
- [desktop.md](desktop.md): GNOME settings, extensions, dock, theme, dictation, Zen (voice assistant)
- [shortcuts.md](shortcuts.md): keyboard shortcuts and workspaces
- [hardware.md](hardware.md): commands to inspect hardware, drivers and disks
- [agents.md](agents.md): the AI tools on this machine and where they keep their config

## Delegating system investigations

Investigations that need many commands or long outputs (logs, hardware, drivers, services, why
something fails) fill your context. If your tool has the read-only `kinobu-system` subagent
(Claude Code, Codex, Antigravity), hand them to it and keep only its short
report; for one or two quick commands, run them yourself. The user may also ask for it by name.
The report format and the fix-and-check loop are in [agents.md](agents.md).

## Safety rules

- Work step by step: explain the plan and wait for the user's go-ahead before anything beyond a small change.
- Inside `$HOME` you may create, edit and run freely once the plan is agreed. Ask before `sudo`, `pkexec` or any change outside `$HOME`, and show the exact command first.
- Never partition, format or write to disks or partitions. Other operating systems may live on them. Read-only inspection (`lsblk`, `df`) is fine.
- Never delete in `$HOME` with `rm -rf`; prefer `gio trash <path>`.
- Install software from the Ubuntu repositories first, then snap, then only official vendor packages.
- Run `gsettings`/`dconf` as the user, never with sudo. They need the graphical session, not SSH.
- This is Wayland: `xdotool` and `xclip` do not work; use `ydotool` and `wl-copy`/`wl-paste`.
- Never put the user's email address (or any other personal data) in a `User-Agent` header or in requests to web services and APIs. When a service asks for contact details in the User-Agent, use the tool name only, or ask the user first.
- @APP_NAME@'s own files live in `@SYSTEM_DIR@` (`programs/`, `skills/`, `i18n/`, `data/`) and `@BIN_DIR@`: they belong to the system, are shared by every user and are rewritten by @APP_NAME@. Never edit them. Blocks marked `@APP_ID@` in dotfiles are rewritten too: make lasting changes outside them.

## Stable facts

- Java: GraalVM JDK in `@JAVA_DIR@` (`JAVA_HOME` is set in `~/.bashrc`).
- Software was chosen in menus at setup: check what is installed live (see software.md).
- Workspaces: @WORKSPACES@, fixed, each with its own wallpaper. Shortcut cheat sheet: Super+K.
- Shell: bash with Oh My Bash (`~/.oh-my-bash`, theme `@OMB_THEME@`; `pb10k` toggles prompt
  segments). Terminals use the `@NERD_FONT_FAMILY@` font, needed for the prompt icons.
- Updating @APP_NAME@: `git pull` in its folder, then `bash kinobu.sh --update`. It updates the
  apps, agents, skill and @APP_NAME@'s own files and never touches the user's look. A plain
  `bash kinobu.sh --install` re-applies the whole @APP_NAME@ look: never suggest it to keep things up to date.
- Logs of @APP_NAME@ runs: `~/.local/state/@APP_ID@/`. Before each run, every GNOME setting is saved
  there as `dconf-<date>.ini` (last 10); restore one with `dconf load / < <file>` and log out and in.
