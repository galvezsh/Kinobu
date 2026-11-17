#!/usr/bin/env python3
"""Draws Kinobu's terminal branding into files/branding/: the rings (logo.txt, and the larger
files/shell/fastfetch-logo.txt) and the KINOBU
wordmark whose O is the rings (wordmark.txt, and assets/kinobu-{dark,light}.svg for the README), with letters as tall as the rings (9 rows). Colour marks: $1 outer ring and letters,
$2 inner ring, $3 centre (the accent). Letters: figlet font Delta Corps Priest 1.

Usage: branding.py [--rows N] [--letters 8|9|10] [--i plain|pine|sprout] [--print]"""
import argparse, math, pathlib

GA = 137.5   # golden angle between the notches of the rings
RINGS = ([(275, 90, -45, 70), (140, 60, -45 + GA, 60)], 56)   # (radius, width, notch angle, notch length), centre radius
QUAD = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"   # bit 1 top-left, 2 top-right, 4 bottom-left, 8 bottom-right

LETTERS = {
    "K": ["   ▄█   ▄█▄", "  ███ ▄███▀", "  ███▐██▀  ", " ▄█████▀   ", "▀▀█████▄   ", "  ███▐██▄  ", "  ███ ▀███▄", "  ███   ▀█▀", "  ▀        "],
    "I": [" ▄█ ", "███ ", "███▌", "███▌", "███▌", "███ ", "███ ", "█▀  "],
    "N": ["███▄▄▄▄  ", "███▀▀▀██▄", "███   ███", "███   ███", "███   ███", "███   ███", "███   ███", " ▀█   █▀ "],
    "B": ["▀█████████▄ ", "  ███    ███", "  ███    ███", " ▄███▄▄▄██▀ ", "▀▀███▀▀▀██▄ ", "  ███    ██▄", "  ███    ███", "▄█████████▀ "],
    "U": ["███    █▄ ", "███    ███", "███    ███", "███    ███", "███    ███", "███    ███", "███    ███", "████████▀ "],
}
TALL = {   # the same letters two rows taller, to match rings of 10 rows
    "K": ["   ▄█     ▄█▄", "  ███   ▄███▀", "  ███ ▄███▀  ", "  ███▐██▀    ", " ▄█████▀     ", "▀▀█████▄     ", "  ███▐██▄    ", "  ███ ▀███▄  ", "  ███   ▀███▄", "  ███     ▀█▀", "  ▀          "],
    "I": [" ▄█ ", "███ ", "███▌", "███▌", "███▌", "███▌", "███▌", "███ ", "███ ", "█▀  "],
    "N": ["███▄▄▄▄  ", "███▀▀▀██▄", "███   ███", "███   ███", "███   ███", "███   ███", "███   ███", "███   ███", "███   ███", " ▀█   █▀ "],
    "B": ["▀█████████▄ ", "  ███    ███", "  ███    ███", "  ███    ███", " ▄███▄▄▄██▀ ", "▀▀███▀▀▀██▄ ", "  ███    ██▄", "  ███    ███", "  ███    ███", "▄█████████▀ "],
    "U": ["███    █▄ ", "███    ███", "███    ███", "███    ███", "███    ███", "███    ███", "███    ███", "███    ███", "███    ███", "████████▀ "],
}
I_SHAPES = {
    "plain": LETTERS["I"],
    "pine": ["   ▟▙   ", "  ▟██▙  ", " ▟████▙ ", "  ▟██▙  ", " ▟████▙ ", "▟██████▙", "   ██   ", "   ██   "],
    "sprout": [" ▄█  ▄▄", "███ ▟█▀", "███▟▀  ", "███▌   ", "███▌   ", "███    ", "███    ", "█▀     "],
}

def layer(x, y):
    """0 nothing, 1 outer ring, 2 inner ring, 3 centre, for a point of the 800-unit canvas."""
    rings, dot = RINGS
    r = math.hypot(x, y)
    if r <= dot:
        return 3
    a = math.degrees(math.atan2(y, x))
    for i, (rad, w, ang, notch) in enumerate(rings):
        if abs(r - rad) <= w / 2:
            if abs((a - ang + 180) % 360 - 180) <= math.degrees(notch / rad) / 2:
                return 0
            return 1 if i == 0 else 2
    return 0

