#!/usr/bin/env python3
"""Draws Kinobu's login sound from code (no recordings, so no rights to clear): a short rustle of
leaves and warm notes, mixed with a small reverb, in stereo at 48 kHz. Only the standard library.

    python3 tools/login_sound.py --variant leaves --out sound.wav
    python3 tools/login_sound.py --all DIR        # every variant, to listen to them
    python3 tools/login_sound.py --kinobu         # Kinobu's two: files/branding/sounds/{login,logout}.oga

Kinobu's sounds (chosen on 2026-11-22): chord-tinkle-celesta to log in, chord-close-amen-4 to
log out. OGG Vorbis through GStreamer (gst-launch-1.0 with vorbisenc).

Variants: chord (a soft chord growing out of silence, a gentle breath at its end) and its other
endings chord-plain, chord-bell, chord-wood, chord-shimmer, chord-bass, chord-rise, chord-tinkle,
chord-tinkle-celesta (Kinobu's login), chord-tinkle-low, chord-close,
chord-close-short, chord-close-<minor|amen|low>-<4|2> (for logging out); leaves
(a rustle with three wooden notes rising), breeze (a breeze with wind chimes)."""
import argparse
import math
import os
import random
import struct
import sys
import wave

RATE = 48000


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def add(track, sound, start, gain=1.0):
    """Mixes sound into track from start (seconds)."""
    first = int(start * RATE)
    for i, value in enumerate(sound):
        if first + i < len(track):
            track[first + i] += value * gain


def note(freq, seconds, partials, attack=0.004, decay=3.0):
    """A struck note: partials (ratio, level, decay speed) under a fast attack."""
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        rise = min(1.0, t / attack)
        out.append(rise * sum(level * math.exp(-t * decay * speed) * math.sin(2 * math.pi * freq * ratio * t)
                              for ratio, level, speed in partials))
    return out


MARIMBA = [(1.0, 1.0, 1.0), (3.98, 0.22, 3.2), (9.9, 0.05, 6.0)]          # wooden bar
SOFT = [(1.0, 1.0, 1.0), (2.0, 0.10, 2.4), (3.0, 0.03, 4.0)]            # a soft mallet: nearly pure
CELESTA = [(1.0, 1.0, 0.8), (4.0, 0.06, 2.0)]                            # a quiet celesta
CHIME = [(1.0, 0.8, 0.6), (2.76, 0.35, 1.1), (5.4, 0.18, 1.8), (8.93, 0.08, 2.6)]   # small metal tube


def pad(freqs, seconds, attack=0.35, fade=1.6):
    """A soft chord that swells and fades, slightly detuned so it breathes. The swell follows an
    eased curve (slow at first), so the sound grows out of silence instead of starting at once."""
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        rise = min(1.0, t / attack)
        level = rise * rise * (3 - 2 * rise) * math.exp(-max(0.0, t - attack) * fade)
        out.append(level * sum(math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 1.003 * t)
                               for f in freqs) / len(freqs))
    return out


def biquad(signal, kind, freq, q=0.7):
    """A band-pass or low-pass filter (RBJ's cookbook)."""
    w = 2 * math.pi * freq / RATE
    alpha = math.sin(w) / (2 * q)
    cos = math.cos(w)
    if kind == "band":
        b = (alpha, 0.0, -alpha)
    else:
        b = ((1 - cos) / 2, 1 - cos, (1 - cos) / 2)
    a0, a1, a2 = 1 + alpha, -2 * cos, 1 - alpha
    b = [x / a0 for x in b]
    a1, a2 = a1 / a0, a2 / a0
    out, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for x in signal:
        y = b[0] * x + b[1] * x1 + b[2] * x2 - a1 * y1 - a2 * y2
        out.append(y)
        x1, x2, y1, y2 = x, x1, y, y1
    return out


def leaves(seconds, seed, bright=3200):
    """Leaves moving: filtered noise in small gusts, with the crackle of leaf against leaf."""
    rnd = random.Random(seed)
    noise = [rnd.uniform(-1, 1) for _ in range(int(seconds * RATE))]
    crackle = [rnd.uniform(-1, 1) if rnd.random() < 0.004 else 0.0 for _ in noise]
    body = biquad(biquad(noise, "band", bright, 0.6), "low", bright * 2)
    snaps = biquad(crackle, "band", bright * 1.6, 1.2)
    out = []
    for i, (v, c) in enumerate(zip(body, snaps)):
        t = i / RATE
        swell = math.sin(math.pi * min(1.0, t / seconds)) ** 1.5
        gust = 0.6 + 0.4 * math.sin(2 * math.pi * 2.3 * t + 1.3) * math.sin(2 * math.pi * 0.9 * t)
        out.append(swell * (v * gust * 1.6 + c * 2.5))
    return out


