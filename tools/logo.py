#!/usr/bin/env python3
"""Draws Kinobu's logo as SVG into assets/: the rings of a trunk seen from above. A thick outer
ring, thinner inner rings and the centre in the accent colour; each ring has a notch, turned by
the golden angle from the one before. logo.svg is the full logo (32 px and larger), logo-small.svg
the reduced one for small icons; the -light files are for light backgrounds. show-apps-symbolic.svg,
in files/branding/, is the reduced logo in one ink with filled shapes, as GNOME's symbolic icons
need: Ubuntu Dock's Show Apps button uses it instead of Ubuntu's logo."""
import math, pathlib

GA = 137.5
FULL = ([(282, 60, -45, 46), (204, 26, -45 + GA, 40), (152, 26, -45 + 2 * GA, 40), (100, 26, -45 + 3 * GA, 40)], 46)
SMALL = ([(275, 90, -45, 70), (140, 60, -45 + GA, 60)], 56)   # (radius, width, notch angle, notch length), centre radius
DARK = ("#ECE6D9", "#A9A397", "#C9A54A")    # outer ring, inner rings, centre: on dark backgrounds
LIGHT = ("#15130F", "#6E695F", "#9A7A26")

def svg(rings, centre, colours):
    out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800">', "  <title>Kinobu</title>"]
    for i, (r, width, angle, notch) in enumerate(rings):
        length = 2 * math.pi * r
        out.append(f'  <circle cx="400" cy="400" r="{r}" fill="none" stroke="{colours[0 if i == 0 else 1]}" stroke-width="{width}" '
                   f'stroke-dasharray="{length - notch:.2f} {notch:.2f}" transform="rotate({angle + math.degrees(notch / r) / 2:.2f} 400 400)"/>')
    out.append(f'  <circle cx="400" cy="400" r="{centre}" fill="{colours[2]}"/>')
    return "\n".join(out) + "\n</svg>\n"

def symbolic(rings, centre, size=16):
    """One ink, filled shapes only (GNOME recolours the fill of symbolic icons, not strokes)."""
    k, c = size / 800, size / 2
    def point(r, deg):
        a = math.radians(deg)
        return f"{c + r * k * math.cos(a):.3f},{c + r * k * math.sin(a):.3f}"
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">']
    for r, width, angle, notch in rings:
        gap = math.degrees(notch / r)
        start, end = angle + gap / 2, angle - gap / 2 + 360       # the ring, without its notch
        outer, inner = r + width / 2, r - width / 2
        large = 1 if end - start > 180 else 0
        out.append(f'  <path fill="#2e3436" d="M{point(outer, start)} A{outer * k:.3f},{outer * k:.3f} 0 {large},1 '
                   f'{point(outer, end)} L{point(inner, end)} A{inner * k:.3f},{inner * k:.3f} 0 {large},0 {point(inner, start)} Z"/>')
    out.append(f'  <circle cx="{c}" cy="{c}" r="{centre * k:.3f}" fill="#2e3436"/>')
    return "\n".join(out) + "\n</svg>\n"

if __name__ == "__main__":
    assets = pathlib.Path(__file__).resolve().parent.parent / "assets"
    for name, (rings, centre) in (("logo", FULL), ("logo-small", SMALL)):
        (assets / f"{name}.svg").write_text(svg(rings, centre, DARK))
        (assets / f"{name}-light.svg").write_text(svg(rings, centre, LIGHT))
    branding = assets.parent / "files" / "branding"
    (branding / "show-apps-symbolic.svg").write_text(symbolic(*SMALL))
