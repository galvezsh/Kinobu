# Kinobu themes: the engine behind Seasons and the kinobu-theme command. Written by Kinobu:
# rewritten on every run and --update.
#
# A theme is a folder with a theme.toml (its choices and its palettes, each one dark or light) and,
# optionally, backgrounds/.
# Factory themes live in Kinobu's system folder, the user's own in ~/.config/kinobu/themes (the
# same id overrides a factory theme). Applying one fills Kinobu's templates with its colours
# (the GTK CSS, a Ptyxis palette) and sets GNOME's settings; nothing runs in the background.
# Design: docs/themes.md in Kinobu's repository.
#
# Usage: kinobu-theme list | current | set <id> [--palette P | --mode dark|light]
#        | validate [--strict] [<id>...] | refresh | pick ... | css <id> [--palette P] [--gtk3]
import argparse
import configparser
import json
import os
import re
import subprocess
import sys
import tomllib

SYSTEM_DIR = "@SYSTEM_DIR@"
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = SYSTEM_DIR.startswith("@")             # run from the repository (files/apps)
APP_ID = "kinobu"

# Always under HOME, like the rest of Kinobu: the setup's tests give HOME a folder of their own
# but keep the real XDG_CONFIG_HOME (dconf needs it), so XDG_* would point at the real one
HOME = os.path.expanduser("~")
CONFIG = os.path.join(HOME, ".config")
DATA = os.path.join(HOME, ".local", "share")
STATE = os.path.join(HOME, ".local", "state")

USER_THEMES = os.path.join(CONFIG, "kinobu", "themes")
if REPO:
    SYSTEM_THEMES = os.path.join(HERE, "..", "themes")
    TEMPLATES = os.path.join(HERE, "..", "themes", "templates")
    DETAILS = {4: os.path.join(HERE, "..", "desktop", "gtk4.css"),
               3: os.path.join(HERE, "..", "desktop", "gtk3.css")}
else:
    SYSTEM_THEMES = os.path.join(SYSTEM_DIR, "themes")
    TEMPLATES = os.path.join(SYSTEM_DIR, "data", "theme-templates")
    DETAILS = {4: os.path.join(TEMPLATES, "gtk4-details.css"),
               3: os.path.join(TEMPLATES, "gtk3-details.css")}
LOOK_FILE = os.path.join(CONFIG, "kinobu", "look.toml")
# Four wallpapers, one per workspace; more workspaces repeat them in order (the extension's list is
# filled to EXTENSION_SLOTS, so new or dynamic workspaces always have one). Themes' wallpapers from
# Wallhaven are downloaded here, by the user, when the theme is applied.
WALL_SLOTS = 4
EXTENSION_SLOTS = 12
WALLPAPERS_DIR = os.path.join(DATA, "kinobu", "wallpapers")
PTYXIS_PALETTES = os.path.join(DATA, "org.gnome.Ptyxis", "palettes")

MODES = ("dark", "light")
# What a good palette reads like (WCAG ratios): text on every surface, secondary text, and the
# accent against the window. validate --strict holds the factory themes to them.
QUALITY = {"text": 7.0, "muted": 4.5, "accent": 3.0}
COLOURS = ("accent", "background", "view", "sidebar", "card", "foreground", "muted",
           "success", "warning", "error")
# GNOME's accents and the Yaru variant Ubuntu pairs with each ("" is plain Yaru)
GNOME_ACCENTS = {
    "blue": ("#3584E4", "blue"), "teal": ("#2190A4", "prussiangreen"),
    "green": ("#3A944A", "olive"), "yellow": ("#C88800", "yellow"),
    "orange": ("#ED5B00", ""), "red": ("#E62D42", "red"), "pink": ("#D56199", "magenta"),
    "purple": ("#9141AC", "purple"), "slate": ("#6F8396", "sage"),
    "brown": ("#B5835A", "wartybrown"),
}
BEGIN, END = f"/* >>> {APP_ID} >>> */", f"/* <<< {APP_ID} <<< */"


class ThemeError(Exception):
    pass


# --- Colours ----------------------------------------------------------------------------------
def rgb(hex_colour):
    h = hex_colour.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def to_hex(c):
    return "#" + "".join(f"{round(max(0, min(1, v)) * 255):02X}" for v in c)


def mix(a, b, amount):
    """a mixed with amount (0-1) of b."""
    ca, cb = rgb(a), rgb(b)
    return to_hex(tuple(x + (y - x) * amount for x, y in zip(ca, cb)))


def luminance(hex_colour):
    def lin(v):
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(v) for v in rgb(hex_colour))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def text_on(background):
    """White on strong colours (as GNOME does on its blue), black on light ones."""
    if contrast(background, "#FFFFFF") >= 3.0:
        return "#FFFFFF"
    return "#000000" if contrast(background, "#000000") >= contrast(background, "#FFFFFF") else "#FFFFFF"


def readable(colour, background, foreground, minimum=4.5):
    """The colour moved towards the text colour until it reads on the background."""
    out, step = colour, 0
    while contrast(out, background) < minimum and step < 20:
        step += 1
        out = mix(colour, foreground, step * 0.05)
    return out


# The ANSI colours that carry text in a terminal (red to cyan, normal and bright); black and white
# are meant to sit near the background or the text, so they are left as they are.
ANSI_TEXT = [f"Color{i}" for i in (*range(1, 7), *range(9, 15))]


def legible(colour, background, minimum=4.5):
    """The colour darkened (on a light background) or lightened (on a dark one), its hue kept,
    until it reads on the background like text does."""
    towards = "#000000" if luminance(background) > 0.18 else "#FFFFFF"
    out, step = colour, 0
    while contrast(out, background) < minimum and step < 20:
        step += 1
        out = mix(colour, towards, step * 0.05)
    return out


def nearest_accent(hex_colour):
    def lab(c):   # OKLab
        r, g, b = rgb(c)
        def lin(v):
            return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
        r, g, b = lin(r), lin(g), lin(b)
        l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
        m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
        s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
        return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    x = lab(hex_colour)
    # hue and chroma matter more than lightness: weight a and b
    return min(GNOME_ACCENTS, key=lambda k: sum(w * (p - q) ** 2 for w, p, q in
                                                 zip((0.3, 1, 1), x, lab(GNOME_ACCENTS[k][0]))))


# --- Themes -----------------------------------------------------------------------------------
def theme_dirs():
    """Where themes live, the user's first (their copy of a factory theme wins)."""
    extra = [d for d in os.environ.get("KINOBU_THEME_DIRS", "").split(":") if d]
    return extra + [USER_THEMES, SYSTEM_THEMES]


def theme_ids():
    seen = []
    for base in theme_dirs():
        if not os.path.isdir(base):
            continue
        for name in sorted(os.listdir(base)):
            if name not in seen and os.path.isfile(os.path.join(base, name, "theme.toml")):
                seen.append(name)
    return seen


def load(theme_id):
    for base in theme_dirs():
        path = os.path.join(base, theme_id)
        toml = os.path.join(path, "theme.toml")
        if os.path.isfile(toml):
            try:
                with open(toml, "rb") as f:
                    data = tomllib.load(f)
            except (OSError, tomllib.TOMLDecodeError) as e:
                raise ThemeError(f"{theme_id}: theme.toml cannot be read ({e})")
            data["id"], data["path"] = theme_id, path
            data["own"] = os.path.realpath(base) == os.path.realpath(USER_THEMES)
            normalise(data)
            return data
    raise ThemeError(f"No theme called '{theme_id}'")


