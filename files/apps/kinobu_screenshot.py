# The screen as a picture, through the desktop's screenshot portal (GNOME 50 lets no other app
# take one silently). GNOME asks the user once whether the app may take screenshots and remembers
# the answer. Written by Kinobu: rewritten on every run and --update.
# Usage: python3 kinobu_screenshot.py OUTPUT.png   (prints the file, or an error and exits 1)
import os
import shutil
import sys

from gi.repository import Gio, GLib


def main(dest):
    bus = Gio.bus_get_sync(Gio.BusType.SESSION)
    token = f"kinobu{os.getpid()}"
    sender = bus.get_unique_name()[1:].replace(".", "_")
    handle = f"/org/freedesktop/portal/desktop/request/{sender}/{token}"
    loop, result = GLib.MainLoop(), {}

    def on_response(_bus, _sender, _path, _iface, _signal, params):
        code, results = params.unpack()
        result["code"], result["uri"] = code, results.get("uri", "")
        loop.quit()

    bus.signal_subscribe("org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request", "Response",
                         handle, None, Gio.DBusSignalFlags.NO_MATCH_RULE, on_response)
    try:
        bus.call_sync("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
                      "org.freedesktop.portal.Screenshot", "Screenshot",
                      GLib.Variant("(sa{sv})", ("", {"handle_token": GLib.Variant("s", token),
                                                     "interactive": GLib.Variant("b", False)})),
                      None, Gio.DBusCallFlags.NONE, -1, None)
    except GLib.Error as e:
        print(f"Error: the screenshot portal is not available ({e.message})")
        return 1
    GLib.timeout_add_seconds(60, loop.quit)       # the user may be answering GNOME's question
    loop.run()
    if result.get("code") != 0 or not result.get("uri"):
        print("Error: no screenshot (the permission was refused, or nobody answered)")
        return 1
    source = GLib.filename_from_uri(result["uri"])[0]
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.move(source, dest)                    # out of ~/Pictures: it is only for Willow
    print(dest)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
