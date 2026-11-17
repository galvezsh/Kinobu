# Kinobu approval window. Written by Kinobu: rewritten on every run.
# kinobu-notify opens it when Claude Code or Codex asks for a permission. It prints "allow" or
# "deny"; closing it, Esc, "In terminal" or the countdown print nothing, so the agent's own
# prompt in the terminal decides. Every text comes translated from kinobu-notify.
import argparse
import sys

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, Gio, GLib, Gtk

CSS = """
window.kinobu-approve { border: 2px solid var(--accent-bg-color); border-radius: 15px; }
.kinobu-approve .kinobu-icon { color: var(--accent-color); }
.kinobu-approve .kinobu-agent { color: var(--accent-color); }
.kinobu-approve .kinobu-project { padding: 3px 12px; border-radius: 999px;
  background-color: color-mix(in srgb, var(--accent-bg-color) 15%, transparent); }
.kinobu-approve .kinobu-card { padding: 12px 14px; border-left: 3px solid var(--accent-bg-color); }
.kinobu-approve .kinobu-detail { font-size: 95%; opacity: 0.85; }
.kinobu-approve button.kinobu-choice { font-weight: bold; padding: 8px 14px; }
.kinobu-approve button.kinobu-terminal { background-color: var(--warning-bg-color); color: var(--warning-fg-color); }
.kinobu-approve button.kinobu-allow { background-color: var(--success-bg-color); color: var(--success-fg-color); }
.kinobu-approve button.kinobu-deny { background-color: var(--destructive-bg-color); color: var(--destructive-fg-color); }
"""


def parse():
    p = argparse.ArgumentParser()
    for name in ("agent", "project", "tool", "detail", "question", "allow", "deny", "terminal",
                 "countdown", "title"):
        p.add_argument("--" + name, default="")
    p.add_argument("--timeout", type=int, default=45)
    return p.parse_args()


def build(app, args):
    provider = Gtk.CssProvider()
    provider.load_from_string(CSS)
    Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider,
                                              Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    win = Adw.ApplicationWindow(application=app, title=f"Kinobu · {args.title}",
                                default_width=540, resizable=False)
    win.add_css_class("kinobu-approve")    # added: css_classes= would drop "background"
    win.answer = ""

    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, margin_top=8,
                  margin_bottom=20, margin_start=24, margin_end=24)
    box.append(Gtk.Image(icon_name="security-high-symbolic", pixel_size=48,
                         css_classes=["kinobu-icon"]))
    heading = Gtk.Box(spacing=8, halign=Gtk.Align.CENTER)
    heading.append(Gtk.Label(label=args.agent, css_classes=["title-2", "kinobu-agent"]))
    heading.append(Gtk.Label(label=args.question, css_classes=["title-2"]))
    box.append(heading)
    if args.project:
        project = Gtk.Box(spacing=6, halign=Gtk.Align.CENTER, css_classes=["kinobu-project"])
        project.append(Gtk.Image(icon_name="folder-symbolic"))
        project.append(Gtk.Label(label=args.project))
        box.append(project)

    card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin_top=6,
                   css_classes=["card", "kinobu-card"])
    card.append(Gtk.Label(label=args.tool or "Tool", xalign=0, css_classes=["heading"]))
    if args.detail:
        detail = Gtk.Label(label=args.detail, xalign=0, wrap=True, selectable=True,
                           wrap_mode=2, css_classes=["monospace", "kinobu-detail"])
        scroll = Gtk.ScrolledWindow(child=detail, propagate_natural_height=True,
                                    max_content_height=180,
                                    hscrollbar_policy=Gtk.PolicyType.NEVER)
        card.append(scroll)
    box.append(card)

    countdown = Gtk.Label(css_classes=["dim-label", "caption"], margin_top=4)
    box.append(countdown)

    buttons = Gtk.Box(spacing=10, homogeneous=True, margin_top=4)
    for label, answer, css in ((args.allow, "allow", "kinobu-allow"),
                               (args.terminal, "", "kinobu-terminal"),
                               (args.deny, "deny", "kinobu-deny")):
        button = Gtk.Button(label=label, css_classes=["pill", "kinobu-choice", css])
        button.connect("clicked", lambda _b, a=answer: finish(a))
        buttons.append(button)
    box.append(buttons)

    view = Adw.ToolbarView()
    view.add_top_bar(Adw.HeaderBar(title_widget=Adw.WindowTitle(title="Kinobu",
                                                               subtitle=args.title)))
    view.set_content(box)
    win.set_content(view)

    # The window takes the keyboard from whatever the user was doing. Two guards so a key or a
    # click already on its way never answers: no button starts with the focus (Space and Enter
    # do nothing until Tab chooses one), and nothing counts during the first moment on screen.
    ready = [False]

    def finish(answer):
        if not ready[0]:
            return
        win.answer = answer
        win.close()

    left = [max(args.timeout, 1)]

    def tick():
        countdown.set_label(args.countdown.replace("%s", str(left[0])))
        left[0] -= 1
        if left[0] < 0:
            win.close()
            return False
        return True

    tick()
    GLib.timeout_add_seconds(1, tick)
    esc = Gtk.ShortcutController()
    esc.add_shortcut(Gtk.Shortcut.new(Gtk.ShortcutTrigger.parse_string("Escape"),
                                      Gtk.CallbackAction.new(lambda *_: win.close() or True)))
    win.add_controller(esc)
    win.present()
    win.set_focus(None)
    GLib.idle_add(lambda: win.set_focus(None) and False)
    GLib.timeout_add(800, lambda: ready.__setitem__(0, True) and False)
    return win


def main():
    args = parse()
    app = Adw.Application(application_id="os.kinobu.Approve",
                          flags=Gio.ApplicationFlags.NON_UNIQUE)
    state = {}
    app.connect("activate", lambda a: state.setdefault("win", build(a, args)))
    app.run([])
    answer = getattr(state.get("win"), "answer", "")
    if answer:
        print(answer)


if __name__ == "__main__":
    sys.exit(main())
