# Themes — design

Status: **agreed, not implemented**. Agreed with the author on 2026-11-17; the open decisions are at the end.

A theme changes the whole look of the computer in one step: light or dark mode, the accent colour, the colours of the apps, the icons, the wallpapers and the terminal. Switching from Tokyo Night to Everforest should feel like a different computer, not a different accent.

## 1. Principles

- **A theme is data, not code.** A folder with a `theme.toml` (colours and choices) and its wallpapers. Nobody writes CSS to make a theme.
- **One engine, several faces.** `kinobu-theme` is the only thing that applies a theme. The app, `kinobu --install`/`--update`, `kinobu --user` and the agents (through the skill) all call it.
- **Templates belong to Kinobu.** The engine fills templates with the theme's colours. When a template improves, every theme improves on the next `--update`.
- **Only what GNOME supports.** Settings GNOME already has (mode, accent, icons, cursor, wallpapers), our own GTK CSS and the terminal. **No GNOME Shell theme**: the panel, menus and notifications keep Yaru and only follow the accent. GNOME 50 stays for the whole life of Ubuntu 26.04, but a broken Shell is the worst failure for someone new to Linux and the gain is small.
- **Two layers.** Factory themes in the system, the user's own in their home folder, as the rest of Kinobu.
- **Safe to switch.** Everything is generated first and swapped in at once; if a step fails, the previous theme stays.

## 2. What a theme changes

