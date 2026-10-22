"""bg_map and shop_decor, in the style of the designer's hand-drawn bg_title / bg_battle
(DECISIONS D-R11, D-R12): flat dark values, ordered dither only for fades and glows, one warm
light, no texture patterns, no extra shading.

    python tools/art/backgrounds.py --only bg_map --preview captures/bg_preview.png
    python tools/art/backgrounds.py --only shop_decor      # write

bg_map: a plain light-to-dark field (the cards carry the information).
shop_decor: the only decorated part of the shop, the right-column corner (120x182).
bg_title and bg_battle are hand-drawn by the designer: no generator owns them.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelgrid import grid, paste, run  # noqa: E402
from palette import rgba  # noqa: E402

W, H = 640, 300
BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


def new(fill: str) -> Image.Image:
    return Image.new("RGBA", (W, H), rgba(fill))


def glow(img: Image.Image, cx: int, cy: int, r: int, key: str) -> None:
    """Checker-dither halo (as around the designer's moon) on pixels of the darkest values."""
    px = img.load()
    col = rgba(key)
    dark = {rgba("N0"), rgba("N1")}
    w, h = img.size
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            if 0 <= x < w and 0 <= y < h and (x - cx) ** 2 + (y - cy) ** 2 <= r * r \
                    and (x + y) % 2 == 0 and px[x, y] in dark:
                px[x, y] = col


# ---------------------------------------------------------------------------------- bg_map
# Plain light-to-dark field (designer request 2026-10-22): the cards carry the information.

def fade(img: Image.Image, stops: list[tuple[int, str]]) -> None:
    """Vertical ordered-dither fade through palette keys at the given rows (lightest on top)."""
    px = img.load()
    for (y0, k0), (y1, k1) in zip(stops, stops[1:]):
        a, b = rgba(k0), rgba(k1)
        for y in range(y0, min(y1, H)):
            level = (y - y0) / max(1, y1 - y0) * 16
            for x in range(W):
                px[x, y] = b if BAYER[y % 4][x % 4] < level else a
    last = rgba(stops[-1][1])
    for y in range(stops[-1][0], H):
        for x in range(W):
            px[x, y] = last


def bg_map() -> Image.Image:
    img = new("N0")
    fade(img, [(0, "N3"), (70, "N2"), (150, "N1"), (235, "N0")])
    return img


# ----------------------------------------------------------------------------- shop_decor
# The Crypt Market keeps the whole screen dark; only the right-column corner is decorated
# (designer request 2026-10-22): an arched alcove with the undertaker's shelf (skulls, one tall
# candle, a pile of coins). The shopkeeper sprite stands in front of it, placed by the scene.
# 120x182 = the right column above the two buttons (ART_SPEC §6.3).

DW, DH = 120, 182

SKULL = [
    "..####..",
    ".#7ccc#.",
    "#7ccccc#",
    "#c##c##c",
    "#c##c##c",
    "#cccBccc",
    ".#cBcB#.",
    "..####..",
]

COINS = [
    "....##....",
    "...#OO#...",
    "..#OoOO#..",
    ".#OOOoOO#.",
    "#OoOOOOoO#",
    "##########",
]

CANDLE = [
    "..g..",
    ".gFg.",
    ".gFg.",
    "..o..",
    ".#c#.",
    ".#c#.",
    ".#c#.",
    ".#c#.",
    ".#B#.",
    ".#B#.",
    ".#B#.",
    ".#B#.",
    "#####",
]


def shop_decor() -> Image.Image:
    img = Image.new("RGBA", (DW, DH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # arched alcove: N2 rim, N1 inside, open at the bottom onto the floor
    for inset, key in ((6, "N2"), (9, "N1")):   # rim, then inside
        x0, x1, top = inset, DW - 1 - inset, 6 + inset
        r = (x1 - x0) // 2
        d.pieslice((x0, top, x1, top + 2 * r), 180, 360, fill=rgba(key))
        d.rectangle((x0, top + r, x1, DH - 1), fill=rgba(key))
    # the shelf with skulls, the candle and the coins
    d.rectangle((14, 82, DW - 15, 84), fill=rgba("N3"))
    for x in (18, 32, 90):
        paste(img, grid(SKULL), x, 74)
    glow(img, 62, 60, 15, "N2")
    paste(img, grid(CANDLE), 60, 70)
    paste(img, grid(COINS), 70, 76)
    # floor line the shopkeeper's counter stands on
    d.rectangle((9, DH - 9, DW - 10, DH - 9), fill=rgba("N3"))
    return img


ASSETS = {"bg_map": bg_map, "shop_decor": shop_decor}

if __name__ == "__main__":
    sys.exit(run(ASSETS, sys.argv[1:]))
