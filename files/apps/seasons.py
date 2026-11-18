# Seasons, Kinobu's themes app. Written by Kinobu: rewritten on every run and --update.
# A gallery of the themes (factory and the user's own): a preview of each one drawn from its
# colours, its palettes and Apply; then icons, cursors, fonts and wallpapers, each with a switch
# to follow the theme or choose your own. The work is done by kinobu_theme.py (the kinobu-theme command).
import math
import os
import sys
import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Gsk", "4.0")
gi.require_version("Graphene", "1.0")
from gi.repository import Adw, Gdk, Gio, GLib, Graphene, Gsk, Gtk  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kinobu_theme as engine  # noqa: E402
import kinobu_wallhaven as wallhaven  # noqa: E402
from kinobu_i18n import texts  # noqa: E402

APP_ID = "os.kinobu.Themes"
T = texts("seasons")


def t(key, **values):
    text = T.get(key, key)
    return text.format(**values) if values else text   # some texts hold braces (code)


def rgba(colour, alpha=1.0):
    r, g, b = engine.rgb(colour)
    return Gdk.RGBA(red=r, green=g, blue=b, alpha=alpha)


def black(alpha):
    return Gdk.RGBA(red=0, green=0, blue=0, alpha=alpha)


def box(x, y, w, h):
    rect = Graphene.Rect()
    rect.init(x, y, w, h)   # in place: PyGObject's copy of the return value is not usable
    return rect


def rounded_box(x, y, w, h, radius):
    out = Gsk.RoundedRect()
    out.init_from_rect(box(x, y, w, h), min(radius, w / 2, h / 2))
    return out


def point(x, y):
    out = Graphene.Point()
    out.init(x, y)
    return out


class Painter:
    """Shapes on a GtkSnapshot (no cairo needed)."""

    def __init__(self, snapshot):
        self.s = snapshot

    def rect(self, x, y, w, h, colour, radius=0):
        if radius:
            self.s.push_rounded_clip(rounded_box(x, y, w, h, radius))
        self.s.append_color(colour, box(x, y, w, h))
        if radius:
            self.s.pop()

    def circle(self, cx, cy, r, colour):
        self.rect(cx - r, cy - r, 2 * r, 2 * r, colour, r)

    def ring(self, cx, cy, r, width, colour):
        self.s.append_border(rounded_box(cx - r, cy - r, 2 * r, 2 * r, r), [width] * 4, [colour] * 4)

    def gradient(self, x, y, w, h, start, end):
        stops = []
        for offset, colour in ((0.0, start), (1.0, end)):
            stop = Gsk.ColorStop()
            stop.offset, stop.color = offset, colour
            stops.append(stop)
        self.s.append_linear_gradient(box(x, y, w, h), point(x, y), point(x + w, y + h), stops)

    def texture(self, texture, x, y, w, h):
        self.s.append_texture(texture, box(x, y, w, h))

    def clip(self, x, y, w, h, radius):
        self.s.push_rounded_clip(rounded_box(x, y, w, h, radius))

    def unclip(self):
        self.s.pop()


class Look:
    """What a preview needs from a theme and palette: its colours, terminal and wallpaper."""
    _terminals = {}

    def __init__(self, theme, palette):
        self.theme, self.palette = theme, palette
        self.mode = engine.mode_of(theme, palette)
        self.c = engine.colours_for(theme, palette)
        key = (theme["id"], palette)
        if key not in Look._terminals:
            Look._terminals[key] = engine.terminal_colours(theme, palette)
        self.term = Look._terminals[key]
        pictures = engine.backgrounds(theme, self.mode)
        self.wallpaper = pictures[0] if pictures else None
        self.left_buttons = theme.get("button_layout", "").startswith("close")

    def ansi(self, n, fallback):
        return self.term.get(f"Color{n}", fallback)


TEXTURES = {}


def draw_wallpaper(look, p, w, h):
    """The theme's wallpaper, or the rings of the tree on a soft gradient of its colours."""
    c = look.c
    texture = None
    if look.wallpaper:
        try:
            texture = TEXTURES.setdefault(look.wallpaper, Gdk.Texture.new_from_filename(look.wallpaper))
        except GLib.Error:
            texture = None
    if texture:
        p.texture(texture, 0, 0, w, h)
    else:
        p.gradient(0, 0, w, h, rgba(engine.mix(c["view"], c["accent"], 0.30)),
                   rgba(engine.mix(c["view"], look.ansi(5, c["accent"]), 0.18)))
        cx, cy = w * 0.82, h * 0.30
        for i in range(1, 9):
            p.ring(cx, cy, i * w * 0.07, w * 0.012, rgba(c["foreground"], 0.06 if i % 2 else 0.035))
        p.circle(cx, cy, w * 0.025, rgba(c["accent"], 0.55))


