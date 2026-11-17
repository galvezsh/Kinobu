# Kinobu notice. Written by Kinobu: rewritten on every run and --update.
# kinobu-notify runs it in the background for every notice. It sends the notification itself
# over D-Bus, so the header shows the agent's name with a small terminal icon (notify-send
# cannot set that icon), and waits for a click to bring back the terminal the agent runs in.
# It ends when the notice is clicked or closed, or after four hours.
# Not tied to an app on purpose: GNOME removes an app's notices as soon as their sender leaves
# the bus, and only notices without an app survive notify-send-style senders.
import argparse

from gi.repository import Gio, GLib

ICON = "utilities-terminal"
# Terminals that are GApplications: activated over D-Bus with the click's activation token
GAPPS = {"org.gnome.Ptyxis": "/org/gnome/Ptyxis", "org.gnome.Terminal": "/org/gnome/Terminal"}

p = argparse.ArgumentParser()
p.add_argument("--app-name", default="Kinobu")
p.add_argument("--summary", default="")
p.add_argument("--body", default="")
p.add_argument("--urgency", type=int, default=1)
p.add_argument("--replace-id", type=int, default=0)
p.add_argument("--id-file", default="")
p.add_argument("--terminal", default="")
args = p.parse_args()

bus = Gio.bus_get_sync(Gio.BusType.SESSION)
hints = {"urgency": GLib.Variant("y", args.urgency), "image-path": GLib.Variant("s", ICON)}
actions = ["default", ""] if args.terminal else []
reply = bus.call_sync("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                      "org.freedesktop.Notifications", "Notify",
                      GLib.Variant("(susssasa{sv}i)", (args.app_name, args.replace_id, ICON,
                                                       args.summary, args.body, actions, hints, -1)),
                      GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, -1, None)
nid = reply.unpack()[0]
if args.id_file:
    with open(args.id_file, "w") as f:
        f.write(f"{nid}\n")
if not args.terminal:
    raise SystemExit(0)

loop = GLib.MainLoop()
token = {"value": ""}


def activate():
    """Bring the terminal back, passing GNOME's activation token so it may take the focus"""
    data = {"activation-token": GLib.Variant("s", token["value"]),
            "desktop-startup-id": GLib.Variant("s", token["value"])}
    path = GAPPS.get(args.terminal)
    try:
        if path:
            bus.call_sync(args.terminal, path, "org.freedesktop.Application", "Activate",
                          GLib.Variant("(a{sv})", (data,)), None, Gio.DBusCallFlags.NONE, 5000, None)
        else:
            info = Gio.DesktopAppInfo.new(f"{args.terminal}.desktop")
            ctx = Gio.AppLaunchContext()
            ctx.setenv("XDG_ACTIVATION_TOKEN", token["value"])
            ctx.setenv("DESKTOP_STARTUP_ID", token["value"])
            if info:
                info.launch([], ctx)
    except GLib.Error:
        pass


def on_signal(_conn, _sender, _path, _iface, signal, params):
    values = params.unpack()
    if values[0] != nid:
        return
    if signal == "ActivationToken":
        token["value"] = values[1]
    elif signal == "ActionInvoked" and values[1] == "default":
        activate()
        loop.quit()
    elif signal == "NotificationClosed":
        loop.quit()


bus.signal_subscribe(None, "org.freedesktop.Notifications", None,
                     "/org/freedesktop/Notifications", None, Gio.DBusSignalFlags.NONE, on_signal)
GLib.timeout_add_seconds(4 * 3600, loop.quit)
loop.run()
