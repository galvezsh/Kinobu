# Willow, the voice assistant of Kinobu. It listens (PipeWire + Handy), answers with a small headless
# agent (Haiku at low effort by default, or more power from its settings: read-only commands, the
# web, kinobu-do's safe actions, a look at the screen, Kinobu's skill read on demand) and speaks the answer sentence by sentence (voice-tts.py:
# Kokoro, Piper or Qwen3-TTS). Quick checks that need more care run in the background on a stronger
# model; real work goes to the full agent in a terminal. Esc closes it and the talk is forgotten.
# The microphone follows the system's mute (Super+Alt+K); with the sound muted it answers in text.
# Settings (engine, voice, listening mode, power, an optional manner) live in ~/.config/kinobu/voice.json.
# Not wired into kinobu.sh yet: run it with  python3 voice.py   (or --demo for a scripted show)
import argparse
import colorsys
import json
import math
import os
import queue
import random
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import wave
from array import array
from datetime import datetime

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Gsk", "4.0")
from gi.repository import Adw, Gdk, Gio, GLib, Graphene, Gsk, Gtk  # noqa: E402
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # kinobu_i18n lives next to it
from kinobu_i18n import language, texts  # noqa: E402

APP_ID = "os.kinobu.Voice"
CONFIG = os.path.join(GLib.get_user_config_dir(), "kinobu", "voice.json")
SAMPLES = os.path.join(GLib.get_user_data_dir(), "kinobu", "voice", "samples")

# Voice engines, lightest first: id -> (name, tier key, [(voice id, label key)])
# Voices: (id, label key, f/m, language). Each language shows its own, English for the rest; Qwen3-TTS
# speaks any language ("*") from a reference voice of that language when there is one.
ENGINES = {
    "piper": ("Piper", "tier_piper", [("davefx", "v_davefx", "m", "es"), ("joe", "v_joe", "m", "en"),
                                      ("kristin", "v_kristin", "f", "en")]),
    "kokoro": ("Kokoro", "tier_kokoro", [("em_santa", "v_santa", "m", "es"), ("ef_dora", "v_dora", "f", "es"),
                                         ("em_alex", "v_alex", "m", "es"), ("af_heart", "v_heart", "f", "en"),
                                         ("af_bella", "v_bella", "f", "en"), ("am_michael", "v_michael", "m", "en"),
                                         ("am_fenrir", "v_fenrir", "m", "en")]),
    "qwen": ("Qwen3-TTS", "tier_qwen", [("kinobu", "v_kinobu", "f", "*"), ("santa", "v_qsanta", "m", "*")]),
}
VOICE_LANGS = {"es", "en"}               # languages with their own voices so far
# Qwen3-TTS clones these Kokoro voices, one reference per language (made by --prepare)
QWEN_REFS = {"es": {"kinobu": "ef_dora", "santa": "em_santa"},
             "en": {"kinobu": "af_heart", "santa": "am_michael"}}
# Personal voices for Qwen3-TTS: <id>.wav (5-15 s of clear speech) + <id>.json {"name", "gender"}.
# They stay on this computer; Kinobu ships none.
PERSONAL = os.path.join(GLib.get_user_data_dir(), "kinobu", "voice", "voices")
# Read-only commands the assistant may run on its own to answer about this computer. Anything
# else is refused automatically and becomes a hand-over to the full agent.
READ_ONLY = ["lspci", "lsusb", "lscpu", "lsblk", "lsmod", "modinfo", "free", "df", "du -sh", "uptime",
             "uname", "hostnamectl status", "lsb_release", "nvidia-smi", "sensors", "upower -d",
             "upower -i", "date", "cal", "journalctl", "systemctl status", "systemctl --failed",
             "systemctl --user status", "systemctl --user --failed", "systemctl list-units",
             "systemctl is-active", "systemctl is-failed", "systemd-analyze", "dpkg -l", "dpkg --audit",
             "dpkg-query", "apt list", "apt-cache policy", "apt policy", "snap list", "snap changes",
             "flatpak list", "ubuntu-drivers list", "mokutil --sb-state", "ip -br", "ip addr",
             "ip route", "nmcli general status", "nmcli device status", "ping -c", "wpctl status",
             "wpctl get-volume", "gsettings get", "ps aux", "ps -eo", "top -bn1", "who", "fastfetch",
             "cat /proc/", "cat /sys/", "cat /etc/os-release", "cat /var/log/", "zcat /var/log/",
             "ls", "grep", "head", "tail -n", "wc", "sort", "uniq"]
# The only actions beyond reading: open an installed app, a web page in the default browser, a folder
OPENERS = ["gtk-launch", "nautilus --new-window", "xdg-open"]   # rules match whole words, not URL prefixes
SKILL_DIR = "@SYSTEM_DIR@/skills/kinobu"        # read only when Willow is unsure, never loaded up front
SCREEN_DIR = os.path.join(GLib.get_user_cache_dir(), "kinobu", "willow")   # kinobu-do screenshot
# Folders outside $HOME it may read (Claude Code asks for anything outside the working folder)
READ_DIRS = ["/usr/share/applications", "/var/lib/snapd/desktop/applications", "/var/log", "/etc",
             SKILL_DIR]
# Read: only the skill and the last screenshot ("//" is an absolute path in Claude Code's rules)
READ_FILES = [f"Read(/{SKILL_DIR}/**)", f"Read(/{SCREEN_DIR}/**)"]
LOOKING = ["WebSearch", "WebFetch"] + [f"Bash({c}:*)" for c in READ_ONLY] + READ_FILES
# Willow itself may also open things and take kinobu-do's safe actions; background jobs only look
ALLOWED = LOOKING + [f"Bash({c}:*)" for c in OPENERS] + ["Bash(kinobu-do:*)"]
# How much thinking Willow puts into an answer: (model, effort). Quick suits every day; the others
# take longer and use more (Sonnet costs about 20 times what Haiku does per token).
POWERS = {"quick": ("haiku", "low"), "smart": ("haiku", "high"), "strong": ("sonnet", "medium")}
DEFAULTS = {"engine": "kokoro", "voice": "em_santa", "continuous": True, "power": "quick",
            "background_model": "sonnet", "background_effort": "medium",
            "persona": "", "idle_close": 60}
BACKGROUND = re.compile(r"\[\[\s*background:\s*(.+?)\]\]", re.S | re.I)
HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.join(GLib.get_user_data_dir(), "kinobu", "voice", "models")
LLAMA = os.path.join(GLib.get_user_data_dir(), "kinobu", "voice", "llama")     # only with Qwen3-TTS
UV = shutil.which("uv") or os.path.expanduser("~/.local/bin/uv")
# The speech worker runs in its own Python (uv caches it): Kokoro and Piper with their models loaded
TTS_ENV = [UV, "run", "-q", "--no-project", "--python", "3.12", "--with", "kokoro-onnx==0.6.1",
           "--with", "piper-tts==1.8.0", "--with", "soundfile", "python",
           os.path.join(HERE, "voice-tts.py"), MODELS,
           LLAMA]
SENTENCE = re.compile(r"(.+?[.!?…:;])(\s+|$)", re.S)
CLOSE = re.compile(r"\[\[\s*close\s*\]\]", re.I)
DELEGATE = re.compile(r"\[\[\s*delegate:\s*(.+?)\]\]", re.S | re.I)
AGENT_NAMES = {"claude": "Claude Code"}