def normalise(theme):
    """theme["palettes"]: {id: table}, in the file's order. Themes written before palettes (a
    [dark] and/or a [light] table, "variants" and a terminal per variant) still work."""
    palettes = theme.get("palettes")
    if not isinstance(palettes, dict):
        palettes = {}
        terminal = theme.get("terminal")
        for mode in theme.get("variants") or [m for m in MODES if m in theme]:
            table = theme.get(mode)
            if isinstance(table, dict):
                table = dict(table, mode=mode)
                if isinstance(terminal, dict):
                    table.setdefault("terminal", terminal.get(mode) or next(iter(terminal.values()), ""))
                elif isinstance(terminal, str):
                    table.setdefault("terminal", terminal)
                palettes[mode] = table
    theme["palettes"] = {pid: table for pid, table in palettes.items() if isinstance(table, dict)}


def mode_of(theme, pid):
    return theme["palettes"][pid].get("mode", "dark")


def pair_of(theme, pid):
    """The palette of the other mode that goes with this one (the dark-style switch), or None."""
    mode = mode_of(theme, pid)
    wanted = theme["palettes"][pid].get("pair")
    if wanted in theme["palettes"] and mode_of(theme, wanted) != mode:
        return wanted
    return next((p for p in theme["palettes"] if mode_of(theme, p) != mode), None)


def palette_name(theme, pid):
    return theme["palettes"][pid].get("name", pid)


# Factory themes that became palettes of another one: old look files land on the same colours
MOVED = {"dracula": ("catppuccin", {"dracula": "dracula", "alucard": "alucard", "dark": "dracula",
                                    "light": "alucard"})}


def moved(theme_id, palette=None, mode=None):
    """(theme, palette, mode) for a theme that moved, unless the user has their own of that id."""
    if theme_id in MOVED and not any(os.path.isfile(os.path.join(base, theme_id, "theme.toml"))
                                     for base in theme_dirs()):
        new, palettes = MOVED[theme_id]
        return new, palettes.get(palette) or palettes.get(mode) or palettes["dark"], None
    return theme_id, palette, mode


def resolve(theme, palette=None, mode=None, before=None):
    """The palette to apply: the one asked for; for a mode, the one in use if it has that mode,
    else its pair, else the first of that mode; with neither, the one in use (before) or the first."""
    palettes = theme["palettes"]
    if palette:
        if palette not in palettes:
            raise ThemeError(f"{theme.get('name', theme['id'])} has no palette '{palette}' "
                             f"(it has: {', '.join(palettes)})")
        return palette
    before = before if before in palettes else None
    if mode:
        if before and mode_of(theme, before) == mode:
            return before
        if before and pair_of(theme, before) and mode_of(theme, pair_of(theme, before)) == mode:
            return pair_of(theme, before)
        found = next((p for p in palettes if mode_of(theme, p) == mode), None)
        if not found:
            raise ThemeError(f"{theme.get('name', theme['id'])} has no {mode} palette")
        return found
    return before or next(iter(palettes))


def load_all():
    themes = []
    for theme_id in theme_ids():
        try:
            themes.append(load(theme_id))
        except ThemeError:
            pass
    order = ["kinobu"]   # Kinobu's own first, then by name
    return sorted(themes, key=lambda t: (t["id"] not in order, t.get("name", t["id"]).lower()))


def validate(theme):
    """Problems that stop a theme, as plain sentences (an empty list is a good theme)."""
    problems = []
    if not theme.get("palettes"):
        problems.append("it needs at least one palette: a [palettes.<id>] table")
    for pid, colours in theme.get("palettes", {}).items():
        where = f"[palettes.{pid}]"
        if colours.get("mode", "dark") not in MODES:
            problems.append(f"{where} mode must be dark or light")
        bad = False
        for key in COLOURS:
            value = colours.get(key, "")
            if not re.fullmatch(r"#[0-9A-Fa-f]{6}", str(value)):
                problems.append(f"{where} {key} must be a colour like #A7C080")
                bad = True
        if bad:
            continue
        for surface in ("background", "view", "card", "sidebar"):
            ratio = contrast(colours["foreground"], colours[surface])
            if ratio < 4.5:
                problems.append(f"{where} text on {surface} is hard to read (contrast {ratio:.1f}, 4.5 needed)")
    return problems


def quality(theme):
    """Where a valid theme reads worse than QUALITY asks (warnings, not problems)."""
    notes = []
    for pid, c in theme["palettes"].items():
        where = f"[palettes.{pid}]"
        text = min(contrast(c["foreground"], c[s]) for s in ("background", "view", "card", "sidebar"))
        muted = min(contrast(c["muted"], c[s]) for s in ("background", "view"))
        accent = contrast(c["accent"], c["background"])
        for what, ratio in (("text", text), ("muted", muted), ("accent", accent)):
            if ratio < QUALITY[what]:
                notes.append(f"{where} {what} contrast {ratio:.1f} ({QUALITY[what]:g} wanted)")
    return notes


def colours_for(theme, pid):
    """Every colour the templates need for one palette, derived where the theme is silent."""
    c = {k: v for k, v in theme["palettes"][pid].items() if isinstance(v, str)}
    dark = mode_of(theme, pid) == "dark"
    c.setdefault("headerbar", c["background"])
    c["accent_fg"] = text_on(c["accent"])
    c["accent_text"] = readable(c["accent"], c["view"], c["foreground"])
    for key in ("success", "warning", "error"):
        c[f"{key}_fg"] = text_on(c[key])
        c[f"{key}_text"] = readable(c[key], c["view"], c["foreground"])
    # rgba() with commas: GTK 3 does not read the CSS 4 form, GTK 4 reads both
    c["shade"] = "rgba(0,0,6,0.25)" if dark else "rgba(0,0,6,0.07)"
    c["shade_strong"] = "rgba(0,0,6,0.45)" if dark else "rgba(0,0,6,0.15)"
    c["intensity"] = str(theme.get("intensity", 1))
    c["VARIANT"] = f"{c.get('name', pid)}, {'dark' if dark else 'light'}"
    return c


def fill(template, values):
    return re.sub(r"@([A-Za-z_]+)@", lambda m: values.get(m.group(1), m.group(0)), template)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def gtk4_css(theme, pid):
    """Layer 1 (the palette and its pair, one block per mode) and layer 2 (Kinobu's details). The
    pair answers GNOME's dark-style switch at once; a palette without a pair is used in both modes."""
    template = read(os.path.join(TEMPLATES, "gtk4-palette.css"))
    name = f"{theme.get('name', theme['id'])} {palette_name(theme, pid)}"
    out = [f"/* Written by Kinobu from the theme '{name}': rewritten "
           "whenever a theme is applied. Put your own CSS in gtk.css, outside the kinobu block. */\n"]
    pair = pair_of(theme, pid)
    if pair:
        for one in (pid, pair):
            out.append(f"@media (prefers-color-scheme: {mode_of(theme, one)}) {{\n:root {{\n"
                       f"{fill(template, colours_for(theme, one))}}}\n}}\n")
    else:
        out.append(f":root {{\n{fill(template, colours_for(theme, pid))}}}\n")
    details = read(DETAILS[4])
    details = re.sub(r"^\s*--kinobu-intensity:.*$\n?", "", details, flags=re.M)   # the theme's
    out.append(details)
    return "\n".join(out)


