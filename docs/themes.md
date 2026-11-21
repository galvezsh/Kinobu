# Themes — design

Status: **in progress**. Agreed with the author on 2026-11-17. Built in the repository: the engine (`files/apps/kinobu_theme.py`), the eight factory themes (`files/themes/`), the CSS templates and Seasons with its gallery (`files/apps/seasons.py`). Installed by the setup (`lib/look.sh`) with their icon, cursor and font packs. Not yet: wallpapers, the editor, and Fluent, WhiteSur, Tela and Colloid (they wait for `kinobu-assets`, see the roadmap). The open decisions are at the end.

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
| Wallpapers, four (one per workspace, repeated in order on more), and the lock screen | The `workspace-wallpapers` extension (its list filled to 12), `picture-uri`, `picture-uri-dark` and the screensaver key; the theme's pictures come from Wallhaven | Yes |
| Terminal (Ptyxis) | The profile's `palette`: one of the ~200 palettes Ptyxis ships, or one generated from the theme; its colours made legible on its background (4.5 for red to cyan, 7 for the text) | Yes |
| Prompt (Oh My Bash) | Uses the terminal's ANSI colours, so it follows the palette | Yes |
| fastfetch and Kinobu's own terminal output | The theme's accent for each mode, made legible on the terminal's background, in `~/.local/state/kinobu/terminal-{dark,light}` (read by `ff` in `bashrc.sh` and `ui_init` in `lib/ui.sh`; GNOME's accent without them) | Next command |
| Kinobu's apps (Willow, welcome tour, approval window, the themes app) | libadwaita, so they get the GTK CSS | Like other apps |
| Window buttons | `org.gnome.desktop.wm.preferences button-layout`, on the left for macOS | Yes |

Not touched: the GNOME Shell's own styles, snap and Flatpak apps with their own look, Chrome, Spotify, Blender, OBS, GIMP, JetBrains IDEs and the code editors (later, see §9).

### Palettes: a theme does not depend on the mode

A theme has one or more **palettes**, each one **dark or light** and each a whole look: its own colours and terminal (decided on 2026-11-18; before, a theme had one dark and one light "variant"). Tokyo Night has Night, Storm, Moon and Day; Catppuccin has Mocha, Macchiato, Frappé and Latte. **Applying a theme in a palette sets the mode**: the palette decides, not the other way round. In the app a theme is one card with a round button per palette; there is no separate light/dark switch.

Every palette has a **pair**: the palette of the other mode it goes with (Storm ↔ Day). The quick settings dark-style switch still works, **with no program in the background**:

- The palette has a pair: everything moves to it on its own. The apps through the CSS (`@media (prefers-color-scheme)`: one file holds the palette and its pair), the terminal through a Ptyxis palette with a `[Dark]` and a `[Light]` section, the wallpaper through GNOME's own `picture-uri-dark`.
- The theme has no palette of the other mode: its one palette is used in both.
- `kinobu-do style dark|light` (Willow) and `kinobu-theme set <id> --mode dark|light` go to the pair too, or to the first palette of that mode.

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
name = "Tokyo Night"
description = "Neon blues and purples of the city at night."
author = "Kinobu, on Tokyo Night by enkia and folke (MIT)"

icons = "Papirus"                # Yaru follows the accent; or an installed pack
cursor = "Bibata-Modern-Classic" # or one per mode: { dark = "…", light = "…" }
button_layout = "appmenu:minimize,maximize,close"   # "close,minimize,maximize:appmenu" puts them left
gnome_accent = "blue"            # optional; by default the nearest to the palette's accent
intensity = 1                    # Kinobu's details (layer 2): 0 off, 1 default, 2 bold
# interface_font = "Inter 11"    # optional, like monospace_font