CSS = """
.kinobu-voice .kinobu-status { font-weight: 600; letter-spacing: 0.02em; }
.kinobu-voice .kinobu-dot { color: var(--accent-color); font-size: 70%; }
.kinobu-voice .kinobu-dot.off { color: var(--destructive-color); }
.kinobu-voice .kinobu-bubble { padding: 9px 13px; border-radius: 14px; }
.kinobu-voice .kinobu-bubble.them { border-bottom-left-radius: 4px;
  border-left: 3px solid var(--accent-bg-color);
  background-color: color-mix(in srgb, var(--accent-bg-color) 12%, transparent); }
.kinobu-voice .kinobu-bubble.me { border-bottom-right-radius: 4px;
  background-color: color-mix(in srgb, currentColor 8%, transparent); }
.kinobu-voice .kinobu-who { font-weight: 800; font-size: 75%; letter-spacing: 0.06em; opacity: 0.6; }
.kinobu-voice .them .kinobu-who { color: var(--accent-color); opacity: 1; }
.kinobu-voice .kinobu-card { padding: 12px 14px; border-left: 3px solid var(--accent-bg-color); }
.kinobu-voice .kinobu-chip { padding: 2px 10px; border-radius: 999px; font-size: 90%;
  background-color: color-mix(in srgb, var(--accent-bg-color) 15%, transparent); }
.kinobu-voice entry.kinobu-entry { border-radius: 999px; min-height: 40px; padding: 0 16px; }
.kinobu-voice button.kinobu-mic { min-width: 44px; min-height: 44px; padding: 0; }
.kinobu-voice button.kinobu-mic:not(:checked) { background-color: var(--destructive-bg-color);
  color: var(--destructive-fg-color); }
"""

LANG = language()
TEXTS = texts("voice", LANG)                     # i18n/<language>.json, section "voice"
LANGUAGE_NAMES = {"en": "English", "es": "Spanish", "fr": "French", "de": "German", "it": "Italian",
                  "pt": "Portuguese"}


def t(key):
    return TEXTS.get(key, key)


def personal_voices():
    found = {}
    for name in sorted(os.listdir(PERSONAL)) if os.path.isdir(PERSONAL) else []:
        stem, ext = os.path.splitext(name)
        if ext == ".wav":
            try:
                with open(os.path.join(PERSONAL, stem + ".json"), encoding="utf-8") as f:
                    meta = json.load(f)
            except (OSError, ValueError):
                meta = {}
            found["my-" + stem] = meta | {"name": meta.get("name", stem.capitalize())}
    return found


def voices_for(engine):
    """(voice id, label) pairs of an engine in the desktop language; Qwen3-TTS adds the personal ones."""
    lang = LANG if LANG in VOICE_LANGS else "en"
    voices = [(v, t(label)) for v, label, _g, vl in ENGINES[engine][2] if vl in (lang, "*")]
    if engine == "qwen":
        voices += [(v, f"{m['name']} · {t('personal')}") for v, m in personal_voices().items()]
    return voices


def female(voice):
    genders = {v: g for _name, _tier, voices in ENGINES.values() for v, _l, g, _vl in voices}
    return genders.get(voice) == "f" or personal_voices().get(voice, {}).get("gender") == "female"


def load_config():
    config = dict(DEFAULTS)
    try:
        with open(CONFIG, encoding="utf-8") as f:
            config.update(json.load(f))
    except (OSError, ValueError):
        pass
    if config["engine"] not in ENGINES:
        config["engine"] = DEFAULTS["engine"]
    if config["power"] not in POWERS:
        config["power"] = DEFAULTS["power"]
    ids = [v for v, _label in voices_for(config["engine"])]
    if config["voice"] not in ids:                     # e.g. a Spanish voice on an English desktop
        config["voice"] = ids[0]
    return config