def draw_preview(look, p, w, h):
    """A small desktop in the theme: wallpaper, top bar, a Files window, a terminal, the dock."""
    c = look.c
    dark = look.mode == "dark"
    draw_wallpaper(look, p, w, h)

    # Top bar
    p.rect(0, 0, w, h * 0.06, black(0.55))
    p.rect(w * 0.46, h * 0.018, w * 0.08, h * 0.024, Gdk.RGBA(red=1, green=1, blue=1, alpha=0.75), h * 0.012)

    def window(x, y, ww, wh, head, body):
        p.rect(x + 2, y + 3, ww, wh, black(0.28 if dark else 0.16), 7)
        p.clip(x, y, ww, wh, 7)
        p.rect(x, y, ww, wh, rgba(body))
        p.rect(x, y, ww, wh * 0.13, rgba(head))
        # window buttons, on the side the theme puts them
        bx = x + ww * 0.05 if look.left_buttons else x + ww - ww * 0.05
        step = ww * 0.045 * (1 if look.left_buttons else -1)
        for i in range(3):
            close = i == 0
            p.circle(bx + i * step, y + wh * 0.065, wh * 0.022,
                     rgba(c["error"] if close else c["muted"], 0.95 if close else 0.5))
        p.unclip()

    # Files: header bar, sidebar with the current place, folders in the view
    x, y, ww, wh = w * 0.06, h * 0.13, w * 0.60, h * 0.66
    window(x, y, ww, wh, c["headerbar"], c["view"])
    side = ww * 0.30
    p.rect(x, y + wh * 0.13, side, wh * 0.87, rgba(c["sidebar"]))
    for i in range(5):
        ry = y + wh * (0.20 + i * 0.12)
        if i == 1:
            p.rect(x + side * 0.08, ry - wh * 0.035, side * 0.84, wh * 0.09, rgba(c["accent"], 0.25), 4)
        p.circle(x + side * 0.18, ry + wh * 0.01, wh * 0.022, rgba(c["accent_text"]))
        p.rect(x + side * 0.30, ry, side * (0.50 - 0.05 * (i % 3)), wh * 0.022, rgba(c["foreground"], 0.75), 2)
    gx, gy = x + side + ww * 0.06, y + wh * 0.22
    for row in range(2):
        for col in range(3):
            fx, fy = gx + col * ww * 0.20, gy + row * wh * 0.36
            p.rect(fx, fy, ww * 0.12, wh * 0.16, rgba(c["accent"] if (row + col) % 3 else c["muted"], 0.9), 4)
            p.rect(fx, fy + wh * 0.20, ww * 0.12, wh * 0.025, rgba(c["foreground"], 0.6), 2)

    # Terminal: the theme's palette
    bg = look.term.get("Background", c["view"])
    fg = look.term.get("Foreground", c["foreground"])
    x, y, ww, wh = w * 0.50, h * 0.44, w * 0.44, h * 0.42
    window(x, y, ww, wh, engine.mix(bg, fg, 0.08), bg)
    lines = [[(4, 0.22), (2, 0.30)], [(7, 0.55)], [(3, 0.25), (6, 0.18), (7, 0.2)], [(4, 0.22), (2, 0.12)]]
    for i, parts in enumerate(lines):
        lx = x + ww * 0.06
        for n, length in parts:
            p.rect(lx, y + wh * (0.25 + i * 0.15), ww * length, wh * 0.06,
                   rgba(fg if n == 7 else look.ansi(n, fg), 0.9), 2)
            lx += ww * (length + 0.03)
    for n in range(1, 7):
        p.rect(x + ww * (0.06 + (n - 1) * 0.14), y + wh * 0.84, ww * 0.11, wh * 0.07, rgba(look.ansi(n, fg)), 2)

    # Dock
    p.rect(w * 0.34, h * 0.905, w * 0.32, h * 0.075, black(0.45), h * 0.03)
    for i in range(5):
        p.circle(w * (0.38 + i * 0.06), h * 0.9425, h * 0.022,
                 rgba(c["accent"] if i == 1 else c["foreground"], 0.9 if i == 1 else 0.7))


def draw_swatches(look, p, w, h):
    c = look.c
    colours = [c["accent"], c["background"], c["view"], c["card"], c["success"], c["warning"],
               c["error"]] + [look.ansi(n, c["accent"]) for n in (1, 2, 3, 4, 5, 6)]
    for i, colour in enumerate(colours):
        cx = h / 2 + i * (h + 5)
        p.circle(cx, h / 2, h / 2, rgba(c["foreground"], 0.18))
        p.circle(cx, h / 2, h / 2 - 1, rgba(colour))


def draw_chip(look, p, w, h):
    """A palette as a small round button: its window colour, a ring of its text and its accent."""
    c = look.c
    r = min(w, h) / 2
    p.circle(w / 2, h / 2, r, rgba(c["foreground"], 0.35))
    p.circle(w / 2, h / 2, r - 1.5, rgba(c["background"]))
    p.circle(w / 2, h / 2, r * 0.42, rgba(c["accent"]))


class Canvas(Gtk.Widget):
    """A widget drawn by a function (painter, width, height)."""

    def __init__(self, draw, width, height, **kwargs):
        super().__init__(**kwargs)
        self.draw = draw
        self.set_size_request(width, height)

    def do_snapshot(self, snapshot):
        self.draw(Painter(snapshot), self.get_width(), self.get_height())


def xcursor_texture(path, size=40):
    """The image of an X cursor file nearest to a size, as a texture (None if unreadable)."""
    import struct
    try:
        with open(path, "rb") as f:
            data = f.read()
        if data[:4] != b"Xcur":
            return None
        header, _, ntoc = struct.unpack_from("<III", data, 4)
        images = []
        for i in range(ntoc):
            kind, subtype, pos = struct.unpack_from("<III", data, 16 + i * 12)
            if kind == 0xFFFD0002:
                images.append((abs(subtype - size), pos))
        _, pos = min(images)
        _, _, _, _, width, height, _, _, _ = struct.unpack_from("<9I", data, pos)
        pixels = data[pos + 36: pos + 36 + width * height * 4]
        return Gdk.MemoryTexture.new(width, height, Gdk.MemoryFormat.B8G8R8A8_PREMULTIPLIED,
                                     GLib.Bytes.new(pixels), width * 4)
    except (OSError, struct.error, ValueError):
        return None


def badge(text, css="season-badge"):
    return Gtk.Label(label=text, css_classes=[css, "caption-heading"], valign=Gtk.Align.CENTER)


def page_box(intro):
    """A scrolling page: a short explanation, then its content (returned)."""
    scroll = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER)
    clamp = Adw.Clamp(maximum_size=1180, margin_top=18, margin_bottom=24, margin_start=18, margin_end=18)
    scroll.set_child(clamp)
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
    clamp.set_child(page)
    page.append(Gtk.Label(label=intro, xalign=0, wrap=True, margin_start=6, margin_end=6))
    return scroll, page


def flow():
    return Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE, homogeneous=True, min_children_per_line=1,
                       max_children_per_line=3, column_spacing=18, row_spacing=18)


