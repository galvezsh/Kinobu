# Roadmap

Only what is still to do. A finished item is deleted and goes to the [Changelog](CHANGELOG.md); git keeps the history.

## 0.4 — next

### Updates

- [ ] **`kinobu --update` updates itself.** Today the installed command runs the installed copy (`/usr/local/share/kinobu/src`), which only reinstalls itself: new changes need `git pull` and `bash kinobu.sh --update` from the project's folder. The installed `kinobu --update` should look in the project's GitHub releases for a newer version than `/usr/local/share/kinobu/version` (`https://api.github.com/repos/agalvezsh/<repo>/releases/latest`, no personal data in the User-Agent), download it, check it (a SHA-256 in the release and a signature, GPG or minisign, since it runs with sudo), keep it in `src/` and run its own `kinobu.sh --update`, with the no-downgrade guard kept. To decide: a notice of a new version (at login or through Echo), and what happens while the repository is private. Later, maybe an APT repository.
- [ ] Until then, **`kinobu --update` says when it runs the installed copy**: it brings nothing new, and the project folder's `kinobu.sh --update` is the one to run.

### Checks on a clean computer

Still to run outside the author's computer (the tests use a fake home folder, a separate GNOME settings database and stand-ins for `sudo`, `curl` and `git`).

- [ ] A full `--install` from scratch in a virtual machine (virt-manager, Ubuntu 26.04, no dedicated graphics card), then review its log.
- [ ] The same with the desktop in English.
- [ ] `--update` from 0.2 and 0.3 on that machine: a theme and look file from 0.1 and 0.2 move to palettes, the theme's wallpapers download.
- [ ] A second user on that machine: the login entry and `kinobu --user`.
- [ ] The app grid keeps its three folders first on a fresh install. On the author's computer GNOME dropped Kinobu's Settings folder because an older folder held two of its apps; Kinobu now takes them out of other folders first.
- [ ] Review the texts of the welcome tour and of the skill, adapted from Orkestr by name only.
- [ ] The menu tests that fail now and then (`tests/pty-run.py`). Cause found on 2026-11-26: not timing but the real internet check before the menus (`online` in `lib/check.sh`, 3 s per server); on an unstable connection it stops the script, no key is typed and the run is cut. Left as is by the author (their connection is unstable); the fix, if wanted, is a `KINOBU_TEST_ONLINE` stand-in for the tests. Then, if they still fail now and then: make them wait for what they need instead of fixed times.
- [ ] The boot splash on a real start: the loop's speed, the size on a 4K screen (Plymouth doubles pictures only on dense screens: a large 4K monitor may need `DeviceScale=2`), with no maker's logo and with an encrypted disk's password box (in the virtual machine), and shutting down.
- [ ] The goodbye on a real shutdown and restart through the computer's own speakers or headphones (through a screen's speakers it is not heard: the screen is already off; accepted).
- [ ] The login screen without Ubuntu's logo (`95-kinobu-login`), seen on a real login.

### Look

- [ ] Possible, not required: **Kinobu's own alert and notice sounds** (a task finished, waiting, a permission, errors, other GNOME alerts), drawn by `tools/login_sound.py` in the same family as the login sound, as a sound theme that inherits Ubuntu's (Yaru) so any sound not drawn keeps Ubuntu's; chosen in the same Seasons section.

- [ ] Later for your own themes, if they are missed: the terminal's own colours, a new palette in a theme, and the theme's own icons, cursor, fonts and wallpapers in the editor (decided on 2026-11-19 to leave them in Seasons' tabs, where they are the user's over any theme; `theme.toml` already takes them by hand).

### Willow, the voice assistant

The author considered Willow done on 2026-11-19; on 2026-11-26 they asked for the voice agent below. On 2026-11-23 they dropped comparing the powers and the two separate agent settings, and asked for the real check below.