def breeze(seconds, seed, cutoff=900):
    """A soft breeze, like a gentle breath: low noise that swells and leaves."""
    rnd = random.Random(seed)
    noise = [rnd.uniform(-1, 1) for _ in range(int(seconds * RATE))]
    body = biquad(biquad(noise, "low", cutoff), "low", cutoff * 0.66)
    return [v * math.sin(math.pi * min(1.0, i / RATE / seconds)) ** 2 * 3 for i, v in enumerate(body)]


def reverb(signal, delays, mix=0.25):
    """A small room: four feedback combs and two all-pass filters (Schroeder)."""
    wet = [0.0] * len(signal)
    for delay, feedback in delays:
        buf = [0.0] * int(delay * RATE)
        pos = 0
        for i, x in enumerate(signal):
            y = buf[pos]
            buf[pos] = x + y * feedback
            pos = (pos + 1) % len(buf)
            wet[i] += y / len(delays)
    for delay in (0.005, 0.0017):
        buf = [0.0] * int(delay * RATE)
        pos, out = 0, []
        for x in wet:
            y = buf[pos]
            buf[pos] = x + y * 0.5
            out.append(y - 0.5 * x)
            pos = (pos + 1) % len(buf)
        wet = out
    return [x * (1 - mix) + w * mix * 3 for x, w in zip(signal, wet)]


def stereo(mono, spread=0.0007):
    """Left and right a little apart (a few samples of delay and its own room each)."""
    shift = int(spread * RATE)
    left = reverb(mono, [(0.0297, 0.78), (0.0371, 0.76), (0.0411, 0.74), (0.0437, 0.72)])
    right = reverb([0.0] * shift + mono[:len(mono) - shift],
                   [(0.0311, 0.78), (0.0359, 0.76), (0.0423, 0.74), (0.0449, 0.72)])
    return left, right


