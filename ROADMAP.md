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

In this order: Claude Code, then Codex, then Antigravity CLI.

- [x] Claude Code: hooks, notices and the approval window checked with the real tool from a read-only folder.
- [ ] Claude Code: the skill and the `kinobu-system` subagent in a real session.
- [ ] Codex: skill, note, subagent, hooks and the approval window (it needs `codex login` and `/hooks`).
- [ ] Antigravity CLI: skill, note, subagent and hooks.

## Zen, the voice assistant

- [x] Installs, prepares its voices and starts (checked with the models already on the author's computer).
- [ ] A whole conversation, and the real download of the models (about 450 MB, 2 GB with Qwen3-TTS).
- [ ] Other agents besides Claude Code, each in its headless mode: Codex first (`codex exec --json`, `resume`), then Antigravity CLI, for people who have no Claude Code session.
- [ ] Two separate settings: **Zen's agent** (the small model that answers) and **delegate to** (the agent that opens for real work).
- [ ] Its final name.

## System layer

- [ ] Zen's voices and models in the system instead of once per user.
- [ ] GNOME extensions, the Nerd Font and Oh My Bash in the system (today each user's setup installs them).

## Later

- **Themes.** A theme is a folder with its colours and wallpapers; templates turn it into the accent, the app colours, the terminal palette and fastfetch. Factory themes in the system (today's look and Everforest), the user's own in `~/.config/kinobu/themes`, and an app to choose and create them.
- **DaVinci Resolve** in the Media creation menu: it is not in APT, snap or the store and needs its own setup.
- **Version names.** From 1.0 on, each major version is named after a fruit (`Kinobu v1.0 (Yuzu)`).
- Zen: more languages, a private mode with a local model, and interrupting it while it speaks.
- A desktop notice when Ubuntu's automatic updates start in the background.