def save_config(config):
    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    with open(CONFIG, "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)


def sample(engine, voice):
    """A recorded sample of this voice (the demo's first answer), or None."""
    path = os.path.join(SAMPLES, f"{engine}-{voice}.wav")
    return path if os.path.isfile(path) else None


def envelope(path, step=0.02):
    """Loudness of a WAV every `step` seconds, 0..1, to move the sphere with the voice."""
    with wave.open(path) as w:
        rate, data = w.getframerate(), array("h", w.readframes(w.getnframes()))
    size = max(int(rate * step), 1)
    env = [math.sqrt(sum(x * x for x in data[i:i + size]) / size) for i in range(0, len(data), size)]
    top = max(env) or 1
    return [min(v / top * 1.4, 1) for v in env], len(data) / rate


# ---- drawing helpers ------------------------------------------------------------------------
def rgba(rgb, a):
    color = Gdk.RGBA()
    color.red, color.green, color.blue, color.alpha = *rgb, a
    return color


def stops(*pairs):
    out = []
    for offset, color in pairs:
        stop = Gsk.ColorStop()
        stop.offset, stop.color = offset, color
        out.append(stop)
    return out


def point(x, y):
    return Graphene.Point().init(x, y)


def square(cx, cy, r):
    return Graphene.Rect().init(cx - r, cy - r, 2 * r, 2 * r)


def shift(rgb, hue=0.0, light=0.0, sat=1.0):
    h, l, s = colorsys.rgb_to_hls(*rgb)
    return colorsys.hls_to_rgb((h + hue) % 1, min(max(l + light, 0), 1), min(s * sat, 1))


def blob(cx, cy, radius, amp, phase, seed):
    """Closed wobbly shape: a circle whose radius waves with three slow harmonics."""
    builder = Gsk.PathBuilder.new()
    for i in range(97):
        a = 2 * math.pi * i / 96
        wave_ = (0.55 * math.sin(2 * a + phase * 1.3 + seed) + 0.30 * math.sin(3 * a - phase * 1.7 + seed * 2)
                 + 0.15 * math.sin(5 * a + phase * 2.3 + seed * 3))
        r = radius * (1 + amp * wave_)
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        if i == 0:
            builder.move_to(x, y)
        else:
            builder.line_to(x, y)
    builder.close()
    return builder.to_path()


# How each state moves the orb: size, wobble, speed, how much the sound level counts, swirl
STYLE = {
    "listening":    (0.95, 0.05, 1.0, 0.18, 0.0),
    "transcribing": (0.84, 0.04, 3.0, 0.00, 0.0),
    "thinking":     (0.88, 0.10, 2.2, 0.00, 0.14),
    "speaking":     (0.95, 0.07, 1.4, 0.24, 0.0),
    "delegating":   (0.95, 0.07, 1.4, 0.24, 0.0),
    "paused":       (0.80, 0.02, 0.3, 0.00, 0.0),
    "muted":        (0.80, 0.02, 0.3, 0.00, 0.0),
}


class Sphere(Gtk.Widget):
    """A soft, living orb: three translucent layers in the accent colour and its neighbours
    that wobble and swirl with the assistant's state and with the voice (yours or hers)."""

    def __init__(self):
        super().__init__(hexpand=True, height_request=220)
        self.state, self.level, self.shown, self.phase = "listening", 0.0, 0.0, 0.0
        self.last = time.monotonic()
        self.style = list(STYLE["listening"])
        self.add_tick_callback(lambda *_: self.queue_draw() or True)

    def accent(self):
        try:
            c = Adw.StyleManager.get_default().get_accent_color_rgba()
            return c.red, c.green, c.blue
        except AttributeError:
            return 0.21, 0.52, 0.89

    def do_snapshot(self, snap):
        now = time.monotonic()
        dt, self.last = min(now - self.last, 0.1), now
        self.style = [cur + (goal - cur) * 0.08 for cur, goal in zip(self.style, STYLE[self.state])]
        size, wobble, speed, react, swirl = self.style
        self.shown += (self.level - self.shown) * 0.25
        self.phase += dt * speed
        w, h = self.get_width(), self.get_height()
        cx, cy = w / 2, h / 2
        radius = min(w, h) * 0.30 * (size + react * self.shown)
        amp = wobble + react * 0.8 * self.shown
        accent = self.accent()
        if self.state in ("paused", "muted"):
            accent = shift(accent, sat=0.15)
        fade = 0.45 if self.state in ("paused", "muted") else 1.0

        halo = radius * 1.7                                   # soft light around the orb
        snap.append_radial_gradient(square(cx, cy, halo), point(cx, cy), halo, halo, 0.35, 1,
                                    stops((0, rgba(accent, 0.28 * fade)), (1, rgba(accent, 0))))
        if self.state in ("speaking", "delegating"):            # rings leaving the orb
            for k in range(2):
                p = (self.phase * 0.5 + k / 2) % 1
                snap.append_stroke(blob(cx, cy, radius * (1.08 + 0.5 * p), amp * 0.5, self.phase, k),
                                   Gsk.Stroke.new(1.5), rgba(accent, 0.30 * (1 - p)))

        layers = ((shift(accent, hue=0.10, light=0.05), 0.55, 1.00, 0.0),
                  (shift(accent, hue=-0.09, light=0.02), 0.55, 0.96, 2.1),
                  (shift(accent, light=0.08), 0.75, 0.86, 4.2))
        for i, (color, alpha, scale, seed) in enumerate(layers):
            angle = self.phase * (0.6 + i * 0.25) + seed
            ox = cx + radius * swirl * math.cos(angle)
            oy = cy + radius * swirl * math.sin(angle)
            r = radius * scale
            snap.push_fill(blob(ox, oy, r, amp, self.phase + seed, seed), Gsk.FillRule.WINDING)
            snap.append_radial_gradient(square(ox, oy, r * 1.4), point(ox - r * 0.25, oy - r * 0.3),
                                        r * 1.3, r * 1.3, 0, 1,
                                        stops((0, rgba(shift(color, light=0.22), alpha * fade)),
                                              (0.6, rgba(color, alpha * 0.85 * fade)),
                                              (1, rgba(shift(color, light=-0.12), alpha * 0.55 * fade))))
            snap.pop()
        glint = radius * 0.55                                 # a gentle light inside, not a hard shine
        gx, gy = cx - radius * 0.22, cy - radius * 0.28
        snap.append_radial_gradient(square(gx, gy, glint), point(gx, gy), glint, glint, 0, 1,
                                    stops((0, rgba((1, 1, 1), 0.22 * fade)), (1, rgba((1, 1, 1), 0))))


# ---- the engine: microphone, transcription, agent and voice ----------------------------------
def agent_path():
    try:
        with open(os.path.join(GLib.get_user_config_dir(), "kinobu", "agent"), encoding="utf-8") as f:
            path = f.read().strip()
    except OSError:
        path = ""
    return path if os.access(path, os.X_OK) else shutil.which("claude")


def agent_name():
    path = agent_path() or ""
    return AGENT_NAMES.get(os.path.basename(path), os.path.basename(path) or "?")


def gender_note(voice):
    return "feminine" if female(voice) else "masculine"


# What Willow knows about Kinobu, so it can guide people who have never used Linux
ABOUT_KINOBU = (
    "About this computer: Kinobu is a layer over Ubuntu 26.04 LTS (GNOME desktop) that sets up "
    "the system, the apps, several AI agents, the shortcuts and the look so that everything works "
    "together from the first minute, with nothing to configure. It was born from Omarchy, DHH's "
    "Arch Linux + Hyprland setup: great ideas, but very technical, a desktop you have to learn from "
    "scratch and a rolling base that updates can break. Kinobu brings what works to a stable base "
    "made for real work and programming: Ubuntu's long-term support keeps the same desktop for "
    "years, and GNOME is familiar (the looks of macOS, the shortcuts of Windows, the workspaces of "
    "Linux). The desktop: a dock at the bottom, 4 workspaces with their own wallpaper, a top bar "
    "with the clock, the weather, the clipboard and the notifications. The Super key is the "
    "Windows key; Super+K shows every shortcut on screen (the cheat sheet), Super+A shows all "
    "apps. The AI agent (Claude Code) opens in a terminal with "
    "Super+Shift+Enter, knows the system through Kinobu's skill and notifies when it finishes or "
    "need permission. Handy types what you dictate (Super+Space) and you, Willow, are the voice to "
    "talk to the computer (Super+Shift+Space). 'bash kinobu.sh --update' keeps Ubuntu, the apps "
    "and Kinobu up to date without touching the user's look. Many people here come from Windows "
    "or macOS and have never used Linux: guide them calmly, in plain, natural words, one step at "
    "a time, explaining any term; prefer a shortcut or a click to the terminal, and when a "
    "terminal is needed give the exact command and say what it does. ")
SHORTCUTS_TSV = "@SYSTEM_DIR@/data/shortcuts.tsv"


def shortcuts_text():
    """The real shortcuts of this computer, from the Super+K cheat sheet Kinobu writes."""
    try:
        with open(SHORTCUTS_TSV, encoding="utf-8") as f:
            rows = [line.rstrip("\n").split("\t") for line in f if line.count("\t") == 2]
    except OSError:
        return ""
    return ("Shortcuts on this computer (the Super+K list): "
            + "; ".join(f"{keys}: {action}" for _group, keys, action in rows) + ". ")


def system_prompt(config):
    """Willow's whole context: who it is, Kinobu and its shortcuts, how to talk, its tools, when to
    delegate. The stable part goes first and the time last, so it caches across conversations."""
    now = datetime.now().astimezone()
    language = LANGUAGE_NAMES.get(LANG, "the user's language")
    return (f"You are {t('app')}, the voice assistant of Kinobu on this computer: your name is "
            f"{t('app')}, use it when you introduce yourself, whatever voice you speak with. The user "
            "talks to you by voice and hears you through text-to-speech. "
            + ABOUT_KINOBU + shortcuts_text() +
            "Your manner: warm, direct and friendly, with charisma and a light sense of humour, like a "
            "good friend who knows computers well: relaxed and natural, never stiff or servile. A quick "
            "joke now and then is welcome, but the useful answer always comes first. "
            + (f"The user asked you to talk like this, which wins over the manner above: {config['persona'][:500]}. "
               if config.get("persona", "").strip() else "") +
            "Answer spoken, in one to three short sentences (a little more when you guide "
            "someone step by step): no Markdown, lists, emojis, code or file paths unless asked; say "
            "numbers, times and key names the way people say them. "
            "Tools: WebSearch and WebFetch for quick facts from the internet, and Bash limited to "
            "read-only commands (hardware, lspci, nvidia-smi, sensors, free, df, uptime, journalctl, "
            "systemctl status and --failed, apt and dpkg queries, network status, /proc, /sys and "
            "/var/log). Use them for quick answers and short diagnoses: a few commands at most, then "
            "summarise in plain words. You can also open things for the user: an installed app with "
            "gtk-launch <desktop id> (find the id with ls in /usr/share/applications, "
            "/var/lib/snapd/desktop/applications or ~/.local/share/applications), a web page or a web "
            "search in the default browser with xdg-open and an https:// address (searches: "
            "https://duckduckgo.com/?q=...), and a folder with nautilus --new-window <folder>. "
            "Actions: the only thing that changes the computer is kinobu-do (run kinobu-do help when "
            "unsure): volume, microphone, brightness, night light, Do Not Disturb, dark or light mode, "
            "the theme, Seasons, music (play, pause, next), a page of Settings, Wi-Fi, Bluetooth, "
            "reminders and timers (kinobu-do remind MINUTES TEXT), and status. Do what the user asks "
            "right away and confirm in a few words; ask first only before turning Wi-Fi or Bluetooth "
            "off. The screen: when the user asks about something they are looking at (a message, a "
            "window, what to click), run kinobu-do screenshot and Read the picture it prints, then "
            "explain; never look at the screen unless they ask. The first time, GNOME asks the user "
            "whether apps may take screenshots: tell them to choose Allow if they want you to see it. "
            "You keep nothing about the user between talks and never ask for personal details such as "
            "their name. This computer in detail: if you "
            f"are unsure how something works here, Read {SKILL_DIR}/SKILL.md and then only the guide "
            "you need; never read them for small talk. Anything else is refused. Never pretend you "
            "checked something you did not. Checks that need more care than a few commands but change "
            "nothing (investigating a problem, comparing options, reading long pages): say in one short "
            "sentence that you will look into it in the background and tell them when it is ready, "
            "then end with a last line exactly like [[background: the task, written clearly, with what "
            "you found]]. For real work (fixing or changing the system, "
            "files, code, projects, installing), say in one short sentence that you "
            f"will hand it to {agent_name()}, then end with a last line exactly like "
            "[[delegate: the task, written clearly for the agent, with what you found]]. Do not "
            "delegate small talk or what you can answer yourself. When the user wants to end the "
            "talk or asks you to close (goodbye, that's all, close yourself), say a very short "
            "goodbye and end with a last line exactly like [[close]]. "
            f"Answer in {language}. Your voice now is {'a woman' if female(config['voice']) else 'a man'}'s: "
            f"in languages with grammatical gender, always speak of yourself in the "
            f"{gender_note(config['voice'])} form. Now: {now:%A %d %B %Y, %H:%M %Z}.")


def background_prompt():
    language = LANGUAGE_NAMES.get(LANG, "the user's language")
    return ("You do quick checks for Willow, the voice assistant of Kinobu (Ubuntu 26.04 with GNOME). "
            "You can read the computer with read-only commands, read Kinobu's guides in "
            f"{SKILL_DIR} and use the web; you cannot change anything. Be efficient: the fewest "
            "commands and pages that answer well. Then answer for someone who has never used Linux, "
            f"in {language}, in two to four short sentences that will be read aloud: no Markdown, "
            "lists or code. If the answer needs a change to the system, say what would be needed and "
            "that Willow can hand it to the full agent.")


def muted(target):
    try:
        out = subprocess.run(["wpctl", "get-volume", target], capture_output=True, text=True,
                             timeout=2).stdout
    except (OSError, subprocess.TimeoutExpired):
        return False
    return "[MUTED]" in out


def transcribe(path):
    """Handy turns the recording into text with the model and device chosen in Handy."""
    try:
        out = subprocess.run(["handy", "-f", path, "--json"], capture_output=True, text=True,
                             timeout=120).stdout
    except (OSError, subprocess.TimeoutExpired):
        return None
    for line in reversed(out.splitlines()):
        if line.startswith("{"):
            try:
                return json.loads(line).get("text", "").strip()
            except ValueError:
                pass
    return None


class Listener(threading.Thread):
    """Reads the microphone (16 kHz mono) and cuts it into utterances: speech that rises above
    the room's noise and ends after a short silence."""
    FRAME = 480                                               # 30 ms

    def __init__(self, on_utterance, folder):
        super().__init__(daemon=True)
        self.on_utterance, self.folder = on_utterance, folder
        self.enabled, self.running, self.proc, self.level = False, True, None, 0.0

    def run(self):
        try:
            self.proc = subprocess.Popen(["pw-record", "--rate", "16000", "--channels", "1",
                                          "--format", "s16", "-"],
                                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        except OSError:
            return
        floor, voiced, quiet, speech, before = 200.0, 0, 0, None, []
        while self.running:
            chunk = self.proc.stdout.read(self.FRAME * 2)
            if not chunk:
                break
            frame = array("h", chunk)
            rms = math.sqrt(sum(x * x for x in frame) / max(len(frame), 1))
            self.level = min(rms / 3000, 1.0) if self.enabled else 0.0
            if not self.enabled:
                speech, voiced, quiet, before = None, 0, 0, []
                continue
            start = max(floor * 3.0, 350)
            if speech is None:
                if rms < start:
                    floor = floor * 0.97 + rms * 0.03           # learn the room's noise
                before = (before + [chunk])[-10:]               # keep 0.3 s before the voice
                voiced = voiced + 1 if rms > start else 0
                if voiced >= 3:
                    speech, quiet = list(before), 0
            else:
                speech.append(chunk)
                quiet = quiet + 1 if rms < start * 0.7 else 0
                if quiet >= 30 or len(speech) >= 1000:        # 0.9 s of silence, or 30 s
                    if len(speech) - quiet >= 12:             # at least ~0.35 s of voice
                        self.save(b"".join(speech))
                    speech, voiced, quiet, before = None, 0, 0, []

    def save(self, pcm):
        path = os.path.join(self.folder, f"heard-{time.monotonic_ns()}.wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(16000)
            w.writeframes(pcm)
        self.enabled = False                                  # deaf while answering
        GLib.idle_add(self.on_utterance, path)

    def stop(self):
        self.running = False
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()


class Agent:
    """One headless agent process for the whole talk, at the power chosen in the settings (Haiku at
    low effort by default) with the prompt above and a few narrow tools, so a turn costs a fraction
    of a cent. The answer arrives in pieces (on_delta)."""

    def __init__(self, config, on_delta, on_done, on_tool):
        self.on_delta, self.on_done, self.on_tool, self.proc = on_delta, on_done, on_tool, None
        path = agent_path()
        if not path or os.path.basename(path) != "claude":     # other agents: later
            return
        model, effort = POWERS[config["power"]]
        args = [path, "-p", "--model", model, "--effort", effort,
                "--input-format", "stream-json",
                "--output-format", "stream-json", "--include-partial-messages", "--verbose",
                "--system-prompt", system_prompt(config), "--tools", "Bash,WebSearch,WebFetch,Read",
                "--allowedTools", *ALLOWED, "--add-dir", *READ_DIRS,
                "--strict-mcp-config", "--disable-slash-commands",
                "--setting-sources", "", "--no-session-persistence"]
        try:
            self.proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                         stderr=subprocess.DEVNULL, text=True, bufsize=1,
                                         cwd=os.path.expanduser("~"),
                                         env={**os.environ, "CLAUDE_CODE_DISABLE_AUTO_MEMORY": "1"})
        except OSError:
            return
        threading.Thread(target=self.read, daemon=True).start()

    def ready(self):
        return self.proc is not None and self.proc.poll() is None

    def send(self, text):
        message = {"type": "user", "message": {"role": "user", "content": text}}
        try:
            self.proc.stdin.write(json.dumps(message) + "\n")
            self.proc.stdin.flush()
            return True
        except (OSError, AttributeError, ValueError):
            return False

    def read(self):
        for line in self.proc.stdout:
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if event.get("type") == "stream_event":
                ev = event.get("event", {})
                delta = ev.get("delta", {})
                if ev.get("type") == "content_block_delta" and delta.get("type") == "text_delta":
                    GLib.idle_add(self.on_delta, delta.get("text", ""))
                elif ev.get("type") == "content_block_stop":
                    GLib.idle_add(self.on_delta, "\n")           # text before a tool ends a sentence
            elif event.get("type") == "assistant":
                for block in event.get("message", {}).get("content", []):
                    if block.get("type") == "tool_use":
                        GLib.idle_add(self.on_tool, block.get("name", ""))
            elif event.get("type") == "result":
                GLib.idle_add(self.on_done, bool(event.get("is_error")))
        GLib.idle_add(self.on_done, True)                     # the process ended

    def stop(self):
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()


class Background:
    """A quick check on a stronger model (Sonnet, medium effort), without a window or a saved
    session: it may only look (read-only commands, the guides, the web). on_done gets the spoken
    answer, or None when it failed."""

    def __init__(self, config, task, on_done):
        path = agent_path()
        if not path or os.path.basename(path) != "claude":
            GLib.idle_add(on_done, None)
            return
        args = [path, "-p", task, "--model", config["background_model"],
                "--effort", config["background_effort"], "--output-format", "json",
                "--system-prompt", background_prompt(), "--tools", "Bash,WebSearch,WebFetch,Read",
                "--allowedTools", *LOOKING, "--add-dir", *READ_DIRS,
                "--strict-mcp-config", "--disable-slash-commands",
                "--setting-sources", "", "--no-session-persistence"]

        def work():
            answer = None
            try:
                out = subprocess.run(args, capture_output=True, text=True, timeout=600,
                                     cwd=os.path.expanduser("~"),
                                     env={**os.environ, "CLAUDE_CODE_DISABLE_AUTO_MEMORY": "1"})
                result = json.loads(out.stdout or "{}")
                if not result.get("is_error"):
                    answer = (result.get("result") or "").strip() or None
            except (OSError, subprocess.TimeoutExpired, ValueError):
                pass
            GLib.idle_add(on_done, answer)
        threading.Thread(target=work, daemon=True).start()


class Speaker:
    """Turns sentences into speech in order (the voice-tts.py worker, kept running) and plays
    them one after another. A new turn (stop) drops whatever the last one left queued."""

    def __init__(self, folder, on_play, on_idle):
        self.folder, self.on_play, self.on_idle = folder, on_play, on_idle
        self.texts, self.wavs = queue.Queue(), queue.Queue()
        self.pending, self.turn, self.lock = 0, 0, threading.Lock()
        self.worker = self.player = None
        self.failed = False
        threading.Thread(target=self.synth_loop, daemon=True).start()
        threading.Thread(target=self.play_loop, daemon=True).start()

    def warm(self, engine, voice):
        self.texts.put(("warm", engine, voice, None, self.turn))

    def say(self, text, engine, voice):
        with self.lock:
            self.pending += 1
        self.texts.put(("say", engine, voice, text, self.turn))

    def busy(self):
        with self.lock:
            return self.pending > 0

    def done_one(self, turn):
        with self.lock:
            if turn != self.turn:
                return
            self.pending = max(self.pending - 1, 0)
            idle = self.pending == 0
        if idle:
            GLib.idle_add(self.on_idle)

    def request(self, req):
        if not (self.worker and self.worker.poll() is None):
            self.worker = subprocess.Popen(TTS_ENV, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                           stderr=subprocess.DEVNULL, text=True, bufsize=1)
        self.worker.stdin.write(json.dumps(req) + "\n")
        self.worker.stdin.flush()
        while True:
            line = self.worker.stdout.readline()
            if not line:
                raise OSError("the voice worker stopped")
            answer = json.loads(line)
            if {"out", "error", "warm"} & answer.keys():
                return answer

    def synth_loop(self):
        count = 0
        while True:
            kind, engine, voice, text, turn = self.texts.get()
            if turn != self.turn:
                continue
            try:
                if kind == "warm":
                    self.request({"warm": engine, "voice": voice})
                    continue
                count += 1
                out = os.path.join(self.folder, f"say-{count}.wav")
                answer = self.request({"engine": engine, "voice": voice, "lang": LANG,
                                       "text": text, "out": out})
                if "out" in answer:
                    self.wavs.put((out, turn))
                    continue
                self.failed = True
            except (OSError, ValueError):
                self.failed = True
            if kind == "say":
                self.done_one(turn)

    def play_loop(self):
        while True:
            path, turn = self.wavs.get()
            if turn == self.turn:
                try:
                    GLib.idle_add(self.on_play, envelope(path)[0])
                    self.player = subprocess.Popen(["pw-play", path])
                    self.player.wait()
                except (OSError, wave.Error):
                    pass
            self.done_one(turn)

    def stop(self):
        with self.lock:
            self.turn += 1
            self.pending = 0
        if self.player and self.player.poll() is None:
            self.player.terminate()

    def close(self):
        self.stop()
        if self.worker and self.worker.poll() is None:
            self.worker.terminate()


class VoiceWindow(Adw.ApplicationWindow):
    def __init__(self, app, args):
        super().__init__(application=app, title=t("app"), default_width=520, default_height=620)
        self.add_css_class("kinobu-voice")      # added: css_classes= would drop "background"
        self.args, self.timers, self.player = args, [], None
        self.config = load_config()
        self.continuous = bool(self.config["continuous"])
        self.real, self.busy, self.mic_muted, self.sound_muted, self.syncing = False, False, False, False, False

        header = Adw.HeaderBar(title_widget=Adw.WindowTitle(title=t("app")), css_classes=["flat"],
                               decoration_layout=":close")
        gear = Gtk.Button(icon_name="emblem-system-symbolic", tooltip_text=t("settings").rstrip("…"))
        gear.connect("clicked", lambda *_: self.show_settings())
        header.pack_start(gear)

        self.sphere = Sphere()
        self.dot = Gtk.Label(label="●", css_classes=["kinobu-dot"])
        self.status = Gtk.Label(css_classes=["title-4", "kinobu-status"])
        status = Gtk.Box(spacing=8, halign=Gtk.Align.CENTER)
        status.append(self.dot)
        status.append(self.status)
        self.hint = Gtk.Label(css_classes=["dim-label", "caption"], visible=False, margin_top=2)

        self.talk = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10,
                            margin_start=18, margin_end=18, margin_top=10, margin_bottom=8)
        self.scroll = Gtk.ScrolledWindow(child=self.talk, vexpand=True, margin_top=10,
                                         hscrollbar_policy=Gtk.PolicyType.NEVER)

        self.entry = Gtk.Entry(placeholder_text=t("type"), hexpand=True, css_classes=["kinobu-entry"])
        self.entry.connect("activate", self.on_typed)
        self.mic = Gtk.ToggleButton(icon_name="audio-input-microphone-symbolic", active=True,
                                    valign=Gtk.Align.CENTER,
                                    css_classes=["circular", "suggested-action", "kinobu-mic"])
        self.mic.connect("toggled", self.on_mic)
        bottom = Gtk.Box(spacing=10, margin_start=16, margin_end=16, margin_bottom=16, margin_top=6)
        bottom.append(self.entry)
        bottom.append(self.mic)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        for part in (self.sphere, status, self.hint, self.scroll, bottom):
            box.append(part)
        view = Adw.ToolbarView(content=box)
        view.add_top_bar(header)
        self.set_content(view)

        keys = Gtk.EventControllerKey(propagation_phase=Gtk.PropagationPhase.CAPTURE)
        keys.connect("key-pressed", self.on_key)
        self.add_controller(keys)
        self.connect("close-request", self.on_close)
        touch = Gtk.GestureClick()
        touch.connect("released", lambda *_: self.listen_now())
        self.sphere.add_controller(touch)
        self.set_state("listening")

    # ---- states -------------------------------------------------------------------------
    def set_state(self, state):
        self.sphere.state, self.sphere.level = state, 0.0
        self.status.set_label(t(state))
        if state in ("paused", "muted"):
            self.dot.add_css_class("off")
        else:
            self.dot.remove_css_class("off")
        self.hint.set_label(t("hint_muted" if state == "muted" else "hint_paused"))
        self.hint.set_visible(state in ("paused", "muted"))
        if self.real:
            self.listener.enabled = state == "listening" and not self.mic_muted

    def after_answer(self):
        if self.real and self.mic_muted:
            self.set_state("muted")
        else:
            self.set_state("listening" if self.continuous and self.mic.get_active() else "paused")
        self.last_activity = time.monotonic()

    def later(self, seconds, func):
        self.timers.append(GLib.timeout_add(int(seconds * 1000), lambda: func() and False))

    def cancel(self):
        for timer in self.timers:
            GLib.source_remove(timer)
        self.timers.clear()
        self.stop_audio()

    # ---- conversation -------------------------------------------------------------------
    def bubble(self, who, text, mine):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3,
                      css_classes=["kinobu-bubble", "me" if mine else "them"],
                      halign=Gtk.Align.END if mine else Gtk.Align.START)
        box.append(Gtk.Label(label=who.upper(), xalign=0, css_classes=["kinobu-who"]))
        label = Gtk.Label(label=text, xalign=0, wrap=True, max_width_chars=40, selectable=True)
        box.append(label)
        self.talk.append(box)
        self.later(0.05, self.scroll_down)
        return label

    def card(self, agent, folder, task, on_open=None):
        row = Gtk.Box(spacing=12, css_classes=["card", "kinobu-card"])
        row.append(Gtk.Image(icon_name="utilities-terminal-symbolic", pixel_size=28,
                             css_classes=["accent"], valign=Gtk.Align.CENTER))
        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4, hexpand=True)
        text.append(Gtk.Label(label=agent, xalign=0, css_classes=["heading"]))
        chip = Gtk.Box(spacing=6, halign=Gtk.Align.START, css_classes=["kinobu-chip"])
        chip.append(Gtk.Image(icon_name="folder-symbolic"))
        chip.append(Gtk.Label(label=folder))
        text.append(chip)
        text.append(Gtk.Label(label=task, xalign=0, wrap=True, css_classes=["dim-label"]))
        row.append(text)
        button = Gtk.Button(label=t("open_agent" if on_open else "open"), valign=Gtk.Align.CENTER,
                            css_classes=["pill", "suggested-action"])
        if on_open:
            button.connect("clicked", lambda *_: on_open(task))
        row.append(button)
        self.talk.append(row)
        self.later(0.05, self.scroll_down)

    def scroll_down(self):
        adj = self.scroll.get_vadjustment()
        adj.set_value(adj.get_upper() - adj.get_page_size())

    def say(self, text, audio=None, done=None):
        """Shows the answer word by word while the orb follows the voice (or a fake one)."""
        self.set_state("speaking")
        label, words = self.bubble(t("app"), "", False), text.split()
        if audio:
            env, length = envelope(audio)
            self.player = subprocess.Popen(["pw-play", audio])
        else:
            length = len(words) * 0.32
            env = [abs(math.sin(i / 3)) * random.uniform(0.5, 1) for i in range(int(length / 0.02))]
        start = time.monotonic()

        def step():
            if self.sphere.state not in ("speaking", "delegating"):
                return False
            pos = time.monotonic() - start
            if pos >= length:
                label.set_label(text)
                self.player = None
                (done or self.after_answer)()
                return False
            self.sphere.level = env[min(int(pos / 0.02), len(env) - 1)]
            label.set_label(" ".join(words[:max(1, int(len(words) * pos / length) + 1)]))
            return True
        self.timers.append(GLib.timeout_add(20, step))

    def stop_audio(self):
        if self.player and self.player.poll() is None:
            self.player.terminate()
        self.player = None

    # ---- real mode ----------------------------------------------------------------------
    def start_engine(self):
        self.real, self.tmp = True, tempfile.mkdtemp(prefix="kinobu-voice-")
        self.env, self.env_start, self.answer, self.spoken = [], 0.0, "", 0
        self.answer_label, self.turn_done, self.last_activity = None, True, time.monotonic()
        self.listener = Listener(self.on_utterance, self.tmp)
        self.agent = Agent(self.config, self.on_delta, self.on_done, self.on_tool)
        self.agent_voice = self.config["voice"]
        self.speaker = Speaker(self.tmp, self.on_play, self.on_spoken)
        self.speaker.warm(self.config["engine"], self.config["voice"])
        self.listener.start()
        GLib.timeout_add(20, self.animate)
        GLib.timeout_add(500, self.poll_system)
        self.poll_system()
        if not self.agent.ready():
            self.bubble(t("app"), t("no_agent"), False)
        self.after_answer()

    def animate(self):
        if self.sphere.state == "listening":
            self.sphere.level = self.listener.level
        elif self.sphere.state == "speaking" and self.env:
            i = int((time.monotonic() - self.env_start) / 0.02)
            self.sphere.level = self.env[i] if i < len(self.env) else 0.0
        return True

    def poll_system(self):
        mic, self.sound_muted = muted("@DEFAULT_AUDIO_SOURCE@"), muted("@DEFAULT_AUDIO_SINK@")
        if mic != self.mic_muted or self.mic.get_active() == mic:
            self.mic_muted, self.syncing = mic, True
            self.mic.set_active(not mic)
            self.syncing = False
            if not self.busy:
                self.after_answer()
        idle = time.monotonic() - self.last_activity
        if self.sphere.state == "listening" and idle > float(self.config["idle_close"]):
            self.close()
            return False
        return True

    def listen_now(self):
        if self.real and not self.busy and not self.mic_muted:
            self.set_state("listening")
            self.last_activity = time.monotonic()

    def on_utterance(self, path):
        if self.busy:
            return
        self.busy, self.last_activity = True, time.monotonic()
        self.set_state("transcribing")

        def work():
            text = transcribe(path)
            try:
                os.remove(path)
            except OSError:
                pass
            GLib.idle_add(self.on_heard, text)
        threading.Thread(target=work, daemon=True).start()

    def on_heard(self, text):
        if not text:
            self.busy = False
            self.after_answer()
            return
        self.busy = False
        self.ask(text)

    def ask(self, text):
        self.speaker.stop()
        self.bubble(t("you"), text, True)
        message = text
        if gender_note(self.config["voice"]) != gender_note(self.agent_voice):
            message = (f"(Note from the app: the voice changed; from now on speak of yourself in the "
                       f"{gender_note(self.config['voice'])} form.)\n{text}")
            self.agent_voice = self.config["voice"]
        if not self.agent.ready() or not self.agent.send(message):
            self.bubble(t("app"), t("no_agent"), False)
            self.after_answer()
            return
        self.busy, self.answer, self.spoken, self.answer_label, self.turn_done = True, "", 0, None, False
        self.set_state("thinking")

    def visible(self):
        """The answer without the [[delegate: …]] or [[background: …]] line, which is for the app."""
        cut = self.answer.find("[[")
        return (self.answer if cut < 0 else self.answer[:cut]).strip()

    def speak_ready(self, final):
        text = self.visible()
        rest = text[self.spoken:]
        while True:
            m = SENTENCE.match(rest)
            if not m or (not final and not m.group(2)):          # the last one may still grow
                break
            self.queue_sentence(m.group(1))
            self.spoken += m.end()
            rest = text[self.spoken:]
        if final and rest.strip():
            self.queue_sentence(rest)
            self.spoken = len(text)

    def queue_sentence(self, sentence):
        sentence = sentence.strip()
        if sentence and not self.sound_muted and self.config["engine"] in ENGINES:
            self.speaker.say(sentence, self.config["engine"], self.config["voice"])

    def on_delta(self, piece):
        if not self.busy or self.turn_done:
            return
        if self.answer_label is None:
            self.answer_label = self.bubble(t("app"), "", False)
            self.set_state("speaking")
        self.answer += piece
        self.answer_label.set_label(self.visible())
        self.speak_ready(final=False)
        self.later(0.02, self.scroll_down)

    def on_done(self, error):
        if not self.busy or self.turn_done:
            return
        self.turn_done = True
        if error and not self.answer:
            self.bubble(t("app"), t("agent_error"), False)
        self.speak_ready(final=True)
        if self.answer_label is not None:
            self.answer_label.set_label(self.visible())
        self.closing = bool(CLOSE.search(self.answer))
        task = DELEGATE.search(self.answer)
        if task:
            self.card(agent_name(), "~", task.group(1).strip(), self.launch_agent)
        job = BACKGROUND.search(self.answer)
        if job and not getattr(self, "background_busy", False):
            self.background_busy = True
            Background(self.config, job.group(1).strip(), self.on_background)
        if self.sound_muted and self.answer:
            self.hint.set_label(t("sound_off"))
            self.hint.set_visible(True)
        elif self.speaker.failed:
            self.hint.set_label(t("no_voice"))
            self.hint.set_visible(True)
        if not self.speaker.busy():
            self.finish_turn()

    def on_tool(self, name):
        if self.busy and not self.turn_done:
            self.status.set_label(t("using_web" if name.startswith("Web") else
                                    "using_read" if name == "Read" else "using_bash"))

    def on_background(self, answer):
        """A background check finished: a notice (the window may be closed by now), and if the
        window is still open, the answer in the talk, spoken."""
        self.background_busy = False
        title = t("background_done") if answer else t("background_failed")
        try:
            subprocess.Popen(["notify-send", "-a", t("app"), "-i", APP_ID, title, (answer or "")[:400]])
        except OSError:
            pass
        if answer and self.get_visible():
            self.bubble(t("app"), answer, False)
            if not self.sound_muted:
                for sentence in re.split(r"(?<=[.!?])\s+", answer):
                    self.queue_sentence(sentence)

    def on_play(self, env):
        self.env, self.env_start = env, time.monotonic()

    def on_spoken(self):
        if self.busy and self.turn_done:
            self.finish_turn()

    def finish_turn(self):
        self.busy, self.env = False, []
        if getattr(self, "restart_pending", False):
            self.restart_agent()
        if getattr(self, "closing", False):                 # "goodbye": close once it has spoken
            self.later(0.8, self.close)
            return
        self.after_answer()

    def launch_agent(self, task):
        """Opens your agent in a terminal, in your home folder, with the task already typed."""
        path = agent_path()
        if not path:
            return
        command = f"{shlex.quote(path)} {shlex.quote(task)}"
        home = os.path.expanduser("~")
        try:
            subprocess.Popen(["ptyxis", "--new-window", "-x", command], cwd=home)
        except OSError:
            subprocess.Popen(["gnome-terminal", "--", "bash", "-lc", command], cwd=home)

    def on_close(self, *_):
        self.stop_audio()
        if self.real:
            self.listener.stop()
            self.agent.stop()
            self.speaker.close()
            shutil.rmtree(self.tmp, ignore_errors=True)       # only this window's own temp folder
        return False

    # ---- demo ---------------------------------------------------------------------------
    def fake_voice(self, seconds):
        """The user 'speaks' for a while: the orb beats as a microphone would make it."""
        end = time.monotonic() + seconds

        def step():
            if time.monotonic() >= end or self.sphere.state != "listening":
                self.sphere.level = 0
                return False
            self.sphere.level = random.uniform(0.3, 1)
            return True
        self.timers.append(GLib.timeout_add(90, step))

    def start_demo(self):
        self.cancel()
        child = self.talk.get_first_child()
        while child:
            self.talk.remove(child)
            child = self.talk.get_first_child()
        self.mic.set_active(True)
        self.set_state("listening")
        self.later(0.8, lambda: self.fake_voice(2.0))
        self.later(3.6, lambda: self.set_state("transcribing"))
        self.later(4.3, lambda: self.bubble(t("you"), t("q1"), True))
        self.later(4.4, lambda: self.set_state("thinking"))
        self.later(6.2, lambda: self.say(t("a1"), sample(self.config["engine"], self.config["voice"]),
                                         self.demo_second))

    def demo_second(self):
        self.after_answer()
        if self.sphere.state != "listening":
            return
        self.later(0.6, lambda: self.fake_voice(1.4))
        self.later(2.8, lambda: self.set_state("transcribing"))
        self.later(3.4, lambda: self.bubble(t("you"), t("q2"), True))
        self.later(3.5, lambda: self.set_state("thinking"))
        self.later(4.8, lambda: self.set_state("delegating"))
        self.later(4.9, lambda: self.card(t("agent"), t("folder"), t("task")))
        self.later(5.4, lambda: self.say(t("a2")))

    # ---- input --------------------------------------------------------------------------
    def on_typed(self, entry):
        text = entry.get_text().strip()
        if not text:
            return
        if self.real:
            if not self.busy:
                entry.set_text("")
                self.ask(text)
            return
        entry.set_text("")
        self.cancel()
        self.bubble(t("you"), text, True)
        self.set_state("thinking")
        self.later(1.0, lambda: self.say(t("typed")))

    def on_mic(self, button):
        button.set_icon_name("audio-input-microphone-symbolic" if button.get_active()
                             else "microphone-disabled-symbolic")
        if self.real:
            if not self.syncing:                       # the button mutes the system's microphone
                self.mic_muted = not button.get_active()
                subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "1" if self.mic_muted else "0"])
                if not self.busy:
                    self.after_answer()
            return
        if button.get_active():
            self.set_state("listening")
        else:
            self.cancel()
            self.set_state("paused")

    def on_key(self, _ctl, keyval, _code, mods):
        if keyval == Gdk.KEY_Escape:
            self.close()
            return True
        if keyval in (Gdk.KEY_m, Gdk.KEY_M) and mods & Gdk.ModifierType.CONTROL_MASK:
            self.mic.set_active(not self.mic.get_active())
            return True
        return False

    def restart_agent(self):
        """A new power or manner: a new agent from the next question on (the talk starts afresh)."""
        if not self.real:
            return
        if self.busy:                                   # after the answer in progress
            self.restart_pending = True
            return
        self.restart_pending = False
        self.agent.stop()
        self.agent = Agent(self.config, self.on_delta, self.on_done, self.on_tool)
        self.hint.set_label(t("restarted"))
        self.hint.set_visible(True)

    # ---- settings -----------------------------------------------------------------------
    def show_settings(self):
        page = Adw.PreferencesPage()
        voices = Adw.PreferencesGroup(title=t("voice_group"))
        engine_ids = list(ENGINES)
        engine_row = Adw.ComboRow(title=t("engine"),
                                  model=Gtk.StringList.new([ENGINES[e][0] for e in engine_ids]))
        voice_row = Adw.ComboRow(title=t("voice"))
        listen = Gtk.Button(icon_name="media-playback-start-symbolic", valign=Gtk.Align.CENTER,
                            tooltip_text=t("try"), css_classes=["flat", "circular"])
        voice_row.add_suffix(listen)
        voices.add(engine_row)
        voices.add(voice_row)
        talk = Adw.PreferencesGroup(title=t("talk_group"))
        keep = Adw.SwitchRow(title=t("continuous"), active=self.continuous)
        talk.add(keep)
        power_ids = list(POWERS)
        power_row = Adw.ComboRow(title=t("power"), model=Gtk.StringList.new([t(f"power_{p}") for p in power_ids]))
        power_row.set_selected(power_ids.index(self.config["power"]))
        power_row.set_subtitle(t(f"power_{self.config['power']}_note"))
        talk.add(power_row)
        manner = Adw.EntryRow(title=t("manner"), text=self.config.get("persona", ""), show_apply_button=True)
        talk.add(manner)
        page.add(voices)
        page.add(talk)

        def power_changed(*_):
            power = power_ids[power_row.get_selected()]
            power_row.set_subtitle(t(f"power_{power}_note"))
            if power != self.config["power"]:
                self.config["power"] = power
                save_config(self.config)
                self.restart_agent()

        def manner_changed(*_):
            self.config["persona"] = manner.get_text().strip()[:500]
            save_config(self.config)
            self.restart_agent()

        def fill_voices(*_):
            engine = engine_ids[engine_row.get_selected()]
            engine_row.set_subtitle(t(ENGINES[engine][1]))
            options = voices_for(engine)
            voice_row.set_model(Gtk.StringList.new([label for _v, label in options]))
            ids = [v for v, _label in options]
            voice_row.set_selected(ids.index(self.config["voice"]) if self.config["voice"] in ids else 0)

        def changed(*_):
            engine = engine_ids[engine_row.get_selected()]
            options = voices_for(engine)
            self.config["engine"] = engine
            self.config["voice"] = options[min(voice_row.get_selected(), len(options) - 1)][0]
            listen.set_sensitive(self.real or bool(sample(engine, self.config["voice"])))
            save_config(self.config)
            if self.real:
                self.speaker.warm(engine, self.config["voice"])

        def play(*_):
            if self.real:                    # said live, in the desktop language, with this voice
                self.speaker.stop()
                self.speaker.say(t("sample"), self.config["engine"], self.config["voice"])
                return
            path = sample(self.config["engine"], self.config["voice"])
            if path:
                self.stop_audio()
                self.player = subprocess.Popen(["pw-play", path])

        def keep_listening(*_):
            self.continuous = self.config["continuous"] = keep.get_active()
            save_config(self.config)

        engine_row.set_selected(engine_ids.index(self.config["engine"]) if self.config["engine"] in ENGINES else 0)
        fill_voices()
        changed()
        engine_row.connect("notify::selected", lambda *_: (fill_voices(), changed()))
        voice_row.connect("notify::selected", changed)
        listen.connect("clicked", play)
        keep.connect("notify::active", keep_listening)
        power_row.connect("notify::selected", power_changed)
        manner.connect("apply", manner_changed)
        dialog = Adw.PreferencesDialog(title=t("settings").rstrip("…"), content_width=540)
        dialog.add(page)
        dialog.present(self)


