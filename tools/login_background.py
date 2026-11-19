#!/usr/bin/env python3
"""Draws the background of the login screen (GDM): a dark gradient in Kinobu's colours with the
wordmark large in the middle, blurred and dimmed, so it reads as Kinobu without getting in the way
of the password. Writes files/branding/login-background.jpg (2560 × 1440); the setup puts it in
the login screen's theme (files/apps/kinobu-login-screen)."""
import math
import pathlib

import gi

gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf  # noqa: E402

W, H = 2560, 1440
CENTRE, EDGE = (0x26, 0x30, 0x2C), (0x0C, 0x0F, 0x10)   # Kinobu's Night, a touch of forest in the middle
LOGO_WIDTH, BLUR, ALPHA = 0.56, 4, 52                  # share of the width, blur steps, opacity (0-255)


def gradient(w, h):
    """A soft radial gradient, drawn small and scaled up (the scaling smooths it)."""
    sw, sh = 96, 54
    data = bytearray()
    for y in range(sh):
        for x in range(sw):
            dx, dy = (x - sw / 2) / (sw / 2), (y - sh * 0.46) / (sh / 2)
            t = min(1.0, math.sqrt(dx * dx * 0.55 + dy * dy * 0.9))
            t = t * t * (3 - 2 * t)   # smoothstep
            data += bytes(round(c + (e - c) * t) for c, e in zip(CENTRE, EDGE))
    small = GdkPixbuf.Pixbuf.new_from_bytes(GdkPixbuf.Pixbuf.new_from_data(
        bytes(data), GdkPixbuf.Colorspace.RGB, False, 8, sw, sh, sw * 3).read_pixel_bytes(),
        GdkPixbuf.Colorspace.RGB, False, 8, sw, sh, sw * 3)
    return small.scale_simple(w, h, GdkPixbuf.InterpType.BILINEAR)


def blurred_logo(svg, width):
    """The wordmark at a width, blurred: halved BLUR times, then doubled back step by step (each
    smooth step softens it like a small Gaussian blur)."""
    logo = GdkPixbuf.Pixbuf.new_from_file_at_scale(str(svg), width, -1, True)
    pad = width // 10   # room for the blur to fade out, instead of a cut at the drawing's edge
    sharp = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, True, 8, logo.get_width() + 2 * pad,
                                 logo.get_height() + 2 * pad)
    sharp.fill(0x00000000)
    logo.copy_area(0, 0, logo.get_width(), logo.get_height(), sharp, pad, pad)
    sizes = [(sharp.get_width(), sharp.get_height())]
    img = sharp
    for _ in range(BLUR):
        w, h = max(1, img.get_width() // 2), max(1, img.get_height() // 2)
        img = img.scale_simple(w, h, GdkPixbuf.InterpType.BILINEAR)
        sizes.append((w, h))
    for w, h in reversed(sizes[:-1]):
        img = img.scale_simple(w, h, GdkPixbuf.InterpType.BILINEAR)
    return img


if __name__ == "__main__":
    root = pathlib.Path(__file__).resolve().parent.parent
    background = gradient(W, H)
    logo = blurred_logo(root / "assets" / "kinobu-dark.svg", int(W * LOGO_WIDTH))
    x, y = (W - logo.get_width()) // 2, (H - logo.get_height()) // 2
    logo.composite(background, x, y, logo.get_width(), logo.get_height(), x, y, 1, 1,
                   GdkPixbuf.InterpType.BILINEAR, ALPHA)
    background.savev(str(root / "files" / "branding" / "login-background.jpg"), "jpeg", ["quality"], ["88"])