# --- Themes -----------------------------------------------------------------------------------
class ThemeCard(Gtk.Box):
    def __init__(self, win, theme):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, css_classes=["card", "season"])
        self.win, self.theme = win, theme
        self.palette = engine.resolve(theme)
        self.set_overflow(Gtk.Overflow.HIDDEN)
        self.preview = Canvas(lambda p, w, h: draw_preview(self.look(), p, w, h), 300, 180)
        self.append(self.preview)

        body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8, margin_top=12,
                       margin_bottom=14, margin_start=14, margin_end=14)
        self.append(body)
        title_row = Gtk.Box(spacing=8)
        title_row.append(Gtk.Label(label=theme.get("name", theme["id"]), xalign=0,
                                   css_classes=["title-4"], hexpand=True))
        if theme.get("own"):
            title_row.append(Gtk.Label(label=t("yours"), css_classes=["dim-label", "caption"]))
        self.badge = badge(t("in_use"))
        title_row.append(self.badge)
        body.append(title_row)
        body.append(Gtk.Label(label=T.get(f"theme.{theme['id']}", theme.get("description", "")), xalign=0, wrap=True,
                              lines=2, ellipsize=3, css_classes=["dim-label"], max_width_chars=28))
        self.swatches = Canvas(lambda p, w, h: draw_swatches(self.look(), p, w, h), 220, 16, margin_top=2)
        body.append(self.swatches)

        # The palettes: one round button each, the chosen one named below
        chips = Gtk.Box(spacing=6, margin_top=4)
        self.chips, first = {}, None
        for pid in theme["palettes"]:
            look = Look(theme, pid)
            chip = Gtk.ToggleButton(css_classes=["palette-chip", "flat", "circular"], group=first,
                                    tooltip_text=self.palette_label(pid), valign=Gtk.Align.CENTER,
                                    child=Canvas(lambda p, w, h, lk=look: draw_chip(lk, p, w, h), 22, 22,
                                                 can_target=False))
            chip.connect("toggled", self.on_palette, pid)
            chips.append(chip)
            self.chips[pid] = chip
            first = first or chip
        self.chips[self.palette].set_active(True)
        chips.append(Gtk.Box(hexpand=True))
        self.button = Gtk.Button(label=t("apply"), css_classes=["pill", "suggested-action"],
                                 valign=Gtk.Align.CENTER)
        self.button.connect("clicked", lambda b: self.win.run(
            lambda: engine.apply(self.theme["id"], self.palette),
            t("applied", name=f"{self.theme.get('name', self.theme['id'])} · "
                              f"{engine.palette_name(self.theme, self.palette)}")))
        chips.append(self.button)
        self.palette_text = Gtk.Label(xalign=0, css_classes=["dim-label", "caption"])
        body.append(self.palette_text)
        body.append(chips)
        self.palette_text.set_label(self.palette_label(self.palette))

    def palette_label(self, pid):
        return f"{engine.palette_name(self.theme, pid)} · {t(engine.mode_of(self.theme, pid))}"

    def look(self):
        return Look(self.theme, self.palette)

    def on_palette(self, chip, pid):
        if not chip.get_active() or pid == self.palette:
            return
        self.palette = pid
        self.palette_text.set_label(self.palette_label(pid))
        self.preview.queue_draw()
        self.swatches.queue_draw()
        self.refresh(self.win.state)

    def refresh(self, state, busy=False):
        here = state["theme"] == self.theme["id"]
        self.badge.set_visible(here)
        if here and state["first"] and state["palette"] in self.chips and state["palette"] != self.palette:
            self.chips[state["palette"]].set_active(True)
        in_use = here and state["palette"] == self.palette
        self.button.set_sensitive(not in_use and not busy)
        self.button.set_label(t("in_use") if in_use else t("apply"))
        (self.button.remove_css_class if in_use else self.button.add_css_class)("suggested-action")


# --- Icons and cursors: a card per pack, with a sample of its own pictures ----------------------
# Each sample is the first name the pack has (packs name some icons differently)
SAMPLE_ICONS = [["folder"], ["folder-download"], ["user-home", "folder-home"],
                ["utilities-terminal", "org.gnome.Terminal", "org.gnome.Ptyxis", "terminal"],
                ["web-browser", "firefox", "org.mozilla.firefox"],
                ["preferences-system", "org.gnome.Settings", "gnome-control-center"],
                ["image-x-generic"], ["text-x-generic"], ["audio-x-generic"], ["user-trash"]]
SAMPLE_CURSORS = [["left_ptr", "default", "arrow"], ["hand2", "pointer", "hand1"],
                  ["xterm", "text", "ibeam"], ["watch", "wait"], ["fleur", "move", "all-scroll"]]


class FollowRow:
    """The switch at the top of a page: on, the theme chooses (and the choices below rest); off,
    what the theme gives now is kept as your own choice, to change as you like."""

    def __init__(self, win, kinds, intro):
        self.win, self.kinds = win, kinds
        self.group = Adw.PreferencesGroup()
        self.row = Adw.SwitchRow(title=t("follow_theme"), subtitle=intro)
        self.row.connect("notify::active", self.on_switch)
        self.group.add(self.row)
        self.quiet = False

    def following(self, state):
        look = state["look"]
        return not any(any(look[k]) if k == "wallpapers" else look[k] for k in self.kinds)

    def on_switch(self, row, _pspec):
        if self.quiet:
            return
        if row.get_active():
            self.win.run(lambda: engine.pick(**{k: ([] if k == "wallpapers" else "") for k in self.kinds}),
                         t("back_to_theme"))
        else:
            state = self.win.state
            own = {}
            for k in self.kinds:
                if k == "wallpapers":
                    own[k] = [w or (state["now_wallpapers"][i] if i < len(state["now_wallpapers"]) else "")
                              for i, w in enumerate(state["use"]["wallpapers"])]
                else:
                    own[k] = state["use"][k] or state.get("system_" + k, "")
            self.win.run(lambda: engine.pick(**own), t("now_yours"))

    def refresh(self, state, busy=False):
        self.quiet = True
        self.row.set_active(self.following(state))
        self.row.set_sensitive(not busy)
        self.quiet = False
        return self.row.get_active()


