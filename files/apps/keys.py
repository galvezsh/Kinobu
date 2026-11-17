# Kinobu keyboard shortcuts window (Super+K). Written by Kinobu: rewritten on every run.
# Reads the cheat sheet (group, keys, action) and shows it like GNOME Settings; Esc closes it.
import gettext, os, sys
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk, Gdk

TSV = "@SYSTEM_DIR@/data/shortcuts.tsv"
title = gettext.translation("gtk40", fallback=True).gettext("Keyboard Shortcuts")


def build(app):
    win = Adw.ApplicationWindow(application=app, title="Kinobu · " + title,
                                default_width=640, default_height=760)
    page = Adw.PreferencesPage()
    groups = {}
    with open(TSV, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 3:
                continue
            group, keys, action = parts
            if group not in groups:
                groups[group] = Adw.PreferencesGroup(title=group)
                page.add(groups[group])
            row = Adw.ActionRow(title=action)
            label = Gtk.Label(label=keys, css_classes=["dim-label", "monospace"])
            row.add_suffix(label)
            groups[group].add(row)
    view = Adw.ToolbarView()
    view.add_top_bar(Adw.HeaderBar())
    view.set_content(page)
    win.set_content(view)
    esc = Gtk.ShortcutController()
    esc.add_shortcut(Gtk.Shortcut.new(Gtk.ShortcutTrigger.parse_string("Escape"),
                                      Gtk.CallbackAction.new(lambda *_: win.close() or True)))
    win.add_controller(esc)
    win.present()


def activate(app):
    # Super+K again: the running copy gets "activate" and closes its window (a toggle)
    win = app.get_active_window()
    if win:
        win.close()
    else:
        build(app)


app = Adw.Application(application_id="os.kinobu.Keys")
app.connect("activate", activate)
sys.exit(app.run([]))