def gtk3_css(theme, pid):
    palette = fill(read(os.path.join(TEMPLATES, "gtk3-palette.css")), colours_for(theme, pid))
    return palette + "\n" + read(DETAILS[3])


# --- Applying ---------------------------------------------------------------------------------
# --- The user's own themes: a copy of any theme, its colours changed in Seasons ----------------
def theme_slug(name):
    """A theme id from its name: lowercase letters, digits and dashes, never one in use."""
    import unicodedata
    plain = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    slug = re.sub(r"[^a-z0-9]+", "-", plain.lower()).strip("-")[:40] or "my-theme"
    taken, out, n = set(theme_ids()), slug, 2
    while out in taken:
        out, n = f"{slug}-{n}", n + 1
    return out


def toml_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def set_top_key(text, key, value):
    """theme.toml with a top-level key (before the first table) set to a string."""
    head, sep, tables = text.partition("\n[")
    line = f"{key} = {toml_string(value)}"
    pattern = re.compile(rf"^{key}\s*=.*$", re.M)
    head = pattern.sub(lambda m: line, head, count=1) if pattern.search(head) else head.rstrip("\n") + "\n" + line + "\n"
    return head + sep + tables


def new_theme(from_id, name, description=None):
    """Makes the user's own copy of a theme under a new name; returns its id. The copy keeps
    everything (palettes, terminal, icons, wallpapers); Seasons then changes its colours."""
    import shutil
    source = load(from_id)
    name = " ".join(name.split()) or f"{source.get('name', from_id)} 2"
    theme_id = theme_slug(name)
    folder = os.path.join(USER_THEMES, theme_id)
    text = read(os.path.join(source["path"], "theme.toml"))
    text = re.sub(r"\A(?:#.*\n)+\n?", "", text)          # the source's opening comments are about it
    text = set_top_key(text, "name", name)
    text = set_top_key(text, "author", f"You, from {source.get('name', from_id)}")
    if description:
        text = set_top_key(text, "description", description)
    os.makedirs(folder)
    if os.path.isdir(os.path.join(source["path"], "backgrounds")):
        shutil.copytree(os.path.join(source["path"], "backgrounds"), os.path.join(folder, "backgrounds"))
    write_if_changed(os.path.join(folder, "theme.toml"), f"# Made in Seasons from {source.get('name', from_id)}\n" + text)
    return theme_id


def own_theme(theme_id):
    theme = load(theme_id)
    if not theme["own"]:
        raise ThemeError(f"'{theme_id}' is a theme of Kinobu: make your own copy first (kinobu-theme new)")
    return theme


def set_colours(theme_id, pid, colours):
    """Changes colours of one palette of the user's own theme (COLOURS keys, "#RRGGBB"). Refused
    when the text would be hard to read, as validate does; the file keeps its comments."""
    theme = own_theme(theme_id)
    if pid not in theme["palettes"]:
        raise ThemeError(f"'{theme_id}' has no palette '{pid}'")
    for key, value in colours.items():
        if key not in COLOURS or not re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
            raise ThemeError(f"{key} = {value}: a colour key ({', '.join(COLOURS)}) and #RRGGBB")
    trial = dict(theme, palettes=dict(theme["palettes"], **{pid: dict(theme["palettes"][pid], **colours)}))
    problems = [p for p in validate(trial) if f"[palettes.{pid}]" in p]
    if problems:
        raise ThemeError("; ".join(problems))
    if "accent" in colours:   # GNOME's own accent (and Yaru's colour) follow the new one
        colours = dict(colours, gnome_accent=nearest_accent(colours["accent"]))
    def as_value(v):
        return v.upper() if v.startswith("#") else v
    path = os.path.join(theme["path"], "theme.toml")
    lines, inside, done = read(path).split("\n"), False, set()
    for i, line in enumerate(lines):
        if line.startswith("["):
            if inside:                     # keys the palette did not have go at its end
                end = i
                while end > 0 and not lines[end - 1].strip():
                    end -= 1
                lines[end:end] = [f'{k} = "{as_value(v)}"' for k, v in colours.items() if k not in done]
                done.update(colours)
                break
            inside = line.strip() == f"[palettes.{pid}]"
            continue
        m = re.match(r"^(\w+)\s*=", line)
        if inside and m and m.group(1) in colours:
            lines[i] = f'{m.group(1)} = "{as_value(colours[m.group(1)])}"'
            done.add(m.group(1))
    if inside and len(done) < len(colours):   # the last table of the file
        while lines and not lines[-1].strip():
            lines.pop()
        lines += [f'{k} = "{as_value(v)}"' for k, v in colours.items() if k not in done] + [""]
    write_if_changed(path, "\n".join(lines))
    return quality(load(theme_id))


BUTTON_LAYOUTS = {"left": "close,minimize,maximize:appmenu", "right": "appmenu:minimize,maximize,close"}


def button_side(theme):
    """Where a theme puts the window buttons: "left" (as macOS) or "right" (GNOME's default)."""
    return "left" if theme.get("button_layout", "").startswith("close") else "right"


def set_buttons(theme_id, side):
    """Puts the window buttons of the user's own theme on the left or the right."""
    theme = own_theme(theme_id)
    if side not in BUTTON_LAYOUTS:
        raise ThemeError("the window buttons go on the left or the right")
    path = os.path.join(theme["path"], "theme.toml")
    write_if_changed(path, set_top_key(read(path), "button_layout", BUTTON_LAYOUTS[side]))


def delete_theme(theme_id):
    """Sends the user's own theme to the Trash (not the one in use)."""
    theme = own_theme(theme_id)
    if current()[0] == theme_id:
        raise ThemeError("it is the theme in use: apply another one first")
    from gi.repository import Gio
    Gio.File.new_for_path(theme["path"]).trash(None)


def write_if_changed(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        if read(path) == text:
            return
    except OSError:
        pass
    tmp = path + ".kinobu-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def import_block(gtk_css):
    """Adds Kinobu's managed block to gtk.css (the user's own CSS around it is kept)."""
    try:
        text = read(gtk_css)
    except OSError:
        text = ""
    block = f'{BEGIN}\n@import url("{APP_ID}.css");\n{END}'
    if BEGIN in text and END in text:
        text = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), lambda m: block, text, flags=re.S)
    else:
        text = (text.rstrip("\n") + "\n\n" if text.strip() else "") + block + "\n"
    write_if_changed(gtk_css, text)


def settings(schema):
    from gi.repository import Gio
    source = Gio.SettingsSchemaSource.get_default()
    if source is None or source.lookup(schema, True) is None:
        return None
    return Gio.Settings.new(schema)


WALLPAPERS_EXTENSION = ("workspace-wallpapers@jonathan.aljl.eu", "org.gnome.shell.extensions.workspace-wallpapers")