class PackCard(Gtk.Box):
    """One icon pack or cursor theme: its name, a sample and Use."""

    def __init__(self, win, kind, pack_id, name):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=10, css_classes=["card", "season"])
        self.win, self.kind, self.pack_id = win, kind, pack_id
        top = Gtk.Box(spacing=8, margin_top=14, margin_start=14, margin_end=14)
        top.append(Gtk.Label(label=name, xalign=0, css_classes=["title-4"], hexpand=True,
                             ellipsize=3))
        self.theirs = badge(t("from_theme"), "season-tag")
        self.badge = badge(t("in_use"))
        top.append(self.theirs)
        top.append(self.badge)
        self.append(top)
        self.sample = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE, min_children_per_line=5,
                                  max_children_per_line=5, homogeneous=True, margin_start=10,
                                  margin_end=10, can_target=False)
        self.append(self.sample)
        self.button = Gtk.Button(label=t("use"), css_classes=["pill"], halign=Gtk.Align.END,
                                 margin_end=14, margin_bottom=14)
        self.button.connect("clicked", lambda b: self.win.run(
            lambda: engine.pick(**{self.kind: self.pack_id}), t("now_using", name=name)))
        self.append(self.button)
        self.drawn_for = None

    def draw_sample(self, state):
        mode = state["mode"]
        key = (self.kind, mode, state["yaru"])
        if self.drawn_for == key:
            return
        self.drawn_for = key
        while child := self.sample.get_first_child():
            self.sample.remove(child)
        if self.kind == "icons":
            name = engine.icon_theme(self.pack_id, mode, state["yaru"]) or self.pack_id
            theme = Gtk.IconTheme()
            theme.set_theme_name(name)
            for names in SAMPLE_ICONS:
                icon = next((n for n in names if theme.has_icon(n)), None)
                if not icon:
                    continue
                paintable = theme.lookup_icon(icon, None, 40, 1, Gtk.TextDirection.NONE, 0)
                self.sample.append(Gtk.Image(paintable=paintable, pixel_size=40, margin_top=4, margin_bottom=4))
        else:
            for names in SAMPLE_CURSORS:
                path = engine.cursor_file(self.pack_id, names)
                texture = xcursor_texture(path) if path else None
                image = Gtk.Image(pixel_size=40, margin_top=6, margin_bottom=6)
                if texture:
                    image.set_from_paintable(texture)
                self.sample.append(image)

    def refresh(self, state, busy=False):
        self.draw_sample(state)
        in_use = state["use"].get(self.kind) == self.pack_id
        self.badge.set_visible(in_use)
        self.theirs.set_visible(state["theme_" + self.kind] == self.pack_id and not in_use)
        self.button.set_visible(not in_use)
        self.button.set_sensitive(not busy and not state["follow_" + self.kind])


class PacksPage:
    def __init__(self, win, kind):
        self.win, self.kind = win, kind
        self.widget, page = page_box(t(f"{kind}_intro"))
        self.follow = FollowRow(win, [kind], t(f"follow_{kind}"))
        page.append(self.follow.group)
        self.grid = flow()
        page.append(self.grid)
        packs = engine.icon_families() if kind == "icons" else engine.cursor_themes()
        self.cards = [PackCard(win, kind, pack_id, name) for pack_id, name in packs]
        for card in self.cards:
            self.grid.append(card)
            card.get_parent().set_focusable(False)

    def refresh(self, state, busy=False):
        state["follow_" + self.kind] = self.follow.refresh(state, busy)
        for card in self.cards:
            card.refresh(state, busy)


# --- Fonts -----------------------------------------------------------------------------------
INTERFACE_FONTS = ["Ubuntu Sans", "Adwaita Sans", "Cantarell", "Inter", "Noto Sans"]
MONOSPACE_FONTS = ["Ubuntu Sans Mono", "Adwaita Mono", "JetBrains Mono", "UbuntuSansMono Nerd Font Mono"]


class FontGroup:
    """One kind of font: a row per family (written in it), its size and any other font."""

    def __init__(self, win, kind, families, sample):
        self.win, self.kind = win, kind
        self.group = Adw.PreferencesGroup(title=t(kind), description=t(kind + "_desc"))
        installed = engine.font_families()
        if kind == "monospace_font":   # every Nerd Font installed, after the usual ones
            families = families + sorted(f for f in installed if f.endswith("Nerd Font Mono") and f not in families)
        self.rows, first = {}, None
        for family in families:
            if family not in installed:
                continue
            row = Adw.ActionRow(title=f'<span font_family="{GLib.markup_escape_text(family)}" size="large">'
                                      f'{GLib.markup_escape_text(family)}</span>',
                                subtitle=f'<span font_family="{GLib.markup_escape_text(family)}">{sample}</span>',
                                use_markup=True, activatable=True)
            check = Gtk.CheckButton(group=first, valign=Gtk.Align.CENTER)
            first = first or check
            row.add_prefix(check)
            row.set_activatable_widget(check)
            check.connect("toggled", self.on_family, family)
            self.group.add(row)
            self.rows[family] = check
        self.other = Adw.ActionRow(title=t("other_font"))
        dialog = Gtk.FontDialog(title=t("other_font"))
        self.chooser = Gtk.FontDialogButton(dialog=dialog, level=Gtk.FontLevel.FAMILY, valign=Gtk.Align.CENTER)
        self.chooser.connect("notify::font-desc", self.on_other)
        self.other.add_suffix(self.chooser)
        self.group.add(self.other)
        self.size = Adw.SpinRow.new_with_range(8, 20, 1)
        self.size.set_title(t("size"))
        self.size.connect("notify::value", self.on_size)
        self.group.add(self.size)
        self.quiet = False

    def current(self, state):
        value = state["use"][self.kind] or state["system_" + self.kind]
        return engine.font_family(value), (value.rsplit(" ", 1)[-1] if value != engine.font_family(value) else "11")

    def choose(self, family):
        _, size = self.current(self.win.state)
        self.win.run(lambda: engine.pick(**{self.kind: f"{family} {size}"}), t("now_using", name=family))

    def on_family(self, check, family):
        if check.get_active() and not self.quiet:
            self.choose(family)

    def on_other(self, button, _pspec):
        desc = button.get_font_desc()
        if desc and not self.quiet:
            self.choose(desc.get_family())

    def on_size(self, row, _pspec):
        if self.quiet:
            return
        family, _ = self.current(self.win.state)
        size = int(row.get_value())
        self.win.run(lambda: engine.pick(**{self.kind: f"{family} {size}"}), t("font_size", size=size))

    def refresh(self, state, busy=False):
        self.quiet = True
        family, size = self.current(state)
        if family in self.rows:
            self.rows[family].set_active(True)
        else:   # a font not in the list: no row ticked
            for check in self.rows.values():
                check.set_active(False)
        self.other.set_subtitle(family if family not in self.rows else "")
        try:
            self.size.set_value(float(size))
        except ValueError:
            pass
        self.group.set_sensitive(not busy and not state["follow_fonts"])
        self.quiet = False