def prepare():
    """Run by kinobu.sh after the downloads: lets uv install the voice worker's packages and makes
    the Qwen3-TTS reference voices (qwen-ref-<voice>-<lang>.wav) from Kokoro, in every language."""
    jobs = [{"warm": "kokoro"}]
    if os.path.isdir(LLAMA):
        for lang, refs in QWEN_REFS.items():
            text = texts("voice", lang).get("ref_text", "")
            for voice, kokoro_voice in refs.items():
                out = os.path.join(MODELS, f"qwen-ref-{voice}-{lang}.wav")
                if not os.path.isfile(out):
                    jobs.append({"engine": "kokoro", "voice": kokoro_voice, "lang": lang,
                                 "text": text, "out": out})
    try:
        done = subprocess.run(TTS_ENV, input="".join(json.dumps(j) + "\n" for j in jobs),
                              capture_output=True, text=True, timeout=3600)
    except (OSError, subprocess.TimeoutExpired) as e:
        print(f"voice worker: {e}", file=sys.stderr)
        return 1
    answers = [json.loads(line) for line in done.stdout.splitlines() if line.startswith("{")]
    errors = [a["error"] for a in answers if "error" in a]
    for error in errors:
        print(f"voice worker: {error}", file=sys.stderr)
    made = sum("out" in a for a in answers)
    print(f"voice worker ready; {made} Qwen3-TTS reference voices made")
    return 1 if errors or done.returncode or len(answers) < len(jobs) else 0


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--demo", action="store_true", help="play the states with sample texts")
    p.add_argument("--prepare", action="store_true", help="set up the voice worker (kinobu.sh)")
    args = p.parse_args()
    if args.prepare:
        return prepare()
    app = Adw.Application(application_id=APP_ID)

    def activate(app):
        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        win = app.get_active_window()
        if win is None:
            win = VoiceWindow(app, args)
            win.present()
            win.set_focus(None)
            if args.demo:
                win.start_demo()
            else:
                win.start_engine()
        else:
            win.present()
    app.connect("activate", activate)
    return app.run([])


if __name__ == "__main__":
    sys.exit(main())
