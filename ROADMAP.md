# Roadmap

What is still to do while Kinobu is in development. Tick each item when it is done and move what ships to the [Changelog](CHANGELOG.md).

## 0.1 — before anyone uses it

Everything so far has only run in simulation (a fake home folder, a separate GNOME settings database and stand-ins for `sudo`, `curl` and `git`).

- [ ] A full `--install` from scratch in a virtual machine (GNOME Boxes, Ubuntu 26.04, no dedicated graphics card), then review its log.
- [ ] The same with the desktop in English.
- [ ] `--update` on that machine.
- [ ] A second user on that machine: the login entry and `kinobu --user`.
- [ ] Check on a real desktop that the app grid keeps its three folders first.
- [ ] Wallpapers: one per workspace, our own or with a free licence (none are included yet; without them the current wallpaper is kept).
- [ ] Review the texts of the welcome tour and of the skill, adapted from Orkestr by name only.

## Agent integration

One agent first: Claude Code, complete, before any other is added.

- [x] Claude Code: hooks, notices and the approval window checked with the real tool from a read-only folder.
- [ ] Claude Code: the skill and the `kinobu-system` subagent in a real session.

## Zen, the voice assistant

- [x] Installs, prepares its voices and starts (checked with the models already on the author's computer).
- [ ] A whole conversation, and the real download of the models (about 450 MB, 2 GB with Qwen3-TTS).
- [ ] Two separate settings: **Zen's agent** (the small model that answers) and **delegate to** (the agent that opens for real work).
- [ ] Its final name.

## System layer

- [ ] Zen's voices and models in the system instead of once per user.
- [ ] GNOME extensions, the Nerd Font and Oh My Bash in the system (today each user's setup installs them).

## Later

- **Themes.** A theme is a folder with its colours and wallpapers; the `kinobu-theme` engine turns it into the mode, the accent, the app colours, the icons, the wallpapers and the terminal palette. Factory themes in the system (Kinobu on Everforest, Tokyo Night, Catppuccin, Dracula, Nord, Gruvbox, Rosé Pine, Windows, macOS), the user's own in `~/.config/kinobu/themes`, and an app to choose and create them. Design and phases: [docs/themes.md](docs/themes.md).
- **More agents**, once Claude Code is complete: Codex, then Antigravity CLI (installer, skill, note, subagent, hooks, the approval window and Zen in their headless modes). They were integrated in 0.1 and taken out to finish one agent first; the facts found for them are in AGENTS.md §8.
- **DaVinci Resolve** in the Media creation menu: it is not in APT, snap or the store and needs its own setup.
- **Version names.** From 1.0 on, each major version is named after a fruit (`Kinobu v1.0 (Yuzu)`).
- Zen: more languages, a private mode with a local model, and interrupting it while it speaks.
- A desktop notice when Ubuntu's automatic updates start in the background.