# The palettes, in the order Seasons shows them: the first one is the default
[palettes.storm]
name       = "Storm"             # shown in the app
mode       = "dark"              # dark or light
pair       = "day"               # the palette of the other mode (the dark-style switch)
terminal   = "Tokyo Night Storm" # a Ptyxis palette (its side of this mode when it has two)
# terminal_background = "#…"     # optional: the terminal's own background and text
# terminal_foreground = "#…"
accent     = "#7AA2F7"
background = "#24283B"           # windows
view       = "#1F2335"           # content: the files in Files, text, lists
sidebar    = "#1F2335"
card       = "#292E42"           # cards, boxed lists, popovers, dialogs
foreground = "#C0CAF5"
muted      = "#A9B1D6"           # secondary text
success    = "#9ECE6A"
warning    = "#E0AF68"
error      = "#F7768E"
# A palette may also set its own icons, cursor, fonts or gnome_accent.
# At the top, next to icons and cursor:
# wallpapers = ["wallhaven:3zgdd3", "wallhaven:rrpp6m", …]   # four, or { dark = […], light = […] }
# wallhaven = "forest"           # Seasons' "For this theme" search
# wallhaven_colour = "336600"    # one of Wallhaven's colours

[palettes.day]
name = "Day"
mode = "light"
# … the same keys
```

Themes written before palettes (`variants`, a `[dark]` and a `[light]` table, `terminal = { dark = …, light = … }`) still work: each table becomes a palette called `dark` or `light`.

## 5. The CSS, in three layers

Today `files/desktop/gtk4.css` only **tints Yaru with the accent**: the backgrounds stay Yaru's grey. The new CSS goes much deeper, in three layers written to `~/.config/gtk-4.0/kinobu.css` (and `gtk-3.0`), which a managed block of each `gtk.css` imports, as today:

| Layer | What it does | Result |
|---|---|---|
| **1. Palette** (new) | Sets libadwaita's colour variables from the theme, one block for the palette and one for its pair under `@media (prefers-color-scheme: …)`. The theme gives about ten colours; the rest is derived in the CSS with `color-mix` and `oklch` | **Every libadwaita app changes at depth**: the background of Files, its sidebar, dialogs, Settings, Text Editor, Calendar, Mission Center, Kinobu's apps. The method Gradience used |
| **2. Kinobu's details** (today's file) | The gradients, the sidebar indicator, the window buttons, Files' address bar, on top of layer 1 and reading the same variables; `intensity` per theme | Kinobu's character |
| **3. Touches per app** | Files, Text Editor's colour scheme (GtkSourceView), Ptyxis's header bar | No loose ends |

The variables of layer 1 (all present in Ubuntu's libadwaita 1.9): `--window-bg/fg-color`, `--view-bg/fg-color`, `--headerbar-bg/fg/border/backdrop/shade-color`, `--sidebar-bg/fg/backdrop/border/shade-color` and the `--secondary-sidebar-*` ones, `--card-bg/fg/shade-color`, `--dialog-bg/fg-color`, `--popover-bg/fg/shade-color`, `--thumbnail-bg/fg-color`, `--overview-bg/fg-color`, `--accent-bg/fg-color`, `--accent-color`, `--destructive-*`, `--success-*`, `--warning-*`, `--error-*`, `--border-color`, `--shade-color`, `--scrollbar-outline-color`, plus Ubuntu's `--yaru-accent-*` and `--yaru-link-*`.

Done well, not only nice:

- `kinobu-theme validate` refuses a palette whose text reads below 4.5 on any surface. `--strict` also holds it to **Kinobu's bar** (WCAG ratios): text 7 on every surface, secondary text 4.5, the accent 3 against the window. The tests run it on every factory theme: no palette ships foggy. Some palettes are a touch stronger than the originals for this (Kinobu, Tokyo Night Day, Catppuccin Frappé and Latte, Rosé Pine Moon and Dawn, macOS Light); each theme says so in its first lines.
- GTK 3 apps (GIMP, Audacity, Eclipse) keep Yaru with its named colours replaced: partial, and few in the catalogue. `adw-gtk3` (GitHub, LGPL) would make them follow layer 1; to evaluate later.
- The GNOME Shell (panel, menus, notifications) only follows the accent.

## 6. The engine: `kinobu-theme`

Python, like Willow and the approval window. The system's Python 3.14 reads TOML (`tomllib`) and nothing else is needed.

```
kinobu-theme list                      factory and own themes, the active one marked
kinobu-theme current
kinobu-theme set <id> [--palette P | --mode dark|light]   (--variant is an old name of --mode)
kinobu-theme new <id> --from <id>      copies a theme into ~/.config/kinobu/themes to edit it
kinobu-theme validate [--strict] [<id>…]
kinobu-theme refresh                   re-generates the active theme (used by --update)
```

`set` does this: validate → generate the CSS and the Ptyxis palette in memory → write `kinobu.css` for GTK 4 and GTK 3 and the import block of each `gtk.css` → apply the gsettings (mode, accent, Yaru, icons, cursor, window buttons, wallpapers) → set the palette of every Ptyxis profile (making the first one if Ptyxis has none) → save the user's look in `~/.config/kinobu/look.toml` → list what was kept and why (a pack that is not installed, no wallpapers).

### In the setup (done)

- The `desktop` block installs the factory themes and the icon packs they use (system layer). It runs `kinobu-theme set kinobu` only when the user has no theme yet: re-running the setup never changes a chosen theme.
- `--update` runs `kinobu-theme refresh`: template fixes reach every user, their theme is kept.
- `kinobu --user` gives other users the default theme.
- `ACCENT`, `COLOR_SCHEME`, `TERMINAL_PALETTE` and `WALLPAPER_DIR` leave `lib/desktop.sh` and `lib/user.sh`: the theme is the only source.
- The skill (`files/skills/kinobu/look.md`) tells agents to use `kinobu-theme` and never to edit the generated files.

## 7. Factory themes

The most used themes in the world, on Ptyxis's own palettes (checked in Ptyxis 50.1). Some Ptyxis palettes have both modes in one file; for the others the theme names one palette per mode and the engine writes a palette of its own with both, so the quick settings switch still works.

| Theme | Palettes (dark, then light) | Terminal palette (Ptyxis) | Icons | Cursor | Buttons |
|---|---|---|---|---|---|
| **Kinobu** (default) | Forest, Night; Meadow, Birch | Everforest, with Kinobu's background and text | Yaru | Yaru | right |
| Tokyo Night | Night, Storm, Moon; Day, Light | Tokyo Night of each one | Papirus | Bibata Modern Classic | right |
| Catppuccin | Mocha, Macchiato, Frappé, Dracula; Latte, Alucard | Catppuccin of each flavour; dracula (both) | Papirus | Catppuccin (mocha dark / latte light) | right |
| Nord | Polar Night, Polar Night Deep; Snow Storm, Snow Storm Bright | nord (both) | Papirus | Nordzy (dark / white) | right |
| Gruvbox | Dark, Dark Hard; Light, Light Hard | Gruvbox (both; the hard ones with their own background) | Papirus | Bibata Modern Amber | right |
| Rosé Pine | Rosé Pine, Moon; Dawn, Dawn Bright | Rosé Pine, … Moon, … Dawn | Papirus | Phinger (dark / light) | right |
| Windows | Light, Light Soft; Dark, Dark Deep | campbell (both; Windows Terminal's) | Papirus (Fluent once in kinobu-assets) | Bibata Modern Ice | right |
| macOS | Light, Light Soft; Dark, Dark Deep | Terminal Basic / Pro | Kora (WhiteSur once in kinobu-assets) | macOS (black / white) | left |

**At least two dark and two light palettes per theme** (2026-11-18): the official ones where they exist (Tokyo Night Light, Gruvbox's hard ones); otherwise worked out by Kinobu from the theme's own, with more contrast ("Deep" in dark, "Bright" in light) or less glare ("Soft" in light), and written into `theme.toml`. **Dracula joined Catppuccin**: Dracula and Alucard are Catppuccin palettes, Dracula's purple and text on Catppuccin's greys and status colours, blended. A look on the old Dracula theme moves there on its own (`MOVED` in the engine).

The icons and cursors of each theme are a first choice; anyone can change them in Seasons. elementary is offered but no theme uses it: some of its symbolic icons are drawn blank in GNOME. Possible later: Solarized, One, Kanagawa, GitHub (all in Ptyxis).

**Kinobu** is built on Everforest's colours and green accent, the forest suits the tree, with more contrast than Everforest itself (2026-11-18: the original read "foggy", text 7.4 in dark and 4.9 in light): brighter text, warmer and less green greys. Forest (dark), Night (darker) and Meadow (light). The brand gold is not tied to the theme. A **Kinobu original** theme family on minerals (gold, amber, jade, quartz…) is an idea for later; it would need palettes of our own (`[terminal.*]` tables).

### Icons

- **Yaru**: in Ubuntu, one variant per accent.
- **Papirus**: in APT (`papirus-icon-theme`), dark and light.
- **Fluent** and **WhiteSur** (vinceliuice, GPL-3.0): not in APT. Installed from their GitHub releases at a fixed version into the system layer. Licence and installer to verify.
- **Cursors**: Yaru (Ubuntu's), **Bibata** (in APT), WhiteSur cursors (GitHub). A theme sets one; the user can pick another one later.

### Wallpapers and names

- **Four wallpapers per theme, from Wallhaven** (decided on 2026-11-18): their ids are in `theme.toml` and the engine downloads them to `~/.local/share/kinobu/wallpapers` when the theme is applied (on the user's computer; the repository holds no pictures). Chosen by Kinobu among Wallhaven's favourites for each theme's search, without people. Without a connection the current wallpapers stay. Four, always: a workspace beyond the fourth repeats them in order, a missing one is simply not seen; whoever wants the same everywhere uses *On every workspace*. Changing one wallpaper makes all four the user's own (the Follow the theme switch goes off). A `backgrounds/` folder in the theme still works for themes of one's own. One option is to **draw them** with a tool like `tools/branding.py`, from each theme's palette (the rings of the logo, gradients, shapes): our own, free of licences, and possible for the user's themes too.
- The themes are called **Windows** and **macOS** (the author's choice). They use **no Microsoft or Apple wallpapers or logos**: they imitate the look only, and the app describes them as "inspired by".

## 8. The app

**Seasons** (app ID `os.kinobu.Themes`, command `kinobu-launch themes` once it is installed): GTK 4 / libadwaita in Python, with the welcome tour's look, in the Settings folder of the app grid.

A bar at the bottom with five sections (decided on 2026-11-17; built in the repository):

| Section | What it shows |
|---|---|
| **Themes** | A card per theme: a preview drawn from its colours, a round button per palette (its window colour and accent) and *Apply*. Two groups, *System* (Kinobu's) and *User* (the user's own) |
| **Icons** | A card per installed icon pack (Papirus covers Papirus-Dark and -Light), with ten of its own icons; *System* and *User* groups (a pack whose folder is in the home folder is the user's: `users_pack`) |
| **Cursors** | A card per cursor theme, with five of its cursors read from their X cursor files; *System* and *User* groups, as for icons |
| **Fonts** | Interface (menus, windows, documents) and monospace (editors, code), each written in its own font; size; any other font. The terminal keeps the Nerd Font: its prompt needs the symbols |
| **Wallpapers** | One per workspace, the first also the lock screen; *Change…* opens a picture. **Find wallpapers on Wallhaven…** opens a window: a search box on top, random pictures as it opens, the theme's suggestion (`wallhaven` and `wallhaven_colour` in `theme.toml`), the popular ones; *Use* downloads one to `~/Pictures/Wallhaven` and sets it on a workspace or on all of them |

**The theme proposes, the user decides.** Icons, Cursors, Fonts and Wallpapers open with a **Follow the theme** switch. On, the theme chooses and the choices below rest. Off, what the theme gives now becomes the user's own pick, to change as they like; it is kept in `~/.config/kinobu/look.toml` (an empty value means "the theme's") and stays when the theme changes. Turning it on again goes back to the theme's. Kinobu's updates never change that file. No GNOME Shell theme (decided: it can break, even with security updates). `kinobu-theme pick icons|cursor|interface-font|monospace-font|wallpaper N …` does the same from the command line, and `seasons.py --page NAME` opens a section.

**Your own themes** (built in 0.3, kept simple on purpose):

1. **Duplicate**: the menu of any theme card (⋮) makes the user's copy under a name they give: the whole `theme.toml` (palettes, terminal, icons, cursor, wallpapers) in `~/.config/kinobu/themes/<id>/`, its id from the name (`theme_slug`), its opening comments replaced by `# Made in Seasons from …`, a description in the user's language. Then the colour editor opens.
2. **Customise**: one palette at a time (a drop-down), a colour button per colour (`COLOURS`), the theme's own preview drawn live, and the three contrasts against Kinobu's bar (text 7, secondary text 4.5, accent 3). Text below 4.5 cannot be saved (the same rule as `validate`). Saving rewrites only those lines of the palette's table, so the file keeps its comments; a changed accent also sets the palette's `gnome_accent` to the nearest GNOME accent; a theme in use is applied again. The terminal keeps the palette's Ptyxis palette. The editor also sets the theme's window buttons, left or right (`button_layout`). Icons, cursor, fonts and wallpapers are not in the editor on purpose: Seasons' tabs make them the user's over any theme, which is what most people want, and `theme.toml` takes them by hand.
3. **Open the file** and **Delete** (to the Trash; not the theme in use) for the user's themes. Factory themes are never changed in place.
4. The command line does the same: `kinobu-theme new NAME --from ID`, `colour ID PALETTE KEY=#RRGGBB…`, `buttons ID left|right`, `delete ID`; `seasons.py --edit ID` opens the editor (Duplicate for a factory theme).
5. **Later, if missed**: the terminal's own colours, adding a palette, wallpapers by drag and drop, a palette from a wallpaper, importing Omarchy themes (`colors.toml`). Icons and cursors stay packs the user installs.

