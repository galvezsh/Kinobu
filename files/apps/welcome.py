# Kinobu welcome tour. Written by Kinobu: rewritten on every run.
# Seven short pages in one libadwaita window. The first full setup makes it open once (an
# autostart entry this window deletes when it closes); afterwards it is in the app grid.
# Arrows or the buttons change page; Esc closes it. Texts: i18n/<language>.json ("welcome").
import os
import re
import shutil
import subprocess
import sys

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, GLib, Gtk

HOME = os.path.expanduser("~")
AUTOSTART = os.path.join(HOME, ".config/autostart/kinobu-welcome.desktop")
LAUNCH = "@LAUNCHER@"
SEARCH_PATH = os.environ.get("PATH", "") + os.pathsep + os.path.join(HOME, ".local/bin")

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # kinobu_i18n lives next to it
from kinobu_i18n import language, texts  # noqa: E402

lang = language()
TEXT = texts("welcome", lang)                    # i18n/<language>.json, section "welcome"

# Coding agents Kinobu can install: (binary, name)
AGENTS = [("claude", "Claude Code")]

# Shortcut rows: (group, accelerators, text key). Kept in line with SHORTCUTS.
SHORTCUTS = [
    ("windows", "<Super>e", "sc.files"),
    ("windows", "<Super>v", "sc.clipboard_history"),
    ("windows", "<Super><Shift>s", "sc.screenshot"),
    ("windows", "<Super>l", "sc.lock_screen"),
    ("windows", "<Super>d", "sc.show_desktop"),
    ("windows", "<Super>Left <Super>Right", "sc.window_to_half_screen"),
    ("windows", "<Super><Primary>Left <Super><Primary>Right", "sc.switch_workspace"),
    ("windows", "<Primary><Shift>Escape", "sc.system_monitor"),
    ("kinobu", "<Super>Return", "sc.terminal"),
    ("kinobu", "<Super>b", "sc.web_browser"),
    ("kinobu", "<Super><Shift>Return", "sc.ai_agent"),
    ("kinobu", "<Super>space", "sc.voice_dictation"),
    ("kinobu", "<Super><Shift>space", "sc.talk_to_zen"),
    ("kinobu", "<Super>k", "sc.all_shortcuts"),
]

# Text about 18 % larger than libadwaita's (title 181 %/136 % compact, body 100 %, subtitle 83 %);
# the buttons keep their size. The application priority wins over the theme.
CSS = """
.kinobu-page image.icon { color: var(--accent-color); }
.kinobu-page box:not(.title) > label.title { font-size: 214%; }
.kinobu-page.compact box:not(.title) > label.title { font-size: 160%; }
.kinobu-page label.description,
.kinobu-page row box.title > label.title,
.kinobu-page label.heading,
.kinobu-page label.dim-label,
.kinobu-chip { font-size: 118%; }
.kinobu-page row label.subtitle { font-size: 98%; }
.kinobu-chip {
  padding: 6px 14px;
  border-radius: 999px;
  font-weight: bold;
  color: var(--accent-color);
  background-color: color-mix(in srgb, var(--accent-bg-color) 18%, transparent);
}
.kinobu-accent { color: var(--accent-color); }
"""

# Texts whose <b>…</b> key phrases are shown bold in the accent colour: (setter, markup).
# Pango markup cannot read CSS variables, so the colour is read from a hidden widget styled
# with var(--accent-color) (the same as the icons) and filled in again when it changes.
ACCENTED = []


def t(key):
    return TEXT.get(key, key)


def has(cmd):
    return shutil.which(cmd, path=SEARCH_PATH) is not None