class PausedExtension:
    """A running GNOME Shell extension switched off while its settings change, then on again.

    The per-workspace wallpapers extension needs it: while it runs it takes any outside change
    of the desktop's wallpaper as the user's pick for the workspace on screen (applying a theme
    from the second workspace copied the first wallpaper onto it); switched off it captures
    nothing, and when it starts it shows the right wallpaper of the workspace on screen itself.

    GNOME Shell switches extensions off and on asynchronously (extensionSystem.js): an "on" sent
    before the "off" has finished is lost and the extension stays off (seen on 2026-11-19). So
    each step waits for GNOME to report the state, the extension gets a second before starting,
    and its start is checked and tried once more; whatever happens it is never left off.
    Nothing happens in the tests (their own settings database is not the one GNOME reads) or
    when the extension is not switched on."""
    ACTIVE, INACTIVE = 1, 2           # ExtensionState in GNOME Shell

    def __init__(self, uuid):
        self.uuid, self.bus, self.paused = uuid, None, False
        if os.environ.get("DCONF_PROFILE"):
            return
        from gi.repository import Gio, GLib
        try:
            self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
            if not self.info().get("enabled"):
                return
            self.call("DisableExtension", "(b)")
            self.paused = self.wait(self.INACTIVE)
        except GLib.Error:
            self.paused = False

    def call(self, method, reply):
        from gi.repository import Gio, GLib
        return self.bus.call_sync("org.gnome.Shell.Extensions", "/org/gnome/Shell/Extensions",
                                  "org.gnome.Shell.Extensions", method, GLib.Variant("(s)", (self.uuid,)),
                                  GLib.VariantType(reply), Gio.DBusCallFlags.NONE, 3000, None).unpack()[0]

    def info(self):
        return self.call("GetExtensionInfo", "(a{sv})")

    def wait(self, state, seconds=3.0):
        import time
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            if self.info().get("state") == state:
                return True
            time.sleep(0.1)
        return False

    def resume(self):
        """Switches it on again and checks that it started (True)."""
        if not self.bus or not self.paused:
            return False
        import time
        from gi.repository import Gio, GLib
        Gio.Settings.sync()           # it must read the settings just written
        try:
            for attempt in range(2):
                time.sleep(1.0)
                self.call("EnableExtension", "(b)")
                if self.wait(self.ACTIVE):
                    return True
                self.call("DisableExtension", "(b)")   # lost "on": off for real, then on again
                self.wait(self.INACTIVE)
            self.call("EnableExtension", "(b)")
        except GLib.Error:
            try:
                self.call("EnableExtension", "(b)")
            except GLib.Error:
                pass
        return False


def extension_settings(uuid, schema):
    """Settings of a GNOME Shell extension: their schema lives in the extension's own folder."""
    from gi.repository import Gio
    default = Gio.SettingsSchemaSource.get_default()
    for base in (os.path.join(DATA, "gnome-shell", "extensions"), "/usr/local/share/gnome-shell/extensions",
                 "/usr/share/gnome-shell/extensions"):
        folder = os.path.join(base, uuid, "schemas")
        if not os.path.isfile(os.path.join(folder, "gschemas.compiled")):
            continue
        try:
            source = Gio.SettingsSchemaSource.new_from_directory(folder, default, False)
        except Exception:   # a broken compiled schema: try the next folder
            continue
        found = source.lookup(schema, False)
        if found:
            return Gio.Settings.new_full(found, None, None)
    return settings(schema)


def current_wallpapers():
    """The wallpaper of each workspace now (paths; "" where there is none)."""
    count = workspaces()
    walls = []
    per_workspace = extension_settings(*WALLPAPERS_EXTENSION)
    if per_workspace:
        walls = [uri for uri in per_workspace.get_strv("workspace-wallpapers")]
    if not any(walls):
        background = settings("org.gnome.desktop.background")
        walls = [background.get_string("picture-uri")] if background else []
    from gi.repository import GLib
    paths = []
    for i in range(count):
        uri = walls[i] if i < len(walls) else (walls[0] if len(walls) == 1 else "")
        try:
            paths.append(GLib.filename_from_uri(uri)[0] if uri.startswith("file://") else uri)
        except Exception:
            paths.append("")
    return paths


LINKS_FILE = os.path.join(STATE, "kinobu", "icon-links")


def link_into_home(names):
    """Links the packs in use into ~/.local/share/icons: GNOME sees the system ones anyway, but
    sandboxed (Flatpak) and older apps only look in the home folder. Links Kinobu made before and
    no longer needed are removed; anything else there is the user's and is left alone."""
    home_icons = os.path.join(DATA, "icons")
    try:
        with open(LINKS_FILE, encoding="utf-8") as f:
            old = [line.strip() for line in f if line.strip()]
    except OSError:
        old = []
    made = []
    for name in dict.fromkeys(n for n in names if n):
        found, link = find_dir(name, "icons"), os.path.join(home_icons, name)
        target = os.path.realpath(found) if found else ""
        if not target or target.startswith(os.path.realpath(home_icons) + os.sep):
            continue   # not installed, or a real folder in the home folder
        if os.path.lexists(link) and name not in old:
            continue   # the user's own folder or link: never touched
        if os.path.islink(link) and os.readlink(link) != target:
            os.unlink(link)
        if not os.path.lexists(link):
            os.makedirs(home_icons, exist_ok=True)
            os.symlink(target, link)
        made.append(name)
    for name in old:
        link = os.path.join(home_icons, name)
        if name not in made and os.path.islink(link):
            os.unlink(link)
    write_if_changed(LINKS_FILE, "".join(f"{n}\n" for n in made))


def default_cursor(cursor):
    """~/.icons/default: the cursor for apps that do not read GNOME's setting (X11 ones)."""
    path = os.path.join(HOME, ".icons", "default", "index.theme")
    mark = "# Written by Kinobu (Seasons)"
    try:
        if mark not in read(path):
            return   # the user's own
    except OSError:
        pass
    write_if_changed(path, f"{mark}\n[Icon Theme]\nName=Default\nInherits={cursor}\n")


def find_dir(name, kind):
    """Path of an installed icon or GTK theme, or None."""
    bases = {"icons": [os.path.join(DATA, "icons"), os.path.join(HOME, ".icons"),
                       "/usr/local/share/icons", "/usr/share/icons"],
             "themes": [os.path.join(DATA, "themes"), os.path.join(HOME, ".themes"),
                        "/usr/local/share/themes", "/usr/share/themes"]}[kind]
    for base in bases:
        path = os.path.join(base, name) if name else ""
        # an icon or cursor theme has an index.theme or a cursors folder: Kinobu's own
        # /usr/local/share/icons/Yaru only adds one icon (the dock's Show Apps button) to Ubuntu's Yaru
        if path and os.path.isdir(path) and (kind != "icons" or any(
                os.path.exists(os.path.join(path, f)) for f in ("index.theme", "cursors"))):
            return path
    return None


def users_pack(name):
    """True when an icon pack or cursor theme is the user's own (its folder is in the home
    folder), False for the system's. The links Kinobu makes in ~/.local/share/icons point to the
    system's packs, so they count as the system's."""
    found = find_dir(name, "icons")
    return bool(found) and os.path.realpath(found).startswith(os.path.realpath(HOME) + os.sep)