def rings(rows, cols=None, ss=6):
    """The rings as rows of (character, colour) cells."""
    cols = cols or round(rows * 2.1)
    size, out = 648, []
    for cy in range(rows):
        row = []
        for cx in range(cols):
            bits, votes = 0, [0, 0, 0, 0]
            for q in range(4):
                hit = 0
                for sy in range(ss):
                    for sx in range(ss):
                        x = (cx * 2 + q % 2 + (sx + .5) / ss) / (cols * 2) * size - size / 2
                        y = (cy * 2 + q // 2 + (sy + .5) / ss) / (rows * 2) * size - size / 2
                        l = layer(x, y)
                        if l:
                            hit += 1; votes[l] += 1
                if hit > ss * ss / 2:
                    bits |= 1 << q
            row.append((QUAD[bits], max((1, 2, 3), key=lambda l: votes[l]) if bits else 0))
        out.append(row)
    return out

def marked(rows):
    """Rows of cells as text lines with $N colour marks."""
    lines = []
    for row in rows:
        line, current = "", 0
        for ch, colour in row:
            if colour and colour != current:
                line += f"${colour}"; current = colour
            line += ch
        lines.append(line.rstrip())
    return "\n".join(lines) + "\n"

HALF = {"█": 15, "▀": 3, "▄": 12, "▌": 5, "▐": 10}   # block characters as 2 x 2 pixels (see QUAD)

def pixels(block):
    """A letter as rows of pixels, two per character each way."""
    width = max(len(r) for r in block)
    grid = []
    for row in block:
        top, bottom = [], []
        for ch in row.ljust(width):
            bits = HALF.get(ch, QUAD.index(ch) if ch in QUAD else 0)
            top += [bits & 1, bits >> 1 & 1]; bottom += [bits >> 2 & 1, bits >> 3 & 1]
        grid += [top, bottom]
    return grid

def shorten(block, cut=(5, 14)):
    """A 10-row letter one pixel lower at the top half and one at the bottom half: 9 rows."""
    grid = pixels(block)
    for y in sorted(cut, reverse=True):
        # prefer a pixel row equal to its neighbour, so no detail is lost
        for near in (y, y - 1, y + 1, y - 2, y + 2):
            if grid[near] == grid[near + 1]:
                y = near
                break
        del grid[y]
    if len(grid) % 2:
        grid.append([0] * len(grid[0]))
    out = []
    for y in range(0, len(grid), 2):
        out.append("".join(QUAD[grid[y][x] | grid[y][x + 1] << 1 | grid[y + 1][x] << 2 | grid[y + 1][x + 1] << 3]
                           for x in range(0, len(grid[0]), 2)))
    while out and not out[-1].strip():
        out.pop()
    return out

def wordmark(ring_rows=9, i_shape="plain", body=9, gap=2):
    """KINOBU with the rings as its O. body is the height of the letters: 8 (the font's own),
    9 (default) or 10; the rings are centred on them."""
    if body == 8:
        letters = dict(LETTERS); letters["I"] = I_SHAPES[i_shape]
    elif body == 9:
        letters = {k: shorten(v) for k, v in TALL.items()}
    else:
        letters = dict(TALL)
    height = max(ring_rows, body) + 1          # one more row for the tail of the K
    top = (max(ring_rows, body) - body) // 2
    grid = [[] for _ in range(height)]
    def add(block, offset):
        width = max(len(r) for r in block)
        for y in range(height):
            src = block[y - offset] if 0 <= y - offset < len(block) else []
            cells = [(c, 1 if c != " " else 0) if isinstance(c, str) else c for c in src]
            grid[y].extend(cells + [(" ", 0)] * (width - len(cells)))
    def space(n):
        for row in grid:
            row.extend([(" ", 0)] * n)
    add(letters["K"], top); space(1)
    add(letters["I"], top); space(1)
    add(letters["N"], top); space(gap)
    add(rings(ring_rows), (max(ring_rows, body) - ring_rows) // 2); space(gap)
    add(letters["B"], top); space(1)
    add(letters["U"], top)
    while not any(c != " " for c, _ in grid[-1]):
        grid.pop()
    return grid

def svg(grid, colours, cw=10, ch=21):
    """The wordmark as an SVG: every lit quarter of a character is a rectangle, so no font is needed."""
    rows, cols = len(grid), max(len(r) for r in grid)
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {cols * cw} {rows * ch}" role="img" aria-label="Kinobu">',
           "  <title>Kinobu</title>"]
    for colour in (1, 2, 3):
        path = ""
        for y, row in enumerate(grid):
            for x, (char, c) in enumerate(row):
                if c != colour:
                    continue
                bits = HALF.get(char, QUAD.index(char) if char in QUAD else 0)
                for q in range(4):
                    if bits >> q & 1:
                        path += f"M{x * cw + q % 2 * cw / 2:g} {y * ch + q // 2 * ch / 2:g}h{cw / 2:g}v{ch / 2:g}h-{cw / 2:g}z"
        out.append(f'  <path fill="{colours[colour - 1]}" d="{path}"/>')
    return "\n".join(out) + "\n</svg>\n"


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--rows", type=int, default=9, help="height of the rings")
    ap.add_argument("--letters", type=int, default=9, choices=(8, 9, 10), help="height of the letters")
    ap.add_argument("--i", default="plain", choices=list(I_SHAPES), help="shape of the I (8-row letters only)")
    ap.add_argument("--print", action="store_true")
    args = ap.parse_args()
    word = marked(wordmark(args.rows, args.i, args.letters))
    if args.print:
        print(word, end="")
    else:
        out = pathlib.Path(__file__).resolve().parent.parent / "files" / "branding"
        (out / "wordmark.txt").write_text(word)
        (out / "logo.txt").write_text(marked(rings(11)))
        (out.parent / "shell" / "fastfetch-logo.txt").write_text(marked(rings(17)))
        # The README banner, for GitHub's dark and light themes
        assets = out.parent.parent / "assets"
        grid = wordmark(args.rows, args.i, args.letters)
        (assets / "kinobu-dark.svg").write_text(svg(grid, ("#ECE6D9", "#A9A397", "#C9A54A")))
        (assets / "kinobu-light.svg").write_text(svg(grid, ("#15130F", "#6E695F", "#9A7A26")))