### Wallhaven

Built on 2026-11-18 (`files/apps/kinobu_wallhaven.py`, the window in `seasons.py`). Wallhaven's public API (`https://wallhaven.cc/api/v1/search`, checked that day) needs no account or key for safe pictures. Kinobu asks for every category (`categories=111`: general, anime, people), `purity=100` (safe for work: the rest needs an account), `ratios=landscape` and at least the size of the largest screen, and keeps only results marked `sfw` with an HTTPS file. Random results come with a `seed` that the next pages reuse. Clicking a picture opens it large (the full file, kept in `~/.cache/kinobu/wallhaven`). The user downloads the pictures on their own computer; Kinobu ships none (the author's decision, 2026-11-18: no further filter). Wallhaven allows 45 requests a minute; thumbnails come from its image server, one after another.

Next: a few chosen pictures per theme (Wallhaven ids in `theme.toml`), downloaded only when the user asks.

## 9. Phases

1. **Engine and format** — *done in the repository*: `theme.toml`, `kinobu-theme`, the CSS layers 1 and 2, GNOME's settings, Ptyxis and the factory themes; tests. Still to do: **the setup**: installing the engine, Seasons, the themes and the templates in the system, Papirus and Bibata from APT, and the `desktop` block applying a theme instead of `ACCENT`, `COLOR_SCHEME` and `TERMINAL_PALETTE`.
2. **Packs, a fixed step of the setup** (not in the menus, nothing to tick) — *done*: installed once for every user in the system, from Ubuntu's archive when it has them (Papirus, Numix Circle, elementary, Bibata, Breeze, Inter, JetBrains Mono) and otherwise as ready-made downloads pinned and checked into `/usr/local/share/icons` (`LOOK_PACKS` in `lib/look.sh`); the engine links the ones in use into each user's folder. Updates may add more. Candidates checked on 2026-11-17: Papirus (Ubuntu's own package, unpacked without installing it), Fluent and WhiteSur icons (GPL-3.0; their `install.sh` assembles them from the source, so it has to be run), Bibata cursors (GPL-3.0, ready-made release files), WhiteSur cursors (GPL-3.0, ready-made in the repository), Inter and JetBrains Mono (OFL-1.1). Cantarell and Adwaita Sans are already in Ubuntu. GNOME Tweaks is no longer installed and the Extensions app is hidden from the app grid. The skill.
3. **The app**: gallery and the sections Icons, Cursors, Fonts and Wallpapers — *done in the repository* (`files/apps/seasons.py`): a card per theme with a preview drawn from its colours, its palettes and Apply; the Follow the theme switches (2026-11-18).
4. **The app**: editor.
5. **Later**: VS Code, Cursor and Antigravity (`workbench.colorTheme` plus the theme's extension), GNOME Text Editor (a GtkSourceView scheme), Omarchy import.

## 10. Checks

Verified on 2026-11-17 (GTK 4.22.4, libadwaita 1.9.1 of Ubuntu, a probe app with `XDG_CONFIG_HOME` pointing at a test folder, no window shown):

- The user's `gtk.css` **overrides libadwaita's colour variables**, the accent included (an exact colour wins over Yaru's).
- `@media (prefers-color-scheme: dark)` works in it: **one file holds a palette and its pair**.
- **Open apps do not reload it**, neither when the file changes nor when `gtk-theme-name` changes: an app gets the new colours when it opens.
- Ptyxis 50.1 ships the palettes of every factory theme; some hold both modes (Everforest, dracula, nord, Gruvbox, campbell), others one each (the five Tokyo Night, the four Catppuccin and the three Rosé Pine). The engine always writes its own `kinobu-<theme>` palette with the chosen palette and its pair.

Found while building it (2026-11-17, in an isolated GNOME Shell, see `tests/desktop-shots.sh`):

- **Ptyxis is always dark by default** (`interface-style` is `'dark'`): the engine sets it to `'system'` so the terminal follows the palette's mode and the dark-style switch.
- Ptyxis reads the user's own palettes from `~/.local/share/org.gnome.Ptyxis/palettes/`; the palette setting holds the file's name without `.palette` (`Everforest`, `dracula`, `kinobu-tokyo-night`).
- Ptyxis makes its default profile on first start; before that the engine makes one, as `lib/user.sh` does.
- An icon or cursor pack that is not installed falls back to Yaru in the theme's accent, never to the pack of the theme before.
- Ubuntu's Yaru variants for GNOME's accents (`blue`, `prussiangreen`, `olive`, `yellow`, plain Yaru for orange, `red`, `magenta`, `purple`, `sage`, `wartybrown`) are taken from the names Ubuntu ships; the pairing for green and slate is a guess to confirm.

To verify:

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
- A theme has **palettes**, each dark or light and a whole look; the palette sets the mode, and the dark-style switch moves to its pair (§2). Decided on 2026-11-18, replacing one dark and one light variant per theme.
- Every factory palette passes `validate --strict` (§5): readable before faithful.
- Seasons' other sections have a **Follow the theme** switch (2026-11-18).
- The CSS goes **in three layers** (§5), libadwaita's variables first.
- The app is called **Seasons**; its app ID is `os.kinobu.Themes`.

Open:

1. **Wallpapers**: drawn by us from each palette, or collected under free licences, or both.
2. **Kinobu original** mineral themes: when and which.
