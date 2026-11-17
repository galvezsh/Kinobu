"""Opens the approval window for a moment and prints what has the keyboard focus.
No button may have it: the window takes the keyboard from the user, so a key already on its
way (Space, Enter) must not answer. Usage: approve-focus.py PATH/approve.py"""
import sys, importlib.util
spec = importlib.util.spec_from_file_location("approve", sys.argv[1]); m = importlib.util.module_from_spec(spec)
sys.argv = ["approve.py", "--agent", "Claude Code", "--project", "kinobu-prueba", "--tool", "Bash", "--detail", "echo prueba",
            "--allow", "Allow", "--deny", "Deny", "--terminal", "In terminal", "--countdown", "%s", "--title", "t", "--question", "q", "--timeout", "30"]
spec.loader.exec_module(m)
from gi.repository import Adw, Gio, GLib, Gtk
args = m.parse()
app = Adw.Application(application_id="os.kinobu.FocusTest", flags=Gio.ApplicationFlags.NON_UNIQUE)
def go(a):
    win = m.build(a, args)
    def look():
        f = win.get_focus()
        print("focus:", type(f).__name__, getattr(f, "get_label", lambda: "")() if f else None, "| default:", win.get_default_widget())
        win.close(); return False
    GLib.timeout_add(400, look)
app.connect("activate", go); app.run([])