def gnome_accent(theme, pid):
    """GNOME's accent for a palette: the palette's, the theme's, or the nearest to its colour."""
    return (theme["palettes"][pid].get("gnome_accent") or theme.get("gnome_accent")
            or nearest_accent(theme["palettes"][pid]["accent"]))


def icon_theme(family, mode, yaru):
    """The installed icon theme of a family for a mode (Papirus → Papirus-Dark), or None."""
    dark = mode == "dark"
    if family == "Yaru":
        candidates = ["Yaru" + (f"-{yaru}" if yaru else "") + ("-dark" if dark else ""), "Yaru"]
    else:
        suffixes = ["-Dark", "-dark"] if dark else ["-Light", "-light", ""]
        candidates = [family + s for s in suffixes] + [family]
    return next((c for c in candidates if find_dir(c, "icons")), None)


ICON_BASES = lambda: [os.path.join(DATA, "icons"), os.path.join(HOME, ".icons"),  # noqa: E731
                      "/usr/local/share/icons", "/usr/share/icons"]
NOT_ICON_THEMES = {"hicolor", "locolor", "default", "HighContrast", "ContrastHigh", "gnome",
                   "ubuntu-mono-dark", "ubuntu-mono-light", "Humanity", "Humanity-Dark", "LoginIcons"}


def index_theme(path):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        parser.read(os.path.join(path, "index.theme"), encoding="utf-8")
        return dict(parser["Icon Theme"]) if parser.has_section("Icon Theme") else {}
    except (configparser.Error, UnicodeDecodeError):
        return {}


def icon_family(name):
    if name.startswith("Yaru"):
        return "Yaru"
    return re.sub(r"-(dark|Dark|light|Light)$", "", name)


def icon_families():
    """Installed icon packs, one entry per family (Papirus covers Papirus-Dark and -Light)."""
    families = {}
    for base in ICON_BASES():
        if not os.path.isdir(base):
            continue
        for name in sorted(os.listdir(base)):
            path = os.path.join(base, name)
            if name in NOT_ICON_THEMES or not os.path.isdir(path):
                continue
            info = index_theme(path)
            # Hidden ones are not full packs: GNOME 50's Adwaita has no app icons of its own
            if not info.get("Directories") or info.get("Hidden", "").lower() == "true":
                continue
            family = icon_family(name)
            families.setdefault(family, info.get("Name", family) if family == name else family)
    return sorted(families.items(), key=lambda f: (f[0] != "Yaru", f[1].lower()))


OLD_CURSORS = {"default", "handhelds", "redglass", "whiteglass", "DMZ-Black", "DMZ-White"}   # X11's


def cursor_themes():
    """Installed cursor themes: (id, name)."""
    found = {}
    for base in ICON_BASES():
        if not os.path.isdir(base):
            continue
        for name in sorted(os.listdir(base)):
            path = os.path.join(base, name)
            if name not in OLD_CURSORS and os.path.isdir(os.path.join(path, "cursors")):
                found.setdefault(name, index_theme(path).get("Name", name))
    return sorted(found.items(), key=lambda c: (c[0] != "Yaru", c[1].lower()))


def cursor_file(theme_id, names):
    """The file of the first of the cursor names that a cursor theme has."""
    for base in ICON_BASES():
        for name in names:
            path = os.path.join(base, theme_id, "cursors", name)
            if os.path.exists(path):
                return path
    return None