class FontsPage:
    def __init__(self, win):
        page = Adw.PreferencesPage(description=t("fonts_intro"))
        self.follow = FollowRow(win, ["interface_font", "monospace_font"], t("follow_fonts"))
        page.add(self.follow.group)
        self.groups = [FontGroup(win, "interface_font", INTERFACE_FONTS, t("sample")),
                       FontGroup(win, "monospace_font", MONOSPACE_FONTS, t("code_sample"))]
        for g in self.groups:
            page.add(g.group)
        self.widget = page

    def refresh(self, state, busy=False):
        state["follow_fonts"] = self.follow.refresh(state, busy)
        for g in self.groups:
            g.refresh(state, busy)


# --- Wallpapers ------------------------------------------------------------------------------
class WallpaperCard(Gtk.Box):
    def __init__(self, win, index):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, css_classes=["card", "season"])
        self.win, self.index = win, index
        self.set_overflow(Gtk.Overflow.HIDDEN)
        # Drawn at the card's size: a Gtk.Picture asks for the photo's own size and would leave
        # one card per row
        self.path = ""
        self.canvas = Canvas(self.draw, 300, 180)
        self.append(self.canvas)
        body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin_top=12,
                       margin_bottom=14, margin_start=14, margin_end=14)
        self.append(body)
        title = Gtk.Box(spacing=8)
        title.append(Gtk.Label(label=t("workspace", n=index + 1), xalign=0, css_classes=["title-4"], hexpand=True))
        self.theirs = badge(t("from_theme"), "season-tag")
        title.append(self.theirs)
        body.append(title)
        if index == 0:
            body.append(Gtk.Label(label=t("lock_screen"), xalign=0, css_classes=["dim-label", "caption"]))
        buttons = Gtk.Box(spacing=8, halign=Gtk.Align.END, margin_top=4)
        everywhere = Gtk.Button(label=t("wh_everywhere"), css_classes=["flat"])
        menu = Gtk.Popover(child=everywhere)
        everywhere.connect("clicked", lambda b: (menu.popdown(), self.on_everywhere()))
        change = Adw.SplitButton(label=t("change"), popover=menu, css_classes=["pill"])
        change.connect("clicked", self.on_change)
        buttons.append(change)
        body.append(buttons)
        self.change = change

    def draw(self, p, w, h):
        texture = None
        if self.path:
            try:
                texture = TEXTURES.setdefault(self.path, Gdk.Texture.new_from_filename(self.path))
            except GLib.Error:
                texture = None
        if not texture:
            draw_wallpaper(self.win.look_preview(), p, w, h)
            return
        tw, th = texture.get_width(), texture.get_height()
        scale = max(w / tw, h / th)   # cover the card, cropping what is left over
        p.clip(0, 0, w, h, 0.01)
        p.texture(texture, (w - tw * scale) / 2, (h - th * scale) / 2, tw * scale, th * scale)
        p.unclip()

    def on_everywhere(self):
        path = self.path
        if path:
            self.win.run(lambda: engine.pick(wallpaper_everywhere=path), t("wh_all_set"))

    def on_change(self, _button):
        dialog = Gtk.FileDialog(title=t("choose_wallpaper", n=self.index + 1), modal=True)
        images = Gtk.FileFilter(name=t("images"))
        images.add_mime_type("image/*")
        store = Gio.ListStore.new(Gtk.FileFilter)
        store.append(images)
        dialog.set_filters(store)
        pictures = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_PICTURES)
        if pictures:
            dialog.set_initial_folder(Gio.File.new_for_path(pictures))

        def done(d, result):
            try:
                path = d.open_finish(result).get_path()
            except GLib.Error:
                return
            self.win.run(lambda: engine.pick(wallpaper=(self.index, path)), t("wallpaper_set", n=self.index + 1))
        dialog.open(self.win, None, done)

    def refresh(self, state, busy=False):
        walls = state["use"]["wallpapers"]
        path = walls[self.index] if self.index < len(walls) else ""
        mine = self.index < len(state["look"]["wallpapers"]) and bool(state["look"]["wallpapers"][self.index])
        now = state["now_wallpapers"][self.index] if self.index < len(state["now_wallpapers"]) else ""
        theirs = bool(path) and not mine
        if not path:   # neither yours nor the theme's: the one the desktop has now
            path = now
        is_now = not theirs and bool(path) and os.path.isfile(path)
        self.theirs.set_label(t("current") if is_now else t("from_theme"))
        self.path = path if path and os.path.isfile(path) else ""
        self.canvas.queue_draw()
        self.theirs.set_visible(not mine)
        self.change.set_sensitive(not busy and not state["follow_wallpapers"])


class WallpapersPage:
    def __init__(self, win):
        self.win = win
        self.widget, page = page_box(t("wallpapers_intro"))
        self.follow = FollowRow(win, ["wallpapers"], t("follow_wallpapers"))
        page.append(self.follow.group)
        find = Gtk.Button(css_classes=["pill", "suggested-action"], halign=Gtk.Align.CENTER,
                          child=Adw.ButtonContent(icon_name="system-search-symbolic", label=t("wh_button")))
        find.connect("clicked", lambda b: WallhavenWindow(self.win).present())
        page.append(find)
        self.grid = flow()
        self.grid.set_min_children_per_line(2)   # 2 × 2, one card per workspace
        self.grid.set_max_children_per_line(2)
        page.append(self.grid)
        self.cards = []

    def refresh(self, state, busy=False):
        state["follow_wallpapers"] = self.follow.refresh(state, busy)
        count = len(state["use"]["wallpapers"])
        while len(self.cards) < count:
            card = WallpaperCard(self.win, len(self.cards))
            self.grid.append(card)
            card.get_parent().set_focusable(False)
            self.cards.append(card)
        for i, card in enumerate(self.cards):
            card.get_parent().set_visible(i < count)
            card.refresh(state, busy)


# --- Wallhaven: find wallpapers on wallhaven.cc ----------------------------------------------
def pictures_folder():
    pictures = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_PICTURES) or os.path.join(engine.HOME, "Pictures")
    return os.path.join(pictures, "Wallhaven")