| Part | How | Live? |
|---|---|---|
| Light or dark mode | `org.gnome.desktop.interface color-scheme` | Yes |
| Accent of GNOME, the Shell and Yaru | `accent-color` (one of GNOME's 10: blue, teal, green, yellow, orange, red, pink, purple, slate, brown), the nearest one to the theme's accent unless the theme names one; `gtk-theme` `Yaru-<accent>[-dark]` | Yes |
| Exact app colours (GTK 4, libadwaita and GTK 3) | Three CSS layers (§5): libadwaita's colour variables set from the theme, Kinobu's details, touches per app | When each app opens (verified: no live reload) |
| Icons | `icon-theme`: Yaru (follows the accent) or an installed pack | Yes |
| Cursor | `cursor-theme` | Yes (some apps on restart) |
| Wallpapers, one per workspace, and the lock screen | The `workspace-wallpapers` extension, `picture-uri`, `picture-uri-dark` and the screensaver key, pointing at the theme's folder | Yes |
| Terminal (Ptyxis) | The profile's `palette`: one of the ~200 palettes Ptyxis ships, or one generated from the theme | Yes |
| Prompt (Oh My Bash) | Uses the terminal's ANSI colours, so it follows the palette | Yes |
| fastfetch and Kinobu's own terminal output | The theme's accent instead of today's fixed table of GNOME accents (`ff` in `bashrc.sh`, `ui_accent` in `lib/ui.sh`) | Next command |
| Kinobu's apps (Zen, welcome tour, approval window, the themes app) | libadwaita, so they get the GTK CSS | Like other apps |
| Window buttons | `org.gnome.desktop.wm.preferences button-layout`, on the left for macOS | Yes |

Not touched: the GNOME Shell's own styles, snap and Flatpak apps with their own look, Chrome, Spotify, Blender, OBS, GIMP, JetBrains IDEs and the code editors (later, see §9).

### Families and variants: a theme does not depend on the mode

A theme is a **family** with one or two **variants**, dark and/or light: Catppuccin has Mocha (dark) and Latte (light), Dracula only a dark one. **Each variant is a whole look**: its own colours, terminal palette and, if it wants, its own wallpapers. **Applying a theme sets the mode**: the theme decides, not the other way round. In the app a family is one card, with a variant switch when it has two.

The quick settings dark-style switch still works, **with no program in the background**:

- The family has the other variant: everything moves to it on its own. The apps through the CSS (`@media (prefers-color-scheme)`: one file holds both variants, verified), the terminal through a Ptyxis palette with a `[Light]` and a `[Dark]` section, the wallpaper through GNOME's own `picture-uri-dark`.
- The family has one variant: the apps fall back to plain Yaru in the other mode, with the theme's accent. The app says the theme has no light (or dark) version.

## 3. Layout

```
files/themes/<id>/                     in the repository, installed to:
/usr/local/share/kinobu/themes/<id>/   factory themes ($SYSTEM_DIR/themes)
~/.config/kinobu/themes/<id>/          the user's own; the same id overrides a factory theme
├── theme.toml
├── backgrounds/        1.jpg, 2.jpg … one per workspace; light/1.jpg … optional for light mode
├── preview.png         optional; the app draws one from the wallpaper and the palette
└── overrides/          optional: a file here replaces what a template would generate

/usr/local/share/kinobu/data/theme-templates/   gtk4.css, gtk3.css, ptyxis.palette …
/usr/local/bin/kinobu-theme                      the engine
~/.local/state/kinobu/theme/                     active theme id and the generated files
```

## 4. `theme.toml`

```toml
name = "Everforest"
description = "A calm forest: soft greens on warm grey"
author = "Kinobu (palette by sainnhe, MIT)"
variants = ["dark", "light"]     # the ones it has; the first one is applied by default

icons = "Yaru"                   # Yaru follows the accent; or an installed pack
cursor = "Yaru"                  # part of the look; the user can still pick another one
button_layout = "appmenu:minimize,maximize,close"   # "close,minimize,maximize:appmenu" puts them left
terminal = "Everforest"          # a Ptyxis palette that has both modes, or one per mode:
# terminal = { dark = "Tokyo Night", light = "Tokyo Night Day" }
# or the [terminal.*] tables below for colours of its own
# gnome_accent = "green"         # optional; by default the nearest to the first variant's accent
intensity = 1                    # Kinobu's details (layer 2): 0 off, 1 default, 2 bold

[dark]                           # one table per variant
name       = "Everforest Dark"   # shown in the app
accent     = "#A7C080"
background = "#2D353B"           # windows
view       = "#343F44"           # content: the files in Files, text, lists
sidebar    = "#272E33"
card       = "#3D484D"           # cards, boxed lists, popovers, dialogs
foreground = "#D3C6AA"
muted      = "#859289"           # secondary text
success    = "#A7C080"
warning    = "#DBBC7F"
error      = "#E67E80"
# Optional, derived in the CSS when missing: headerbar, border, shade, selection, link…

[light]
name       = "Everforest Light"
accent     = "#8DA101"
# … the same keys

# Only for a palette Ptyxis does not have:
# [terminal.dark]
# background = "#…"  foreground = "#…"  cursor = "#…"
# colors = ["#…", … 16 colours]
```

`kinobu-theme validate` checks the keys, the colours and that the icons, the cursor and the Ptyxis palette exist on the computer.

## 5. The CSS, in three layers

Today `files/desktop/gtk4.css` only **tints Yaru with the accent**: the backgrounds stay Yaru's grey. The new CSS goes much deeper, in three layers written into the managed block of `~/.config/gtk-4.0/gtk.css` (and `gtk-3.0`):

| Layer | What it does | Result |
|---|---|---|
| **1. Palette** (new) | Sets libadwaita's colour variables from the theme, one block per variant under `@media (prefers-color-scheme: …)`. The theme gives about ten colours; the rest is derived in the CSS with `color-mix` and `oklch` | **Every libadwaita app changes at depth**: the background of Files, its sidebar, dialogs, Settings, Text Editor, Calendar, Mission Center, Kinobu's apps. The method Gradience used |
| **2. Kinobu's details** (today's file) | The gradients, the sidebar indicator, the window buttons, Files' address bar, on top of layer 1 and reading the same variables; `intensity` per theme | Kinobu's character |
| **3. Touches per app** | Files, Text Editor's colour scheme (GtkSourceView), Ptyxis's header bar | No loose ends |