def font_families():
    try:
        out = subprocess.run(["fc-list", ":", "family"], capture_output=True, text=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return set()
    return {f.strip() for line in out.splitlines() for f in line.split(",") if f.strip()}


def font_family(font):
    """'Inter 11' → 'Inter'."""
    parts = font.rsplit(" ", 1)
    return parts[0] if len(parts) == 2 and re.fullmatch(r"[\d.]+", parts[1]) else font


def ptyxis_palette(name):
    """A palette that ships inside Ptyxis, parsed ({} when it does not exist)."""
    try:
        raw = subprocess.run(["gresource", "extract", "/usr/bin/ptyxis",
                              f"/org/gnome/Ptyxis/palettes/{name}.palette"],
                             capture_output=True, text=True, timeout=10, check=True).stdout
    except (OSError, subprocess.SubprocessError):
        return {}
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    try:
        parser.read_string(raw)
    except configparser.Error:
        return {}
    return {s: dict(parser[s]) for s in parser.sections()}


def terminal_side(theme, pid):
    """The terminal colours of a palette: its Ptyxis palette (the side of its mode when that has
    two), with the theme's own background and text when it gives them."""
    table = theme["palettes"][pid]
    name = table.get("terminal") or ""
    sections = ptyxis_palette(name) if name else {}
    mode = mode_of(theme, pid).capitalize()
    colours = sections.get(mode) or {k: v for k, v in sections.get("Palette", {}).items()
                                     if k not in ("Name", "Primary")}
    colours = dict(colours)
    if colours:
        for key in ("background", "foreground"):
            if table.get(f"terminal_{key}"):
                colours[key.capitalize()] = table[f"terminal_{key}"]
        # Many terminal palettes, the light ones above all, have colours too pale to read on
        # their background (yellow, the bright ones): they are made legible here
        background = colours.get("Background", "")
        if re.fullmatch(r"#[0-9A-Fa-f]{6}", background):
            for key in ANSI_TEXT:
                if re.fullmatch(r"#[0-9A-Fa-f]{6}", colours.get(key, "")):
                    colours[key] = legible(colours[key], background)
            if re.fullmatch(r"#[0-9A-Fa-f]{6}", colours.get("Foreground", "")):   # text, as in the apps
                colours["Foreground"] = legible(colours["Foreground"], background, 7)
    return colours


def terminal_palette(theme, pid):
    """(palette id for Ptyxis, its file): the palette in its mode's side and its pair in the
    other, so the terminal follows the dark-style switch like the apps. (None, None) without one."""
    pair = pair_of(theme, pid) or pid
    sides = {}
    for one in (pid, pair):
        colours = terminal_side(theme, one)
        if not colours:
            return None, None
        sides.setdefault(mode_of(theme, one).capitalize(), colours)
    for mode in ("Dark", "Light"):   # a palette without a pair fills both sides
        sides.setdefault(mode, sides.get("Dark") or sides.get("Light"))
    lines = ["[Palette]", f"Name={theme.get('name', theme['id'])} ({APP_ID.capitalize()})", ""]
    for mode in ("Dark", "Light"):
        lines.append(f"[{mode}]")
        lines += [f"{k}={v}" for k, v in sides[mode].items()]
        lines.append("")
    return f"{APP_ID}-{theme['id']}", "\n".join(lines)


TERMINAL_ACCENT = os.path.join(STATE, "kinobu", "terminal-{mode}")


def terminal_accents(theme, pid):
    """For each mode, the colours Kinobu's terminal output takes from the palette (fastfetch and
    the setup): "accent ring1 ring2" as r;g;b, the accent made legible on the terminal's
    background and the rings near its text with a faint tint of the accent."""
    out = {}
    for one in (pid, pair_of(theme, pid) or pid):
        table, term = theme["palettes"][one], terminal_side(theme, one)
        background = term.get("Background") or table["background"]
        foreground = term.get("Foreground") or table["foreground"]
        accent = legible(table["accent"], background)
        rings = (mix(foreground, accent, 0.12), mix(mix(foreground, background, 0.4), accent, 0.12))
        line = " ".join(";".join(str(round(v * 255)) for v in rgb(c)) for c in (accent, *rings))
        out.setdefault(mode_of(theme, one), line)
    for mode in MODES:   # a palette without a pair gives both modes
        out.setdefault(mode, out.get("dark") or out.get("light"))
    return out


def terminal_colours(theme, pid):
    """The 16 ANSI colours, background and foreground of a palette's terminal (for previews)."""
    return {k: v for k, v in terminal_side(theme, pid).items()
            if k.startswith("Color") or k in ("Background", "Foreground")}


def theme_wallhaven(theme, mode):
    """The Wallhaven ids of a theme's wallpapers ("wallhaven:<id>"; one list, or one per mode)."""
    value = theme.get("wallpapers", [])
    if isinstance(value, dict):
        value = value.get(mode) or next(iter(value.values()), [])
    return [w.split(":", 1)[1] for w in value if isinstance(w, str) and w.startswith("wallhaven:")]


def wallhaven_file(wallhaven_id):
    """The downloaded file of a Wallhaven id, or None."""
    for ext in (".jpg", ".png", ".jpeg", ".webp"):
        path = os.path.join(WALLPAPERS_DIR, f"wallhaven-{wallhaven_id}{ext}")
        if os.path.isfile(path):
            return path
    return None


def wallpapers_to_download(theme, pid):
    """The theme's Wallhaven wallpapers not downloaded yet (Seasons warns that the first time is slower)."""
    return [w for w in theme_wallhaven(theme, mode_of(theme, pid)) if not wallhaven_file(w)]


def fetch_wallpapers(theme, mode):
    """Downloads the theme's Wallhaven wallpapers that are missing, all at once. Returns notes.
    Set KINOBU_NO_DOWNLOAD=1 to skip it (the tests do)."""
    missing = [w for w in theme_wallhaven(theme, mode) if not wallhaven_file(w)]
    if not missing or os.environ.get("KINOBU_NO_DOWNLOAD") == "1":
        return []
    sys.path.insert(0, HERE)   # next to this file, also under python3 -I
    import kinobu_wallhaven as wallhaven
    from concurrent.futures import ThreadPoolExecutor

    def one(wallhaven_id):
        try:
            wallhaven.download(wallhaven.picture(wallhaven_id), WALLPAPERS_DIR)
            return True
        except (wallhaven.WallhavenError, OSError):
            return False
    with ThreadPoolExecutor(max_workers=4) as pool:
        failed = list(pool.map(one, missing)).count(False)
    return [f"{failed} of the theme's wallpapers could not be downloaded (no connection?): "
            "kept the current ones there"] if failed else []


def backgrounds(theme, mode):
    """The theme's wallpapers on this computer: its backgrounds/ folder, or those downloaded."""
    folder = os.path.join(theme["path"], "backgrounds")
    for sub in (os.path.join(folder, mode), folder):
        if os.path.isdir(sub):
            files = sorted(f for f in os.listdir(sub) if f.lower().endswith((".jpg", ".jpeg", ".png", ".webp")))
            if files:
                return [os.path.join(sub, f) for f in files]
    return [p for p in (wallhaven_file(w) for w in theme_wallhaven(theme, mode)) if p]


# --- The user's look ------------------------------------------------------------------------
# Everything the user chose lives in one file of their own: the theme and its palette, and what
# they picked instead of the theme's (icons, cursor, fonts, wallpapers). Kinobu's updates
# improve the themes and never touch this file. An empty value means "the theme's".
LOOK_KEYS = ("theme", "palette", "icons", "cursor", "interface_font", "monospace_font")
LOOK_HEADER = """# Your look: written by Seasons and kinobu-theme, read on every Kinobu update.
# Kinobu's updates never change this file. An empty value means "the theme's".
"""


def read_look():
    look = {key: "" for key in LOOK_KEYS}
    look["wallpapers"], look["mode"] = [], ""
    try:
        with open(LOOK_FILE, "rb") as f:
            data = tomllib.load(f)
    except (OSError, tomllib.TOMLDecodeError):
        return look
    for key in LOOK_KEYS:
        if isinstance(data.get(key), str):
            look[key] = data[key]
    # Before palettes the file held a variant (dark or light): the mode to look for
    look["mode"] = data["variant"] if data.get("variant") in MODES and not look["palette"] else ""
    if isinstance(data.get("wallpapers"), list):
        look["wallpapers"] = [w if isinstance(w, str) else "" for w in data["wallpapers"]]
    return look


def write_look(look):
    def q(value):   # a TOML basic string (JSON's escapes are valid TOML)
        return json.dumps(value, ensure_ascii=False)
    lines = [LOOK_HEADER]
    notes = {"interface_font": "   # e.g. \"Inter 11\"", "monospace_font": "   # editors and code",
             "palette": "   # one of the theme's palettes (kinobu-theme list)"}
    for key in LOOK_KEYS:
        lines.append(f"{key} = {q(look.get(key, ''))}{notes.get(key, '')}")
    walls = ", ".join(q(w) for w in look.get("wallpapers", [])[:WALL_SLOTS])
    lines.append(f"wallpapers = [{walls}]   # four, one per workspace (repeated on more); the first is also the lock screen")
    write_if_changed(LOOK_FILE, "\n".join(lines) + "\n")


def current():
    """(theme id, palette id or None, mode of the file before palettes or None)."""
    look = read_look()
    return (look["theme"] or None), (look["palette"] or None), (look["mode"] or None)


def workspaces():
    wm = settings("org.gnome.desktop.wm.preferences")
    return max(1, wm.get_int("num-workspaces")) if wm else 4


def theme_value(theme, key, pid, default=""):
    """A setting of the theme for a palette: the palette's own, or the theme's, which may be one
    value or one per mode ({dark = …, light = …})."""
    own = theme["palettes"].get(pid, {}).get(key)
    if isinstance(own, str) and own:
        return own
    value = theme.get(key, default)
    if isinstance(value, dict):
        value = value.get(mode_of(theme, pid)) or next(iter(value.values()), default)
    return value or default


def effective(look, theme, pid):
    """What will be applied: the user's picks, or the theme's."""
    mode = mode_of(theme, pid)
    pictures = backgrounds(theme, mode) or backgrounds(theme, "dark") or backgrounds(theme, "light")
    walls = []
    for i in range(WALL_SLOTS):
        mine = look["wallpapers"][i] if i < len(look["wallpapers"]) else ""
        walls.append(mine or (pictures[i % len(pictures)] if pictures else ""))
    return {
        "icons": look["icons"] or theme_value(theme, "icons", pid, "Yaru"),
        "cursor": look["cursor"] or theme_value(theme, "cursor", pid, "Yaru"),
        "interface_font": look["interface_font"] or theme_value(theme, "interface_font", pid),
        "monospace_font": look["monospace_font"] or theme_value(theme, "monospace_font", pid),
        "wallpapers": walls,
    }


def own_wallpapers(look):
    """The four wallpapers as the user's own: theirs, else the theme's, else the desktop's now."""
    try:
        theme = load(look["theme"])
        pid = resolve(theme, look["palette"] or None, look["mode"] or None)
        walls = effective(look, theme, pid)["wallpapers"]
    except (ThemeError, KeyError):
        walls = [""] * WALL_SLOTS
    now = current_wallpapers()
    return [w or (now[i] if i < len(now) else "") for i, w in enumerate(walls)]


def pick(**changes):
    """Changes the user's picks (icons, cursor, fonts, wallpapers; "" goes back to the theme's)
    and applies the look again. Changing one wallpaper makes all four the user's own."""
    look = read_look()
    for key, value in changes.items():
        if key == "wallpaper":
            index, path = value
            walls = own_wallpapers(look)
            walls[index % WALL_SLOTS] = path
            look["wallpapers"] = walls
        elif key == "wallpaper_everywhere":
            look["wallpapers"] = [value] * WALL_SLOTS if value else []
        elif key == "wallpapers":
            look["wallpapers"] = list(value)[:WALL_SLOTS]
        elif key in LOOK_KEYS:
            look[key] = value
    write_look(look)
    if not look["theme"]:
        raise ThemeError("No theme applied yet: choose one first")
    return apply(look["theme"], look["palette"] or None, mode=look["mode"] or None, quiet=True)


def apply(theme_id, palette=None, mode=None, quiet=False):
    """Applies a theme in one of its palettes (or the one of a mode) with the user's picks on top.
    Returns notes for the user (what could not be used and why); quiet leaves out what the user
    already knows (a theme without wallpapers)."""
    theme_id, palette, mode = moved(theme_id, palette, mode)
    theme = load(theme_id)
    problems = validate(theme)
    if problems:
        raise ThemeError(f"{theme_id}: " + "; ".join(problems))
    look = read_look()
    before = look["palette"] if look["theme"] == theme_id else None
    if look["theme"] == theme_id and not before and not palette and not mode:
        mode = look["mode"] or None   # a file from before palettes: keep its mode
    chosen = resolve(theme, palette, mode, before)
    look["theme"], look["palette"], look["mode"] = theme_id, chosen, ""
    notes = []
    if not all(look["wallpapers"][i] if i < len(look["wallpapers"]) else "" for i in range(WALL_SLOTS)):
        notes += fetch_wallpapers(theme, mode_of(theme, chosen))   # the theme's are used somewhere
    use = effective(look, theme, chosen)
    scheme = mode_of(theme, chosen)
    dark = scheme == "dark"

    # Everything is generated first, so a failing template changes nothing
    css4 = gtk4_css(theme, chosen)
    css3 = gtk3_css(theme, chosen)
    pid, palette_file = terminal_palette(theme, chosen)

    write_if_changed(os.path.join(CONFIG, "gtk-4.0", f"{APP_ID}.css"), css4)
    write_if_changed(os.path.join(CONFIG, "gtk-3.0", f"{APP_ID}.css"), css3)
    for version in ("4.0", "3.0"):
        import_block(os.path.join(CONFIG, f"gtk-{version}", "gtk.css"))

    accent = gnome_accent(theme, chosen)
    yaru = GNOME_ACCENTS.get(accent, ("", ""))[1]
    interface = settings("org.gnome.desktop.interface")
    if interface:
        interface.set_string("color-scheme", "prefer-dark" if dark else "prefer-light")
        if "accent-color" in interface.props.settings_schema.list_keys():
            interface.set_enum("accent-color", list(GNOME_ACCENTS).index(accent))
        gtk_theme = "Yaru" + (f"-{yaru}" if yaru else "") + ("-dark" if dark else "")
        if find_dir(gtk_theme, "themes"):
            interface.set_string("gtk-theme", gtk_theme)
        # A pack that is not installed falls back to Yaru in the theme's accent, never to the
        # icons of the theme before
        icons = icon_theme(use["icons"], scheme, yaru)
        if not icons:
            notes.append(f"icons {use['icons']} are not installed: Yaru is used instead")
            icons = icon_theme("Yaru", scheme, yaru)
        if icons:
            interface.set_string("icon-theme", icons)
        cursor = use["cursor"]
        if not find_dir(cursor, "icons"):
            notes.append(f"cursor {cursor} is not installed: Yaru is used instead")
            cursor = "Yaru"
        if find_dir(cursor, "icons"):
            interface.set_string("cursor-theme", cursor)
        link_into_home([icons, cursor])
        default_cursor(cursor)
        # Fonts: the pick, or the theme's, or GNOME's own (a theme without fonts resets them)
        families = font_families() if use["interface_font"] or use["monospace_font"] else set()
        for value, keys in ((use["interface_font"], ("font-name", "document-font-name")),
                            (use["monospace_font"], ("monospace-font-name",))):
            if value and font_family(value) not in families:
                notes.append(f"font {font_family(value)} is not installed: kept Ubuntu's")
                value = ""
            for key in keys:
                if value:
                    interface.set_string(key, value)
                else:
                    interface.reset(key)
    wm = settings("org.gnome.desktop.wm.preferences")
    if wm and theme.get("button_layout"):
        wm.set_string("button-layout", theme["button_layout"])

    # Wallpapers: four, one per workspace and repeated in order on more; the first is also the
    # desktop of both modes and the lock screen
    walls = [w for w in use["wallpapers"] if w and os.path.isfile(w)]
    missing = [w for w in use["wallpapers"] if w and not os.path.isfile(w)]
    if missing:
        notes.append(f"{len(missing)} wallpaper(s) no longer exist: kept the current ones there")
    background = settings("org.gnome.desktop.background")
    if background and walls:
        from gi.repository import GLib
        four = [("file://" + w if w and os.path.isfile(w) else "") for w in use["wallpapers"]]
        uris = [four[i % WALL_SLOTS] for i in range(EXTENSION_SLOTS)]
        per_workspace = extension_settings(*WALLPAPERS_EXTENSION)
        paused = None
        if per_workspace and per_workspace.props.settings_schema.has_key("workspace-wallpapers"):
            paused = PausedExtension(WALLPAPERS_EXTENSION[0])   # off while the wallpapers change
            old = per_workspace.get_strv("workspace-wallpapers")
            uris = [u or (old[i] if i < len(old) else "") for i, u in enumerate(uris)]
            per_workspace.set_value("workspace-wallpapers", GLib.Variant("as", uris))
        if uris[0]:   # the first workspace is also the lock screen, and the desktop without the extension
            background.set_string("picture-uri", uris[0])
            background.set_string("picture-uri-dark", uris[0])
            screensaver = settings("org.gnome.desktop.screensaver")
            if screensaver:
                screensaver.set_string("picture-uri", uris[0])
        if paused and not paused.resume() and paused.paused:
            notes.append("the per-workspace wallpapers extension did not start again: sign out and in")
    elif background and not quiet:
        notes.append("this theme has no wallpapers yet: kept the current ones")

    # Terminal: the accent of Kinobu's own output (fastfetch, the setup), then the palette of
    # every Ptyxis profile
    for mode, line in terminal_accents(theme, chosen).items():
        write_if_changed(TERMINAL_ACCENT.format(mode=mode), line + "\n")
    if pid:
        if palette_file:
            write_if_changed(os.path.join(PTYXIS_PALETTES, f"{pid}.palette"), palette_file)
        ptyxis = settings("org.gnome.Ptyxis")
        if ptyxis:
            from gi.repository import Gio
            # Ptyxis is always dark by default: let it follow the palette's mode (and the
            # quick settings dark-style switch)
            ptyxis.set_string("interface-style", "system")
            uuids = ptyxis.get_strv("profile-uuids")
            if not uuids:   # Ptyxis makes its default profile on first start: make it now
                import uuid as uuidlib
                uuids = [uuidlib.uuid4().hex]
                ptyxis.set_strv("profile-uuids", uuids)
                ptyxis.set_string("default-profile-uuid", uuids[0])
            for uuid in uuids:
                Gio.Settings.new_with_path("org.gnome.Ptyxis.Profile",
                                           f"/org/gnome/Ptyxis/Profiles/{uuid}/").set_string("palette", pid)

    from gi.repository import Gio
    Gio.Settings.sync()
    write_look(look)
    return notes


# --- Command line -----------------------------------------------------------------------------
def main(argv):
    parser = argparse.ArgumentParser(prog="kinobu-theme", description="Kinobu's themes")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list", help="the themes, the active one marked")
    sub.add_parser("current", help="the active theme, palette and mode")
    p = sub.add_parser("set", help="apply a theme")
    p.add_argument("theme")
    p.add_argument("--palette", help="one of its palettes (kinobu-theme list)")
    p.add_argument("--mode", "--variant", dest="mode", choices=MODES,
                   help="its palette for this mode (the one in use, or its pair)")
    p = sub.add_parser("validate", help="check themes (all when none is named)")
    p.add_argument("--strict", action="store_true", help="also fail on contrast below Kinobu's bar")
    p.add_argument("themes", nargs="*")
    sub.add_parser("refresh", help="write the active theme again (after an update)")
    p = sub.add_parser("new", help="your own copy of a theme, to change its colours")
    p.add_argument("name", help="the new theme's name")
    p.add_argument("--from", dest="source", default="kinobu", help="the theme to copy (kinobu)")
    p = sub.add_parser("colour", help="change colours of a palette of your own theme")
    p.add_argument("theme")
    p.add_argument("palette")
    p.add_argument("colours", nargs="+", metavar="KEY=#RRGGBB", help=", ".join(COLOURS))
    p = sub.add_parser("buttons", help="the window buttons of your own theme on the left or the right")
    p.add_argument("theme")
    p.add_argument("side", choices=tuple(BUTTON_LAYOUTS))
    p = sub.add_parser("delete", help="send your own theme to the Trash")
    p.add_argument("theme")
    p = sub.add_parser("pick", help="your own icons, cursor, fonts or wallpaper over the theme's "
                       "('theme' goes back to the theme's)")
    p.add_argument("what", choices=("icons", "cursor", "interface-font", "monospace-font", "wallpaper",
                                     "wallpapers"))
    p.add_argument("value", help="a name, a font like 'Inter 11', for a wallpaper: N PATH (1-4), "
                   "for wallpapers: PATH on all four")
    p.add_argument("path", nargs="?")
    sub.add_parser("packs", help="the icon packs, cursors and fonts installed")
    sub.add_parser("look", help="your look: the theme and what you picked")
    p = sub.add_parser("css", help="print the GTK CSS a theme makes")
    p.add_argument("theme")
    p.add_argument("--palette")
    p.add_argument("--gtk3", action="store_true")
    args = parser.parse_args(argv)

    try:
        if args.command == "list":
            active, palette, _ = current()
            for t in load_all():
                mark = "●" if t["id"] == active else " "
                own = " (yours)" if t["own"] else ""
                names = ", ".join(("●" if t["id"] == active and p == palette else "") + f"{p} ({mode_of(t, p)})"
                                  for p in t["palettes"])
                print(f"{mark} {t['id']:<14} {t.get('name', t['id'])}{own} · {names}")
        elif args.command == "current":
            active, palette, mode = current()
            if active and palette:
                try:
                    mode = mode_of(load(active), palette)
                except (ThemeError, KeyError):
                    pass
            print(f"{active} {palette or '-'} {mode or '-'}" if active else "none")
        elif args.command in ("set", "refresh"):
            if args.command == "refresh":
                theme_id, palette, mode = current()
                if not theme_id:
                    print("No theme applied yet")
                    return 0
            else:
                theme_id, palette, mode = args.theme, args.palette, args.mode
            for note in apply(theme_id, palette, mode):
                print(f"· {note}")
            theme_id, palette, _ = current()
            theme = load(theme_id)
            print(f"✔ {theme.get('name', theme_id)} ({palette_name(theme, palette)}) applied. "
                  "Open apps take it when they open again.")
        elif args.command == "validate":
            bad = 0
            for theme_id in args.themes or theme_ids():
                try:
                    theme = load(theme_id)
                    problems = validate(theme)
                    notes = quality(theme) if not problems else []
                except ThemeError as e:
                    problems, notes = [str(e)], []
                failed = bool(problems) or (args.strict and bool(notes))
                bad += failed
                print(("✘ " if failed else "✔ ") + theme_id + "".join(f"\n    {p}" for p in problems)
                      + "".join(f"\n    ! {n}" for n in notes))
            return 1 if bad else 0
        elif args.command == "new":
            theme_id = new_theme(args.source, args.name)
            print(f"✔ {theme_id}: {os.path.join(USER_THEMES, theme_id, 'theme.toml')}")
        elif args.command == "colour":
            pairs = dict(c.split("=", 1) for c in args.colours if "=" in c)
            for note in set_colours(args.theme, args.palette, pairs):
                print(f"· {note}")
            print("✔ Done (kinobu-theme refresh shows it when it is the theme in use)")
        elif args.command == "buttons":
            set_buttons(args.theme, args.side)
            print("✔ Done (kinobu-theme refresh shows it when it is the theme in use)")
        elif args.command == "delete":
            delete_theme(args.theme)
            print("✔ In the Trash")
        elif args.command == "pick":
            value = "" if args.value == "theme" else args.value
            if args.what == "wallpaper":
                if not args.value.isdigit():
                    raise ThemeError("wallpaper needs a workspace number: pick wallpaper 2 ~/picture.jpg")
                path = "" if args.path in (None, "theme") else os.path.abspath(os.path.expanduser(args.path))
                if not 1 <= int(args.value) <= WALL_SLOTS:
                    raise ThemeError(f"there are {WALL_SLOTS} wallpapers: 1 to {WALL_SLOTS}")
                notes = pick(wallpaper=(int(args.value) - 1, path))
            elif args.what == "wallpapers":
                path = "" if args.value == "theme" else os.path.abspath(os.path.expanduser(args.value))
                notes = pick(wallpaper_everywhere=path)
            else:
                notes = pick(**{args.what.replace("-", "_"): value})
            for note in notes:
                print(f"· {note}")
            print("✔ Done")
        elif args.command == "packs":
            print("Icons:   " + ", ".join(name for _, name in icon_families()))
            print("Cursors: " + ", ".join(name for name, _ in cursor_themes()))
        elif args.command == "look":
            print(read(LOOK_FILE) if os.path.isfile(LOOK_FILE) else "No look chosen yet")
        elif args.command == "css":
            theme = load(args.theme)
            pid = resolve(theme, args.palette)
            print(gtk3_css(theme, pid) if args.gtk3 else gtk4_css(theme, pid))
    except ThemeError as e:
        print(f"✘ {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