- [ ] **Willow drives the full agent by voice** (proposed on 2026-11-26). Today a delegated task opens a terminal with `claude "task"` and the voice stops there. Instead, Willow starts a full Claude Code without a window (`claude -p` with stream-json in and out, the same as its own talk, in the project's folder and with the user's settings, so `CLAUDE.md`, `kinobu-dev` and the hooks load) and stays its voice:
  - The agent's instructions (`--append-system-prompt`): end each turn with `[[say: …]]`, one or two sentences read aloud, and ask one question at a time with `[[ask: …]]`. Code, diffs and commands are never read: a progress card in the window shows them (editing files, running tests).
  - The user's answer goes straight to the agent when it asked something; otherwise Willow answers it or passes it on. The talk stays on the cheap model; only the real work uses the full one.
  - Specs by voice: the agent's questions, the spec read in summary (what it will and will not do), the user's yes, then one notice per finished task.
  - The session is kept: "Open in terminal" resumes it (`claude --resume`); closing Willow during a task asks whether to stop it or carry on in the terminal.
  - First a spike, before touching Willow: the full agent headless with the user's settings, Gate answering its permissions there (the `PermissionRequest` hook, otherwise `--permission-prompts host` or `--permission-prompt-tool` passing them to Gate), and the resume in a terminal. Kinobu never changes the agent's permissions.
  - To decide: actions approved with a click in Gate (recommended: safer and already tested) or by voice.
  - Then: a `Worker` class next to `Agent` and `Background` in `files/apps/voice.py`, tests for the marks, the agent's arguments and the routing, and the docs.

- [ ] A whole conversation, and the real download of the models (about 450 MB, 2 GB with Qwen3-TTS): started on 2026-11-23 in a throwaway home and stopped by a cut in the internet (which led to the download fix). The check: a question spoken by the voice worker, transcribed by Handy, answered by Willow's agent and voiced by each engine. Run it again when the connection is good.

## Later

- **`kinobu-assets`: icon packs that only ship their source** (Fluent, WhiteSur, Tela and Colloid; out of the setup until then, decided on 2026-11-17). Their `install.sh` does not just copy a folder: it assembles each variant (WhiteSur's makes 84 copies, `sed` recolourings and links). Nobody publishes them ready-made in a form a setup can pin: not Ubuntu, Debian or Arch's official repositories, and gnome-look.org's download links expire. The plan, so that no third-party script ever runs on a user's computer:
  1. A public repository `agalvezsh/kinobu-assets` (GPL-3.0, the packs' licence), with `packs.toml`: for each pack its upstream repository, the tag or commit, the SHA-256 of that source archive, the `install.sh` options and the variants to keep (for example Fluent `standard` with its `-dark` and `-light`, WhiteSur `-t default`, Tela `standard`, Colloid default).
  2. A GitHub Actions workflow (`.github/workflows/build.yml`, on manual dispatch and on a tag): on `ubuntu-latest`, for each pack it downloads `https://codeload.github.com/<repo>/tar.gz/<tag>`, checks its SHA-256 against `packs.toml` (stops on a mismatch), runs `bash install.sh -d "$OUT/<pack>" <options>` as a normal user with no network beyond that download, and packs the result reproducibly (`tar --sort=name --mtime=@0 --owner=0 --group=0 -cJf <pack>-<version>.tar.xz`).
  3. A GitHub release per build with the archives, a `SHA256SUMS` file, the upstream source archives themselves (GPL: the source goes with the binaries) and `SOURCES.md` (upstream URL, tag, commit, licence and authors of each pack). Each pack keeps its `COPYING` and `AUTHORS` inside its folder.
  4. In Kinobu, one line per pack (`name|URL of the release archive|SHA-256|folders it contains`), next to the other icon and cursor packs: the setup downloads, checks and unpacks into `$PREFIX/share/icons`; `--update` replaces a pack when its line changes.
  5. Updating a pack: change its tag and SHA-256 in `packs.toml`, run the workflow, copy the new SHA-256 into Kinobu.
  6. Then: the Windows theme back on Fluent and the macOS theme on WhiteSur. The same repository can serve the themes' wallpapers.
- **More agents**, once Claude Code is complete: Codex, then Antigravity CLI (installer, skill, note, subagent, hooks, the approval window and Willow in their headless modes). They were integrated in early 0.1 and taken out to finish one agent first; the facts found for them are in `docs/facts.md`.
- **The boot menu (GRUB)**: left alone for now (decided on 2026-11-18). A theme and showing Windows would touch the boot, with Secure Boot on; only with a test in a virtual machine first.
- **DaVinci Resolve** in the Media creation menu: it is not in APT, snap or the store and needs its own setup.
- **Version names.** From 1.0 on, each major version is named after a fruit (`Kinobu v1.0 (Yuzu)`).
- Willow: more languages, a private mode with a local model, and interrupting it by voice while it speaks (it would hear itself without echo cancellation; the stop button, Esc and the shortcut do it today).
- A desktop notice when Ubuntu's automatic updates start in the background.
