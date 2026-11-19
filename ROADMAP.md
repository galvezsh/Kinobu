# Roadmap

What is still to do while Kinobu is in development. Tick each item when it is done and move what ships to the [Changelog](CHANGELOG.md).

## Done in 0.2 (2026-11-18)

- The first real `--install` and `--update`, on the author's computer (after moving it off Orkestr): no warnings; three bugs found and fixed (the default agent when none is ticked, GTK 3 colours, Gate flashing in auto mode).
- Claude Code complete: hooks, notices, Gate (the auto-mode wait, Allow, Deny, "In terminal" bringing the terminal back), the skill and the `kinobu-agent` subagent, checked in real sessions.
- Themes with palettes, Seasons and its five sections, four wallpapers per theme from Wallhaven, Wallhaven's search in Seasons.
- The login screen with Kinobu's background (`kinobu-login-screen`), checked in an isolated GNOME; still to see on the real one by signing out.
- Willow installs, prepares its voices and starts (with the models already on the author's computer).

The details are in the [Changelog](CHANGELOG.md).

## 0.3 — next

### Checks on a clean computer

Still to run outside the author's computer (the tests use a fake home folder, a separate GNOME settings database and stand-ins for `sudo`, `curl` and `git`).

- [ ] A full `--install` from scratch in a virtual machine (virt-manager, Ubuntu 26.04, no dedicated graphics card), then review its log.
- [ ] The same with the desktop in English.
- [ ] `--update` from 0.2 on that machine: a theme and look file from 0.1 and 0.2 move to palettes, the theme's wallpapers download.
- [ ] A second user on that machine: the login entry and `kinobu --user`.
- [ ] The app grid keeps its three folders first on a fresh install. On the author's computer GNOME dropped Kinobu's Settings folder because an older folder held two of its apps; Kinobu now takes them out of other folders first.
- [ ] Review the texts of the welcome tour and of the skill, adapted from Orkestr by name only.
- [ ] The menu tests that fail now and then (`tests/pty-run.py` under load): make them wait for what they need instead of fixed times.

### Updates

- [ ] **`kinobu --update` updates itself.** Today the installed command runs the installed copy (`/usr/local/share/kinobu/src`), which only reinstalls itself: new changes need `git pull` and `bash kinobu.sh --update` from the project's folder. The installed `kinobu --update` should look in the project's GitHub releases for a newer version than `/usr/local/share/kinobu/version` (`https://api.github.com/repos/agalvezsh/<repo>/releases/latest`, no personal data in the User-Agent), download it, check it (a SHA-256 in the release and a signature, GPG or minisign, since it runs with sudo), keep it in `src/` and run its own `kinobu.sh --update`, with the no-downgrade guard kept. To decide: a notice of a new version (at login or through Echo), and what happens while the repository is private. Later, maybe an APT repository.
- [ ] Until then, **`kinobu --update` says when it runs the installed copy**: it brings nothing new, and the project folder's `kinobu.sh --update` is the one to run.

### Look

- [x] **The boot splash (Plymouth)**: Kinobu's rings turning while the computer starts (see the changelog).
- [ ] The boot splash on a real start: the loop's speed, the size on a 4K screen (Plymouth doubles pictures only on dense screens: a large 4K monitor may need `DeviceScale=2`), an encrypted disk's password box (in the virtual machine), and shutting down.
- [x] **Terminal palettes with more contrast**: the engine makes every palette's colours legible (see the changelog).
- [x] fastfetch and Kinobu's terminal output in the theme's accent.
- [ ] The login screen without Ubuntu's logo (`95-kinobu-login`), seen on a real login.
- [ ] Papirus folders in the theme's colour (`papirus-folders`).
- [x] **Your own themes in Seasons**: duplicate any theme, change its palettes' colours with a live preview, delete it.
- [ ] Later for your own themes, if they are missed: the terminal's own colours, a new palette in a theme, and the theme's own icons, cursor, fonts and wallpapers in the editor (decided on 2026-11-19 to leave them in Seasons' tabs, where they are the user's over any theme; `theme.toml` already takes them by hand).

### Willow, the voice assistant

- [ ] A whole conversation, and the real download of the models (about 450 MB, 2 GB with Qwen3-TTS).
- [ ] Its new abilities with the real model: the three powers compared on the same questions (Haiku low, medium, high; Sonnet medium), `kinobu-do` actions, the screen, the skill on demand and the background checks on Sonnet; measure the tokens per turn.
- [ ] **Links shown, not read aloud**: Willow keeps URLs in the window's text (to copy them) but its voice says something like "I left the link in the window" (in its instructions, and the URLs taken out of the text before the voice as a safety net).
- [ ] Two separate settings: **Willow's agent** (the small model that answers) and **delegate to** (the agent that opens for real work).

### System layer

- [ ] Willow's voices and models in the system instead of once per user.
- [ ] GNOME extensions, the Nerd Font and Oh My Bash in the system (today each user's setup installs them).

## Later

- **`kinobu-assets`: icon packs that only ship their source** (Fluent, WhiteSur, Tela and Colloid; out of the setup until then, decided on 2026-11-17). Their `install.sh` does not just copy a folder: it assembles each variant (WhiteSur's makes 84 copies, `sed` recolourings and links). Nobody publishes them ready-made in a form a setup can pin: not Ubuntu, Debian or Arch's official repositories, and gnome-look.org's download links expire. The plan, so that no third-party script ever runs on a user's computer:
  1. A public repository `agalvezsh/kinobu-assets` (GPL-3.0, the packs' licence), with `packs.toml`: for each pack its upstream repository, the tag or commit, the SHA-256 of that source archive, the `install.sh` options and the variants to keep (for example Fluent `standard` with its `-dark` and `-light`, WhiteSur `-t default`, Tela `standard`, Colloid default).
  2. A GitHub Actions workflow (`.github/workflows/build.yml`, on manual dispatch and on a tag): on `ubuntu-latest`, for each pack it downloads `https://codeload.github.com/<repo>/tar.gz/<tag>`, checks its SHA-256 against `packs.toml` (stops on a mismatch), runs `bash install.sh -d "$OUT/<pack>" <options>` as a normal user with no network beyond that download, and packs the result reproducibly (`tar --sort=name --mtime=@0 --owner=0 --group=0 -cJf <pack>-<version>.tar.xz`).
  3. A GitHub release per build with the archives, a `SHA256SUMS` file, the upstream source archives themselves (GPL: the source goes with the binaries) and `SOURCES.md` (upstream URL, tag, commit, licence and authors of each pack). Each pack keeps its `COPYING` and `AUTHORS` inside its folder.
  4. In Kinobu, one line per pack (`name|URL of the release archive|SHA-256|folders it contains`), next to the other icon and cursor packs: the setup downloads, checks and unpacks into `$PREFIX/share/icons`; `--update` replaces a pack when its line changes.
  5. Updating a pack: change its tag and SHA-256 in `packs.toml`, run the workflow, copy the new SHA-256 into Kinobu.
  6. Then: the Windows theme back on Fluent and the macOS theme on WhiteSur. The same repository can serve the themes' wallpapers.
- **More agents**, once Claude Code is complete: Codex, then Antigravity CLI (installer, skill, note, subagent, hooks, the approval window and Willow in their headless modes). They were integrated in early 0.1 and taken out to finish one agent first; the facts found for them are in AGENTS.md §8.
- **The boot menu (GRUB)**: left alone for now (decided on 2026-11-18). A theme and showing Windows would touch the boot, with Secure Boot on; only with a test in a virtual machine first.
- **DaVinci Resolve** in the Media creation menu: it is not in APT, snap or the store and needs its own setup.
- **Version names.** From 1.0 on, each major version is named after a fruit (`Kinobu v1.0 (Yuzu)`).
- Willow: more languages, a private mode with a local model, and interrupting it by voice while it speaks (it would hear itself without echo cancellation; the stop button, Esc and the shortcut do it today).
- A desktop notice when Ubuntu's automatic updates start in the background.