The variables of layer 1 (all present in Ubuntu's libadwaita 1.9): `--window-bg/fg-color`, `--view-bg/fg-color`, `--headerbar-bg/fg/border/backdrop/shade-color`, `--sidebar-bg/fg/backdrop/border/shade-color` and the `--secondary-sidebar-*` ones, `--card-bg/fg/shade-color`, `--dialog-bg/fg-color`, `--popover-bg/fg/shade-color`, `--thumbnail-bg/fg-color`, `--overview-bg/fg-color`, `--accent-bg/fg-color`, `--accent-color`, `--destructive-*`, `--success-*`, `--warning-*`, `--error-*`, `--border-color`, `--shade-color`, `--scrollbar-outline-color`, plus Ubuntu's `--yaru-accent-*` and `--yaru-link-*`.

Done well, not only nice:

- `kinobu-theme validate` checks the **contrast** of every variant (text on background, on views and cards, text on the accent) against accessibility minimums.
- **Automatic tests** read the colours GTK really computes for each theme and variant, without showing windows (the method of the checks in §10).
- GTK 3 apps (GIMP, Audacity, Eclipse) keep Yaru with its named colours replaced: partial, and few in the catalogue. `adw-gtk3` (GitHub, LGPL) would make them follow layer 1; to evaluate later.
- The GNOME Shell (panel, menus, notifications) only follows the accent.

## 6. The engine: `kinobu-theme`

Python, like Zen and the approval window. The system's Python 3.14 reads TOML (`tomllib`) and nothing else is needed.

```
kinobu-theme list                      factory and own themes, the active one marked
kinobu-theme current
kinobu-theme set <id> [--variant dark|light]
kinobu-theme new <id> --from <id>      copies a theme into ~/.config/kinobu/themes to edit it
kinobu-theme validate <id | folder>
kinobu-theme refresh                   re-generates the active theme (used by --update)
```

`set` does this: validate → render every template into a temporary folder → swap it with `~/.local/state/kinobu/theme/` → write the managed block of each `gtk.css` → apply the gsettings in one go → select the Ptyxis palette (writing it first if the theme brings its own) → say which open apps need a restart.

### In the setup

- The `desktop` block installs the factory themes and the icon packs they use (system layer). It runs `kinobu-theme set kinobu` only when the user has no theme yet: re-running the setup never changes a chosen theme.
- `--update` runs `kinobu-theme refresh`: template fixes reach every user, their theme is kept.
- `kinobu --user` gives other users the default theme.
- `ACCENT`, `COLOR_SCHEME`, `TERMINAL_PALETTE` and `WALLPAPER_DIR` leave `lib/desktop.sh` and `lib/user.sh`: the theme is the only source.
- The skill (`files/skill/desktop.md`) tells agents to use `kinobu-theme` and never to edit the generated files.

## 7. Factory themes

The most used themes in the world, on Ptyxis's own palettes (checked in Ptyxis 50.1). Some Ptyxis palettes have both modes in one file; for the others the theme names one palette per mode and the engine writes a palette of its own with both, so the quick settings switch still works.

| Theme | Variants | Terminal palette (Ptyxis) | Icons | Cursor | Buttons |
|---|---|---|---|---|---|
| **Kinobu** (default) | dark, light | Everforest (both) | Yaru | Yaru | right |
| Tokyo Night | dark, light | Tokyo Night / Tokyo Night Day | Papirus | Bibata | right |
| Catppuccin | dark, light | Catppuccin Mocha / Catppuccin Latte | Papirus | Bibata | right |
| Dracula | dark, light | dracula (both) | Papirus | Bibata | right |
| Nord | dark, light | nord (both) | Papirus | Bibata | right |
| Gruvbox | dark, light | Gruvbox (both) | Papirus | Bibata | right |
| Rosé Pine | dark, light | Rosé Pine / Rosé Pine Dawn | Papirus | Bibata | right |
| Windows | light, dark | campbell (both; Windows Terminal's) | Fluent | to choose | right |
| macOS | light, dark | Terminal Basic / to choose | WhiteSur | WhiteSur cursors | left |

The icon and cursor of each theme are a first proposal, to settle when we see them. Possible later: Solarized, One, Kanagawa, GitHub (all in Ptyxis).

**Kinobu** is Everforest with Everforest's green accent: the forest suits the tree. The brand gold is not tied to the theme. A **Kinobu original** theme family on minerals (gold, amber, jade, quartz…) is an idea for later; it would need palettes of our own (`[terminal.*]` tables).

### Icons

- **Yaru**: in Ubuntu, one variant per accent.
- **Papirus**: in APT (`papirus-icon-theme`), dark and light.
- **Fluent** and **WhiteSur** (vinceliuice, GPL-3.0): not in APT. Installed from their GitHub releases at a fixed version into the system layer. Licence and installer to verify.
- **Cursors**: Yaru (Ubuntu's), **Bibata** (in APT), WhiteSur cursors (GitHub). A theme sets one; the user can pick another one later.

### Wallpapers and names

- Every wallpaper must be our own or under a free licence, with its source and licence noted next to it. Nine themes with one wallpaper per workspace is about 36 images: the biggest piece of work that is not code. One option is to **draw them** with a tool like `tools/branding.py`, from each theme's palette (the rings of the logo, gradients, shapes): our own, free of licences, and possible for the user's themes too.
- The themes are called **Windows** and **macOS** (the author's choice). They use **no Microsoft or Apple wallpapers or logos**: they imitate the look only, and the app describes them as "inspired by".

## 8. The app

GTK 4 / libadwaita in Python, with the welcome tour's look. In the Settings folder of the app grid, plus `kinobu-launch themes`.

1. **Gallery**: one card per theme (wallpaper, a strip with its palette, its name), the active one marked, light/dark switch for themes with both; *Apply*. Own themes can be edited, duplicated and deleted.
2. **Editor**: start from any theme; name, modes, accent with a colour picker, the interface colours, the terminal palette (a Ptyxis one or own colours), icons, wallpapers by drag and drop (one per workspace); a live preview; saved to `~/.config/kinobu/themes`.
3. **Later**: a palette from a wallpaper, importing Omarchy themes (`colors.toml`), a keyboard shortcut.

## 9. Phases

1. **Engine and format**: `theme.toml`, `kinobu-theme`, the CSS layers 1 and 2 and the other templates (GNOME settings, Ptyxis, fastfetch, Kinobu's output), the setup changes and the factory themes with Yaru, Papirus and Bibata. Command line only. Tests. It starts with the palette layer and Kinobu (Everforest) in both variants, to see Files and Settings changed before the other themes.
2. **Icons and cursors from GitHub** (Fluent, WhiteSur) and the Windows and macOS themes; the skill.
3. **The app**: gallery.
4. **The app**: editor.
5. **Later**: VS Code, Cursor and Antigravity (`workbench.colorTheme` plus the theme's extension), GNOME Text Editor (a GtkSourceView scheme), Omarchy import.

## 10. Checks

Verified on 2026-11-17 (GTK 4.22.4, libadwaita 1.9.1 of Ubuntu, a probe app with `XDG_CONFIG_HOME` pointing at a test folder, no window shown):

- The user's `gtk.css` **overrides libadwaita's colour variables**, the accent included (an exact colour wins over Yaru's).
- `@media (prefers-color-scheme: dark)` works in it: **one file holds both variants**.
- **Open apps do not reload it**, neither when the file changes nor when `gtk-theme-name` changes: an app gets the new colours when it opens.
- Ptyxis 50.1 ships the palettes of every factory theme; some hold both variants (Everforest, dracula, nord, Gruvbox, campbell), others one each (Tokyo Night and Tokyo Night Day, Catppuccin Mocha and Latte, Rosé Pine and Dawn).

To verify in phase 1:

- GTK 3 with Yaru: which named colours its CSS still honours.
- How Ubuntu switches `gtk-theme` between `Yaru-<accent>` and `Yaru-<accent>-dark` when the mode changes, and how Ubuntu maps GNOME's 10 accents to the Yaru variants (blue, prussiangreen, olive, sage, yellow, wartybrown, red, magenta, purple…).
- Ptyxis's folder for the user's own palettes (`~/.local/share/org.gnome.Ptyxis/palettes/` is likely: the binary has user palettes) and whether a new file is seen without restarting it.
- The licences of the palettes (Tokyo Night, Dracula, Everforest, Catppuccin: MIT is expected) and of the icon packs.

## 11. Decisions

Taken on 2026-11-17:

- **Kinobu** is Everforest with its green accent; the brand gold does not define the theme.
- The themes **Windows** and **macOS** keep those names.
- The factory set is the most used themes, on Ptyxis's palettes (§7), Nord included.
- A theme changes **everything**, window buttons and cursor included (the buttons are the `button-layout` key GNOME Tweaks sets). The user can still change any of them afterwards.
- A theme is a **family of one or two variants**, each a whole look; the theme sets the mode, and the dark-style switch moves to the other variant when there is one (§2).
- The CSS goes **in three layers** (§5), libadwaita's variables first.

Open:

1. **Wallpapers**: drawn by us from each palette, or collected under free licences, or both.
2. **The app's name**: "Kinobu Themes" or a name from the tree metaphor.
3. **Kinobu original** mineral themes: when and which.