def screen_size(widget):
    """The largest monitor, as Wallhaven's "at least" (1920x1080 when unknown)."""
    try:
        monitors = widget.get_display().get_monitors()
        sizes = []
        for i in range(monitors.get_n_items()):
            m = monitors.get_item(i)
            g, s = m.get_geometry(), m.get_scale()
            sizes.append((round(g.width * s), round(g.height * s)))
        w, h = max(sizes)
        return f"{w}x{h}" if w >= 1280 else "1920x1080"
    except Exception:
        return "1920x1080"


def use_button(window, picture, css):
    """Use ▾: a workspace, every workspace, or the picture's page on Wallhaven."""
    menu = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
    popover = Gtk.Popover(child=menu)

    def item(label, action):
        button = Gtk.Button(label=label, css_classes=["flat"])
        button.get_child().set_xalign(0)
        button.connect("clicked", lambda b: (popover.popdown(), action()))
        menu.append(button)
    for i in range(engine.WALL_SLOTS):
        item(t("workspace", n=i + 1), lambda i=i: window.use(picture, [i]))
    item(t("wh_everywhere"), lambda: window.use(picture, None))
    menu.append(Gtk.Separator(margin_top=2, margin_bottom=2))
    item(t("wh_open"), lambda: Gtk.UriLauncher(uri=picture["url"]).launch(window, None, None, None))
    return Gtk.MenuButton(label=t("use"), popover=popover, css_classes=css, valign=Gtk.Align.CENTER)


class WallhavenDetail(Adw.Dialog):
    """One picture, large: the thumbnail at once, the full picture when it has arrived."""

    def __init__(self, window, picture, texture):
        super().__init__(title=picture["resolution"].replace("x", " × "), content_width=1000,
                         content_height=680)
        self.picture = Gtk.Picture(content_fit=Gtk.ContentFit.CONTAIN, can_shrink=True, vexpand=True,
                                   paintable=texture)
        self.spinner = Adw.Spinner(halign=Gtk.Align.CENTER, valign=Gtk.Align.CENTER,
                                   width_request=40, height_request=40)
        overlay = Gtk.Overlay(child=self.picture)
        overlay.add_overlay(self.spinner)
        view = Adw.ToolbarView()
        view.add_top_bar(Adw.HeaderBar())
        view.set_content(overlay)
        bar = Gtk.Box(spacing=12, margin_start=18, margin_end=18, margin_top=10, margin_bottom=14)
        size = picture.get("size") or 0
        bar.append(Gtk.Label(label=t("wh_info", resolution=picture["resolution"].replace("x", " × "),
                                     mb=f"{size / 1048576:.1f}"),
                             xalign=0, hexpand=True, css_classes=["dim-label"]))
        bar.append(use_button(window, picture, ["pill", "suggested-action"]))
        view.add_bottom_bar(bar)
        self.set_child(view)

        def work():
            try:
                path = wallhaven.full(picture)
                texture = Gdk.Texture.new_from_filename(path)
            except (wallhaven.WallhavenError, GLib.Error):
                texture = None
            GLib.idle_add(done, texture)

        def done(texture):
            self.spinner.set_visible(False)
            if texture:
                self.picture.set_paintable(texture)
            return False
        threading.Thread(target=work, daemon=True).start()


class WallhavenCard(Gtk.Box):
    """One picture: its thumbnail, size, and a menu to use it on a workspace or on all of them."""

    def __init__(self, window, picture):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, css_classes=["card", "season"])
        self.window, self.picture, self.texture = window, picture, None
        self.set_overflow(Gtk.Overflow.HIDDEN)
        self.canvas = Canvas(self.draw, 280, 158, cursor=Gdk.Cursor.new_from_name("pointer"),
                             tooltip_text=t("wh_look"))
        click = Gtk.GestureClick()
        click.connect("released", lambda *a: WallhavenDetail(window, picture, self.texture).present(window))
        self.canvas.add_controller(click)
        self.append(self.canvas)
        row = Gtk.Box(spacing=6, margin_top=8, margin_bottom=8, margin_start=12, margin_end=8)
        row.append(Gtk.Label(label=picture["resolution"].replace("x", " × "), xalign=0, hexpand=True,
                             css_classes=["dim-label", "caption"]))
        row.append(use_button(window, picture, ["pill", "flat"]))
        self.append(row)

    def set_thumbnail(self, path):
        try:
            self.texture = Gdk.Texture.new_from_filename(path)
        except GLib.Error:
            self.texture = None
        self.canvas.queue_draw()

    def draw(self, p, w, h):
        if not self.texture:
            p.rect(0, 0, w, h, black(0.12))
            return
        tw, th = self.texture.get_width(), self.texture.get_height()
        scale = max(w / tw, h / th)
        p.clip(0, 0, w, h, 0.01)
        p.texture(self.texture, (w - tw * scale) / 2, (h - th * scale) / 2, tw * scale, th * scale)
        p.unclip()