def variant(name):
    track = silence(2.6)
    if name == "leaves":
        add(track, leaves(1.9, 7), 0.0, 0.10)
        for i, freq in enumerate((329.63, 493.88, 659.25)):        # E4, B4, E5
            add(track, note(freq, 1.6, MARIMBA, decay=2.2), 0.28 + i * 0.13, 0.32)
    elif name == "breeze":
        add(track, breeze(2.2, 11), 0.0, 0.09)
        for start, freq in ((0.25, 880.0), (0.45, 1318.5), (0.72, 1108.7), (1.0, 1760.0)):   # A5, E6, C#6, A6
            add(track, note(freq, 1.6, CHIME, decay=1.4), start, 0.16)
    elif name.startswith("chord"):   # a chord growing out of silence, then its ending
        ending = name[len("chord"):].lstrip("-") or "breath"
        # The login's chord is D4 A4 D5 E5. The goodbyes' are a little darker, each in its own way;
        # chord-close-<chord>-4 or -2: four notes (down, up, down) or two (down) over it
        chords = {"minor": (293.66, 440.0, 587.33, 698.46),     # D minor: F5 instead of E5
                  "amen": (196.0, 293.66, 392.0, 440.0),        # G add9 under it: a settling "amen"
                  "low": (220.0, 329.63, 440.0, 493.88)}        # the same chord a fourth lower
        melodies = {"minor": ((1174.66, 698.46, 880.0, 587.33), (880.0, 587.33)),      # D6 F5 A5 D5 · A5 D5
                    "amen": ((1174.66, 783.99, 880.0, 587.33), (880.0, 587.33)),       # D6 G5 A5 D5 · A5 D5
                    "low": ((880.0, 554.37, 659.25, 440.0), (659.25, 440.0))}          # A5 C#5 E5 A4 · E5 A4
        parts = ending.split("-")
        dark = parts[1] if parts[0] == "close" and len(parts) == 3 and parts[1] in chords else ""
        if dark:
            add(track, pad(chords[dark], 2.3, attack=0.7, fade=2.0), 0.05, 0.38)
            notes = melodies[dark][0 if parts[2] == "4" else 1]
            for i, freq in enumerate(notes):
                add(track, note(freq, 1.3, CELESTA, attack=0.012, decay=2.2), 0.75 + i * 0.17, 0.09)
            ending = "done"
        else:
            add(track, pad((293.66, 440.0, 587.33, 659.25), 2.3, attack=0.7), 0.05, 0.42)
        if ending == "breath":     # a gentle breath
            add(track, breeze(1.4, 5, cutoff=700), 1.05, 0.06)
        elif ending == "bell":     # two small bells, high and soft
            add(track, note(1174.66, 1.4, CHIME, decay=1.2), 0.95, 0.07)       # D6
            add(track, note(1760.0, 1.3, CHIME, decay=1.3), 1.15, 0.05)        # A6
        elif ending == "wood":     # one warm wooden note
            add(track, note(587.33, 1.4, MARIMBA, decay=1.8), 0.95, 0.20)      # D5
        elif ending == "shimmer":  # the chord an octave up, very soft, as a glow
            add(track, pad((1174.66, 1318.5), 1.5, attack=0.4), 0.9, 0.10)     # D6, E6
        elif ending == "bass":     # a deep, warm note under the chord
            add(track, pad((146.83,), 1.9, attack=0.5), 0.35, 0.30)            # D3
        elif ending == "rise":     # three soft notes climbing over it
            for i, freq in enumerate((587.33, 739.99, 880.0)):                 # D5, F#5, A5
                add(track, note(freq, 1.2, MARIMBA, decay=2.4), 0.8 + i * 0.16, 0.12)
        elif ending in ("close", "close-short"):   # the first goodbyes, on the login's chord
            melody = (1174.66, 739.99, 880.0, 587.33) if ending == "close" else (880.0, 587.33)
            for i, freq in enumerate(melody):
                add(track, note(freq, 1.3, CELESTA, attack=0.012, decay=2.2), 0.75 + i * 0.17, 0.09)
        elif ending.startswith("tinkle"):   # four soft notes: up, down and up again, at the chord's level
            melody, timbre, step = (587.33, 880.0, 739.99, 1174.66), SOFT, 0.17          # D5 A5 F#5 D6
            if ending == "tinkle-celesta":
                timbre = CELESTA
            elif ending == "tinkle-low":
                melody = (440.0, 659.25, 587.33, 880.0)                                 # A4 E5 D5 A5
            for i, freq in enumerate(melody):
                add(track, note(freq, 1.3, timbre, attack=0.012, decay=2.2), 0.75 + i * step, 0.09)
        elif ending not in ("plain", "done"):    # plain: the chord alone; done: already drawn
            raise SystemExit(f"Unknown ending: {ending}")
    else:
        raise SystemExit(f"Unknown variant: {name}")
    left, right = stereo(track)
    peak = max(1e-9, max(abs(v) for v in left + right))
    gain = 0.33 / peak                                            # about -9.6 dB at the loudest: soft
    fade = int(0.25 * RATE)
    for i in range(fade):                                         # a clean end
        k = 1 - i / fade
        left[-fade + i] *= k
        right[-fade + i] *= k
    return [v * gain for v in left], [v * gain for v in right]


def write(path, left, right):
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<hh", int(max(-1, min(1, a)) * 32767),
                                           int(max(-1, min(1, b)) * 32767)) for a, b in zip(left, right)))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--variant", default="chord-tinkle-celesta")
    p.add_argument("--out")
    p.add_argument("--all", metavar="DIR", help="write every variant into DIR")
    p.add_argument("--kinobu", action="store_true", help="write Kinobu's login and logout sounds")
    args = p.parse_args()
    if args.kinobu:
        import subprocess
        import tempfile
        out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "files", "branding", "sounds")
        os.makedirs(out, exist_ok=True)
        for name, chosen in (("login", "chord-tinkle-celesta"), ("logout", "chord-close-amen-4")):
            with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
                write(tmp.name, *variant(chosen))
                subprocess.run(["gst-launch-1.0", "-q", "filesrc", f"location={tmp.name}", "!", "wavparse", "!",
                                "audioconvert", "!", "vorbisenc", "quality=0.5", "!", "oggmux", "!", "filesink",
                                f"location={os.path.join(out, name + '.oga')}"], check=True)
        return 0
    if args.all:
        os.makedirs(args.all, exist_ok=True)
        for name in ("leaves", "breeze", "chord"):
            write(os.path.join(args.all, f"{name}.wav"), *variant(name))
        return 0
    if not args.out:
        p.error("--out FILE or --all DIR")
    write(args.out, *variant(args.variant))
    return 0


if __name__ == "__main__":
    sys.exit(main())
