# Kinobu texts for the apps written in Python. Every text lives in i18n/<language>.json, one
# section per app ("welcome", "voice"...); a missing language or text falls back to English.
# Installed next to the apps in Kinobu's system folder; in the repository it reads files/i18n.
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
FOLDERS = (os.path.join(HERE, "i18n"), os.path.join(HERE, "..", "i18n"))


def language():
    """The desktop language as a two-letter code (en when unknown)."""
    raw = (os.environ.get("LANGUAGE") or os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES")
           or os.environ.get("LANG") or "en")
    return re.split(r"[_.:@]", raw)[0] or "en"


def texts(section, lang=None):
    """The texts of one app: English first, then the desktop language on top of it."""
    folder = next((f for f in FOLDERS if os.path.isdir(f)), FOLDERS[0])
    out = {}
    for code in dict.fromkeys(("en", lang or language())):
        try:
            with open(os.path.join(folder, code + ".json"), encoding="utf-8") as f:
                out.update(json.load(f).get(section, {}))
        except (OSError, ValueError):
            pass
    return out