class WallhavenWindow(Adw.Window):
    """Search on top, the pictures below: random ones when it opens, the theme's suggestion,
    the most popular, or what you type. Using one downloads it to Pictures/Wallhaven."""

    def __init__(self, win):
        super().__init__(transient_for=win, modal=False, title="Wallhaven",
                         default_width=1000, default_height=780)
        self.win, self.next, self.busy, self.generation = win, None, False, 0
        theme, palette = win.state["theme_obj"], win.state["palette"]
        self.suggestion = (engine.theme_value(theme, "wallhaven", palette),
                           engine.theme_value(theme, "wallhaven_colour", palette))
        self.atleast = screen_size(win)

        view = Adw.ToolbarView()
        header = Adw.HeaderBar(title_widget=Adw.WindowTitle(title="Wallhaven", subtitle=t("wh_subtitle")))
        view.add_top_bar(header)
        bar = Gtk.Box(spacing=10, margin_start=18, margin_end=18, margin_top=6, margin_bottom=10)
        self.entry = Gtk.SearchEntry(placeholder_text=t("wh_search"), hexpand=True)
        self.entry.connect("activate", lambda e: self.start("search"))
        bar.append(self.entry)
        self.modes = Adw.ToggleGroup(valign=Gtk.Align.CENTER)
        self.modes.add(Adw.Toggle(name="random", label=t("wh_random")))
        if self.suggestion[0]:
            self.modes.add(Adw.Toggle(name="theme", label=t("wh_theme", name=theme.get("name", theme["id"]))))
        self.modes.add(Adw.Toggle(name="top", label=t("wh_top")))
        self.modes.add(Adw.Toggle(name="search", label=t("wh_results"), enabled=False))
        self.modes.connect("notify::active-name", lambda g, _p: self.start(g.get_active_name(), from_toggle=True))
        bar.append(self.modes)
        view.add_top_bar(bar)

        self.stack = Gtk.Stack()
        scroll = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER)
        clamp = Adw.Clamp(maximum_size=1180, margin_top=6, margin_bottom=18, margin_start=18, margin_end=18)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        self.grid = flow()
        self.grid.set_min_children_per_line(3)
        self.grid.set_max_children_per_line(4)
        self.grid.set_row_spacing(14)
        self.grid.set_column_spacing(14)
        box.append(self.grid)
        self.more = Gtk.Button(label=t("wh_more"), css_classes=["pill"], halign=Gtk.Align.CENTER)
        self.more.connect("clicked", lambda b: self.load())
        box.append(self.more)
        box.append(Gtk.Label(label=t("wh_note", folder=pictures_folder()), wrap=True, xalign=0.5,
                             css_classes=["dim-label", "caption"], justify=Gtk.Justification.CENTER))
        clamp.set_child(box)
        scroll.set_child(clamp)
        self.stack.add_named(scroll, "grid")
        self.stack.add_named(Adw.Spinner(halign=Gtk.Align.CENTER, valign=Gtk.Align.CENTER,
                                         width_request=48, height_request=48), "loading")
        self.status = Adw.StatusPage(icon_name="image-missing-symbolic")
        self.stack.add_named(self.status, "status")
        self.toasts = Adw.ToastOverlay(child=self.stack)
        view.set_content(self.toasts)
        self.set_content(view)
        self.start("random")

    def query(self, mode):
        if mode == "theme":
            return self.suggestion[0], "relevance", self.suggestion[1]
        if mode == "top":
            return "", "toplist", ""
        if mode == "search":
            return self.entry.get_text(), "relevance", ""
        return "", "random", ""

    def start(self, mode, from_toggle=False):
        """A new search: empties the grid and loads the first page."""
        if mode == "search" and not self.entry.get_text().strip():
            return
        if not from_toggle and self.modes.get_active_name() != mode:
            self.modes.get_toggle_by_name("search").set_enabled(mode == "search")
            self.modes.set_active_name(mode)   # calls start again, from the toggle
            return
        self.mode, self.next = mode, (1, "")
        self.generation += 1
        while child := self.grid.get_first_child():
            self.grid.remove(child)
        self.stack.set_visible_child_name("loading")
        self.load()

    def load(self):
        if not self.next or self.busy:
            return
        self.busy = True
        self.more.set_sensitive(False)
        page, seed = self.next
        query, sorting, colour = self.query(self.mode)
        generation = self.generation

        def work():
            try:
                found, nxt = wallhaven.search(query, sorting, page, seed, colour, self.atleast)
                error = None
            except (wallhaven.WallhavenError, ValueError) as e:
                found, nxt, error = [], None, str(e)
            GLib.idle_add(self.loaded, generation, found, nxt, error)
        threading.Thread(target=work, daemon=True).start()

    def loaded(self, generation, found, nxt, error):
        self.busy = False
        if generation != self.generation:   # a newer search started meanwhile and waited for this one
            self.load()
            return False
        self.next = nxt
        cards = [WallhavenCard(self, picture) for picture in found]
        for card in cards:
            self.grid.append(card)
            card.get_parent().set_focusable(False)
        if error and not self.grid.get_first_child():
            self.status.set_title(t("wh_error"))
            self.status.set_description(error)
            self.stack.set_visible_child_name("status")
        elif not self.grid.get_first_child():
            self.status.set_title(t("wh_empty"))
            self.status.set_description(t("wh_empty_desc"))
            self.stack.set_visible_child_name("status")
        else:
            self.stack.set_visible_child_name("grid")
        self.more.set_visible(bool(nxt))
        self.more.set_sensitive(True)
        if error and self.grid.get_first_child():
            self.toasts.add_toast(Adw.Toast(title=error, timeout=6))

        def thumbs():   # one after another, in the background
            for card in cards:
                if generation != self.generation:
                    return
                try:
                    path = wallhaven.thumbnail(card.picture)
                except wallhaven.WallhavenError:
                    continue
                GLib.idle_add(card.set_thumbnail, path)
        threading.Thread(target=thumbs, daemon=True).start()
        return False

    def use(self, picture, workspaces):
        """Downloads the picture and sets it on those workspaces (None: on all of them)."""
        self.toasts.add_toast(Adw.Toast(title=t("wh_downloading"), timeout=3))

        def work():
            try:
                path = wallhaven.download(picture, pictures_folder())
                if workspaces is None:
                    notes = engine.pick(wallpaper_everywhere=path)
                else:
                    notes = []
                    for i in workspaces:
                        notes = engine.pick(wallpaper=(i, path))
                error = None
            except Exception as e:   # shown to the user, never a crash
                notes, error = [], str(e)
            GLib.idle_add(done, notes, error)

        def done(notes, error):
            self.win.refresh()
            if error:
                self.toasts.add_toast(Adw.Toast(title=t("failed", error=error), timeout=8))
            else:
                message = t("wh_all_set") if workspaces is None else t("wallpaper_set", n=workspaces[0] + 1)
                self.toasts.add_toast(Adw.Toast(title=message, timeout=5))
                for note in notes:
                    self.toasts.add_toast(Adw.Toast(title=note, timeout=5))
            return False
        threading.Thread(target=work, daemon=True).start()