def run(*cmd):
    try:
        subprocess.Popen(cmd, start_new_session=True, stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def page(icon, title, body, *extra):
    status = Adw.StatusPage(icon_name=icon, title=title,
                            css_classes=["kinobu-page"], vexpand=True, hexpand=True)
    ACCENTED.append((status.set_description, body))
    if extra:
        status.add_css_class("compact")     # smaller icon: room for the rows below
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        for widget in extra:
            box.append(widget)
        status.set_child(box)
    return status


def agents_widget():
    installed = [name for cmd, name in AGENTS if has(cmd)]
    if not installed:
        return Gtk.Label(label=t("p5.none"), use_markup=True, wrap=True,
                         justify=Gtk.Justification.CENTER, css_classes=["dim-label"])
    chips = Adw.WrapBox(child_spacing=8, line_spacing=8, align=0.5)
    for name in installed:
        chips.append(Gtk.Label(label=name, css_classes=["kinobu-chip"]))
    return chips


def shortcuts_widgets():
    groups = {"windows": Adw.PreferencesGroup(title=t("p6.windows")),
              "kinobu": Adw.PreferencesGroup(title=t("p6.kinobu"))}
    for group, accels, key in SHORTCUTS:
        if accels == "<Super>space" and not has("handy"):
            continue
        row = Adw.ActionRow(title=t(key))
        row.add_suffix(Adw.ShortcutLabel(accelerator=accels, valign=Gtk.Align.CENTER))
        groups[group].add(row)
    button = Gtk.Button(label=t("p6.all"), halign=Gtk.Align.CENTER, css_classes=["pill"])
    button.connect("clicked", lambda *_: run(LAUNCH, "keys"))
    return [groups["windows"], groups["kinobu"], button]


def step_row(icon, title, subtitle, command=None):
    row = Adw.ActionRow(title=title, use_markup=True)
    ACCENTED.append((row.set_subtitle, subtitle))
    row.add_prefix(Gtk.Image(icon_name=icon))
    if command:
        button = Gtk.Button(label=t("open"), valign=Gtk.Align.CENTER)
        button.connect("clicked", lambda *_: run(*command))
        row.add_suffix(button)
    return row


def steps_widgets():
    group = Adw.PreferencesGroup()
    mail = "p7.google.mail" if has("geary") else "p7.google.nomail"
    group.add(step_row("system-users-symbolic", t("p7.google"), t(mail),
                       ["gnome-control-center", "online-accounts"]))
    if has("handy"):
        group.add(step_row("audio-input-microphone-symbolic", t("p7.handy"), t("p7.handy.sub"),
                           ["handy"]))
    group.add(step_row("software-update-available-symbolic", t("p7.update"), t("p7.update.sub")))
    again = Gtk.Label(label=t("p7.again"), wrap=True, justify=Gtk.Justification.CENTER,
                      css_classes=["dim-label"])
    return [group, again]


def build(app):
    provider = Gtk.CssProvider()
    provider.load_from_string(CSS)
    Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider,
                                              Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    voice = t("p5.voice") if has("handy") else ""
    voice += t("p5.zen")
    pages = [
        page("computer-symbolic", t("p1.title"), t("p1.body")),
        page("starred-symbolic", t("p2.title"), t("p2.body")),
        page("distributor-logo-symbolic", t("p3.title"), t("p3.body")),
        page("user-desktop-symbolic", t("p4.title"), t("p4.body")),
        page("utilities-terminal-symbolic", t("p5.title"), t("p5.body") + voice, agents_widget()),
        page("input-keyboard-symbolic", t("p6.title"), t("p6.body"), *shortcuts_widgets()),
        page("emblem-ok-symbolic", t("p7.title"), t("p7.body"), *steps_widgets()),
    ]
    carousel = Adw.Carousel(allow_scroll_wheel=False, vexpand=True)
    for widget in pages:
        carousel.append(widget)

    back = Gtk.Button(label=t("back"), css_classes=["pill"])
    forward = Gtk.Button(label=t("next"), css_classes=["pill", "suggested-action"])
    bar = Gtk.CenterBox(margin_top=12, margin_bottom=12, margin_start=12, margin_end=12)
    bar.set_start_widget(back)
    bar.set_center_widget(Adw.CarouselIndicatorDots(carousel=carousel))
    bar.set_end_widget(forward)

    win = Adw.ApplicationWindow(application=app, title="Kinobu",
                                default_width=680, default_height=760)
    view = Adw.ToolbarView()
    header = Adw.HeaderBar(title_widget=Adw.WindowTitle(title="Kinobu", subtitle=t("welcome")))
    probe = Gtk.Label(css_classes=["kinobu-accent"], visible=False)
    header.pack_end(probe)
    view.add_top_bar(header)
    view.add_bottom_bar(bar)

    def paint(*_):
        c = probe.get_color()
        span = '<span weight="bold" foreground="#%02x%02x%02x">' % (
            round(c.red * 255), round(c.green * 255), round(c.blue * 255))
        for setter, markup in ACCENTED:
            setter(markup.replace("<b>", span).replace("</b>", "</span>"))
        return False

    # Accent or light/dark changed: wait for the new style, then repaint
    style = Adw.StyleManager.get_default()
    for prop in ("notify::accent-color", "notify::dark"):
        style.connect(prop, lambda *_: GLib.timeout_add(150, paint))
    view.set_content(carousel)
    win.set_content(view)
    paint()                                 # the probe is in the window now: it has the theme
    win.carousel = carousel

    def current():
        return round(carousel.get_position())

    def go(delta):
        index = current() + delta
        if index >= carousel.get_n_pages():
            win.close()
        elif index >= 0:
            carousel.scroll_to(carousel.get_nth_page(index), True)
        return True

    def changed(*_):
        index = current()
        back.set_sensitive(index > 0)
        last = index == carousel.get_n_pages() - 1
        forward.set_label(t("start") if last else t("next"))

    carousel.connect("page-changed", changed)
    back.connect("clicked", lambda *_: go(-1))
    forward.connect("clicked", lambda *_: go(1))
    changed()

    keys = Gtk.ShortcutController(propagation_phase=Gtk.PropagationPhase.CAPTURE)
    for trigger, action in (("Left", lambda *_: go(-1)), ("Right", lambda *_: go(1)),
                            ("Escape", lambda *_: win.close() or True)):
        keys.add_shortcut(Gtk.Shortcut.new(Gtk.ShortcutTrigger.parse_string(trigger),
                                           Gtk.CallbackAction.new(action)))
    win.add_controller(keys)

    def closing(*_):
        # Shown once: the autostart entry written by the setup goes away
        try:
            os.remove(AUTOSTART)
        except OSError:
            pass
        return False

    win.connect("close-request", closing)
    win.set_default_widget(forward)
    win.present()
    forward.grab_focus()
    return win


def activate(app):
    win = app.get_active_window()
    if win:
        win.present()
    else:
        build(app)


def main():
    app = Adw.Application(application_id="os.kinobu.Welcome")
    app.connect("activate", activate)
    return app.run([])


if __name__ == "__main__":
    sys.exit(main())