# --- The window ------------------------------------------------------------------------------
class Window(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Seasons", default_width=1120, default_height=820)
        view = Adw.ToolbarView()
        header = Adw.HeaderBar(title_widget=Adw.WindowTitle(title="Seasons"))
        folder = Gtk.Button(icon_name="folder-open-symbolic", tooltip_text=t("folder"))
        folder.connect("clicked", self.open_folder)
        header.pack_end(folder)
        view.add_top_bar(header)

        self.stack = Adw.ViewStack()
        self.toasts = Adw.ToastOverlay(child=self.stack)
        view.set_content(self.toasts)
        view.add_bottom_bar(Adw.ViewSwitcherBar(stack=self.stack, reveal=True))
        self.set_content(view)

        self.state = self.read_state(first=True)
        themes_widget, themes_page = page_box(t("intro"))
        grid = flow()
        themes_page.append(grid)
        self.theme_cards = [ThemeCard(self, theme) for theme in engine.load_all()]
        for card in self.theme_cards:
            grid.append(card)
            card.get_parent().set_focusable(False)
        self.pages = [PacksPage(self, "icons"), PacksPage(self, "cursor"), FontsPage(self), WallpapersPage(self)]
        self.stack.add_titled_with_icon(themes_widget, "themes", t("tab_themes"), "applications-graphics-symbolic")
        for page, name, icon in zip(self.pages, ("icons", "cursors", "fonts", "wallpapers"),
                                    ("view-grid-symbolic", "input-mouse-symbolic",
                                     "font-select-symbolic", "image-x-generic-symbolic")):
            self.stack.add_titled_with_icon(page.widget, name, t("tab_" + name), icon)
        self.refresh()
        self.state["first"] = False

    def read_state(self, first=False):
        look = engine.read_look()
        state = {"look": look, "theme": look["theme"], "palette": look["palette"], "first": first,
                 "yaru": "", "theme_icons": "", "theme_cursor": "", "theme_interface_font": "",
                 "theme_monospace_font": "",
                 "now_wallpapers": [],
                 "use": {"icons": "", "cursor": "", "interface_font": "", "monospace_font": "", "wallpapers": []}}
        interface = engine.settings("org.gnome.desktop.interface")
        state["system_interface_font"] = interface.get_string("font-name") if interface else "Ubuntu Sans 11"
        state["system_monospace_font"] = interface.get_string("monospace-font-name") if interface else "Ubuntu Sans Mono 13"
        if look["theme"]:   # a theme that became palettes of another one
            look["theme"], look["palette"], mode = engine.moved(look["theme"], look["palette"], look["mode"])
            look["mode"] = mode or ""
            state["theme"], state["palette"] = look["theme"], look["palette"]
        try:
            theme = engine.load(look["theme"]) if look["theme"] else engine.load("kinobu")
        except engine.ThemeError:
            theme = engine.load_all()[0]
        try:
            palette = engine.resolve(theme, None, look["mode"] or None,
                                     look["palette"] if theme["id"] == look["theme"] else None)
        except engine.ThemeError:
            palette = engine.resolve(theme)
        state["theme_obj"], state["palette"] = theme, palette
        state["mode"] = mode = engine.mode_of(theme, palette)
        state["yaru"] = engine.GNOME_ACCENTS.get(engine.gnome_accent(theme, palette), ("", ""))[1]
        state["theme_icons"] = engine.theme_value(theme, "icons", palette, "Yaru")
        state["theme_cursor"] = engine.theme_value(theme, "cursor", palette, "Yaru")
        state["theme_interface_font"] = engine.theme_value(theme, "interface_font", palette)
        state["theme_monospace_font"] = engine.theme_value(theme, "monospace_font", palette)
        state["use"] = engine.effective(look, theme, palette)
        state["now_wallpapers"] = engine.current_wallpapers()
        if not engine.find_dir(state["use"]["cursor"], "icons"):
            state["use"]["cursor"] = "Yaru"
        if not engine.icon_theme(state["use"]["icons"], mode, state["yaru"]):
            state["use"]["icons"] = "Yaru"
        return state

    def look_preview(self):
        return Look(self.state["theme_obj"], self.state["palette"])

    def refresh(self, busy=False):
        if not busy:
            first = self.state.get("first", False)
            self.state = self.read_state(first=first)
        for card in self.theme_cards:
            card.refresh(self.state, busy)
        for page in self.pages:
            page.refresh(self.state, busy)

    def run(self, work, message):
        """Runs an engine call away from the window, then shows the result."""
        self.refresh(busy=True)

        def worker():
            try:
                notes, error = work(), None
            except Exception as e:   # shown to the user, never a crash
                notes, error = [], str(e)
            GLib.idle_add(done, notes, error)

        def done(notes, error):
            self.refresh()
            if error:
                self.toasts.add_toast(Adw.Toast(title=t("failed", error=error), timeout=8))
            else:
                self.toasts.add_toast(Adw.Toast(title=message, timeout=5))
                for note in notes or []:
                    self.toasts.add_toast(Adw.Toast(title=note, timeout=5))
            return False

        threading.Thread(target=worker, daemon=True).start()

    def open_folder(self, _button):
        os.makedirs(engine.USER_THEMES, exist_ok=True)
        Gio.AppInfo.launch_default_for_uri(GLib.filename_to_uri(engine.USER_THEMES), None)


CSS = """
.season { border-radius: 14px; }
.palette-chip { min-width: 30px; min-height: 30px; padding: 2px; }
.palette-chip:checked { box-shadow: inset 0 0 0 2px var(--accent-bg-color); }
.season-badge {
  padding: 2px 10px;
  border-radius: 999px;
  color: var(--accent-fg-color);
  background-color: var(--accent-bg-color);
}
.season-tag {
  padding: 2px 10px;
  border-radius: 999px;
  background-color: color-mix(in srgb, currentColor 10%, transparent);
}
"""


# seasons.py --page icons|cursors|fonts|wallpapers opens on that section
PAGE = sys.argv[sys.argv.index("--page") + 1] if "--page" in sys.argv[:-1] else "themes"


def main():
    app = Adw.Application(application_id=APP_ID)

    def activate(app):
        win = app.get_active_window()
        if not win:
            provider = Gtk.CssProvider()
            provider.load_from_string(CSS)
            Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider,
                                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            win = Window(app)
        if PAGE in ("themes", "icons", "cursors", "fonts", "wallpapers"):
            win.stack.set_visible_child_name(PAGE)
        win.present()

    app.connect("activate", activate)
    return app.run(sys.argv[:1])


if __name__ == "__main__":
    sys.exit(main())
