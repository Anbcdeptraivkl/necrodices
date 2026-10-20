"""Scenery art: backgrounds, VFX, logo, app icon and the DEFEATED stamp (ART_SPEC §7, §10, §11).

    python tools/art/scenery.py                         # write every id that changed
    python tools/art/scenery.py --only bg_*             # backgrounds only
    python tools/art/scenery.py --preview out.png       # x6 contact sheet, writes nothing

Backgrounds are scenery: they are composed from palette-only operations (dithered sky in
the sky only, silhouette ridges, seeded placement) plus hand-placed row grids for every prop
(gravestones, lanterns, candles, shelf items, bats, windows). Logo letters, the app icon,
the stamp lettering and every VFX frame are hand-placed grids.

Layout facts the backgrounds respect (ART_SPEC §6, §11): the 640x300 image is drawn centred,
so the 480x270 base canvas sees bg x 80..560, y 15..285. Battle: the battlefield (bg x 128..512,
y 98..268) holds only N1/N2 with very low detail; the horizon sits behind the enemy zone above.
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelgrid import BASE_LEGEND, canvas, grid, rgba, run, sheet  # noqa: E402

W, H = 640, 300
BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


# ---------------------------------------------------------------------------------------------
# A palette-key canvas (every write is a Hallow32 key, never a raw colour)
# ---------------------------------------------------------------------------------------------

class Pic:
    def __init__(self, w: int, h: int, fill: str | None = None):
        self.w, self.h = w, h
        self.px: list[list[str | None]] = [[fill] * w for _ in range(h)]

    def put(self, x: int, y: int, k: str | None) -> None:
        if k is not None and 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = k

    def get(self, x: int, y: int) -> str | None:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def rect(self, x: int, y: int, w: int, h: int, k: str) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, k)

    def hline(self, x0: int, x1: int, y: int, k: str) -> None:
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.put(x, y, k)

    def vline(self, x: int, y0: int, y1: int, k: str) -> None:
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.put(x, y, k)

    def line(self, x0: int, y0: int, x1: int, y1: int, k: str) -> None:
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, k)
            if x0 == x1 and y0 == y1:
                return
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def poly(self, pts: list[tuple[float, float]], k: str) -> None:
        """Even-odd scanline fill, sampled at pixel centres."""
        ys = [p[1] for p in pts]
        for y in range(max(0, int(min(ys))), min(self.h, int(max(ys)) + 1)):
            cy = y + 0.5
            xs = []
            for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]):
                if (y0 <= cy < y1) or (y1 <= cy < y0):
                    xs.append(x0 + (cy - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for a, b in zip(xs[::2], xs[1::2]):
                for x in range(int(math.ceil(a - 0.5)), int(math.floor(b - 0.5)) + 1):
                    self.put(x, y, k)

    def disc(self, cx: float, cy: float, r: float, k: str) -> None:
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    self.put(x, y, k)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, k: str) -> None:
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, k)

    def stamp(self, rows: list[str], x: int, y: int, legend: dict | None = None,
              flip: bool = False) -> None:
        """Paste a hand-placed row grid (BASE_LEGEND letters -> palette keys)."""
        leg = dict(BASE_LEGEND)
        if legend:
            leg.update(legend)
        for j, row in enumerate(rows):
            if flip:
                row = row[::-1]
            for i, ch in enumerate(row):
                k = leg[ch]
                if k is not None:
                    self.put(x + i, y + j, k)

    def image(self):
        img = canvas(self.w, self.h)
        cache: dict[str, tuple] = {}
        data = []
        for row in self.px:
            for k in row:
                if k is None:
                    data.append((0, 0, 0, 0))
                else:
                    if k not in cache:
                        cache[k] = rgba(k)
                    data.append(cache[k])
        img.putdata(data)
        return img


def dith(x: int, y: int, t: float) -> bool:
    """Ordered (4x4 Bayer) threshold: True -> use the second colour."""
    return t * 16 > BAYER[y & 3][x & 3] + 0.5


def sky(p: Pic, stops: list[tuple[int, str]], wobble: float = 2.0, seed: int = 0) -> None:
    """Flat bands joined by ordered-dither ramps. stops = [(y, key), ...] with paired ys:
    a band holds `key` from its y to the next stop; a different next key means a ramp."""
    ph = seed * 0.37
    for x in range(p.w):
        off = wobble * math.sin(x / 41.0 + ph) + wobble * 0.6 * math.sin(x / 13.0 + ph * 2)
        for y in range(p.h):
            yy = y + off
            k = stops[-1][1]
            for (ya, ka), (yb, kb) in zip(stops, stops[1:]):
                if yy < yb:
                    if yy < ya:
                        k = ka
                    elif ka == kb:
                        k = ka
                    else:
                        k = kb if dith(x, y, (yy - ya) / (yb - ya)) else ka
                    break
            p.px[y][x] = k


def smooth_noise(rng: random.Random, x0: int, x1: int, step: int, amp: float):
    """1D value noise (cosine-interpolated control points) -> f(x)."""
    pts = {x: rng.uniform(-amp, amp) for x in range(x0 - step, x1 + 2 * step, step)}

    def f(x: float) -> float:
        a = x0 - step + int((x - (x0 - step)) // step) * step
        t = (x - a) / step
        t = (1 - math.cos(t * math.pi)) / 2
        return pts[a] * (1 - t) + pts.get(a + step, 0.0) * t
    return f


def fill_below(p: Pic, top, k: str, x0: int = 0, x1: int | None = None, bottom: int | None = None) -> None:
    x1 = p.w if x1 is None else x1
    bottom = p.h if bottom is None else bottom
    for x in range(x0, x1):
        for y in range(int(round(top(x))), bottom):
            p.put(x, y, k)


def moon(p: Pic, cx: int, cy: int, r: int, craters: list[tuple[int, int, int]], glow: str,
         base_sky: str, glow_w: int = 8) -> None:
    """Moon disc: N6 body, N7 top-left light, N5 bottom-right terminator and craters.
    The glow is an ordered-dither ring in the sky colour above `base_sky` (sky only)."""
    for y in range(cy - r - glow_w - 1, cy + r + glow_w + 2):
        for x in range(cx - r - glow_w - 1, cx + r + glow_w + 2):
            d = math.hypot(x - cx, y - cy)
            if r < d <= r + glow_w and p.get(x, y) == base_sky:
                t = 1 - (d - r) / glow_w
                if dith(x, y, t * 0.85):
                    p.put(x, y, glow)
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy <= r * r + r * 0.6:
                k = "N6"
                s = (dx + dy) / r
                if s < -0.55 and dx * dx + dy * dy < (r - 1.5) ** 2:
                    k = "N7"
                if s > 0.9:
                    k = "N5"
                p.put(x, y, k)
    for ox, oy, cr in craters:
        for y in range(cy + oy - cr, cy + oy + cr + 1):
            for x in range(cx + ox - cr, cx + ox + cr + 1):
                dx, dy = x - cx - ox, y - cy - oy
                if dx * dx + dy * dy <= cr * cr + cr * 0.5 and (x - cx) ** 2 + (y - cy) ** 2 <= (r - 1) ** 2:
                    p.put(x, y, "N5")
        # lit lower-right rim of the crater (light from top-left falls inside the bowl)
        for y in range(cy + oy - cr, cy + oy + cr + 2):
            for x in range(cx + ox - cr, cx + ox + cr + 2):
                dx, dy = x - cx - ox, y - cy - oy
                d2 = dx * dx + dy * dy
                if cr >= 3 and cr * cr + cr * 0.5 < d2 <= (cr + 1) ** 2 + 0.5 and dx + dy > 0 \
                        and (x - cx) ** 2 + (y - cy) ** 2 <= (r - 1) ** 2 and p.get(x, y) == "N6":
                    p.put(x, y, "N7")


def stars(p: Pic, rng: random.Random, n: int, region: tuple[int, int, int, int], sky_keys: set[str],
          avoid=None, bright: int = 6) -> None:
    x0, y0, x1, y1 = region
    placed = 0
    tries = 0
    while placed < n and tries < n * 20:
        tries += 1
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        if avoid and avoid(x, y):
            continue
        if any(p.get(x + dx, y + dy) not in sky_keys for dx in (-2, 0, 2) for dy in (-2, 0, 2)):
            continue
        roll = rng.random()
        if placed < bright:
            p.put(x, y, "N7")
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p.put(x + dx, y + dy, "N5")
        elif roll < 0.25:
            p.put(x, y, "N6")
        elif roll < 0.6:
            p.put(x, y, "N5")
        else:
            p.put(x, y, "N4")
        placed += 1


def cloud(p: Pic, x: int, y: int, lobes: list[tuple[int, int, int]], body: str, rim: str,
          only_on: set[str] | None = None) -> None:
    """A flat cloud from overlapping lobes (dx, dy, r); `rim` on the top edge (moonlit)."""
    mask = set()
    for dx, dy, r in lobes:
        for yy in range(-r, r + 1):
            for xx in range(-2 * r, 2 * r + 1):
                if (xx / 2.0) ** 2 + yy * yy <= r * r and yy <= r // 2:
                    mask.add((x + dx + xx, y + dy + yy))
    for (mx, my) in mask:
        if only_on is not None and p.get(mx, my) not in only_on:
            continue
        p.put(mx, my, rim if (mx, my - 1) not in mask else body)


# ---------------------------------------------------------------------------------------------
# Prop grids (hand-placed). '#' N0, digits N1..N7, letters per BASE_LEGEND.
# ---------------------------------------------------------------------------------------------

GRAVES = {
    "round": [
        "..#####..",
        ".#33332#.",
        "#3322222#",
        "#3222222#",
        "#3221222#",
        "#3222122#",
        "#3222222#",
        "#3212222#",
        "#3221222#",
        "#3222222#",
        "#2222221#",
        "#########",
    ],
    "slab": [
        ".######.",
        "#333332#",
        "#322222#",
        "#322222#",
        "#322212#",
        "#322122#",
        "#322222#",
        "#322222#",
        "#222221#",
        "########",
    ],
    "lean": [
        "....####..",
        "...#3332#.",
        "..#3322221#",
        "..#322222#",
        ".#3222212#",
        ".#322212#.",
        "#3222222#.",
        "#322222#..",
        "#2222221#.",
        "##########",
    ],
    "broken": [
        ".##.#...",
        "#33#3#..",
        "#3222#..",
        "#32222##",
        "#322222#",
        "#322122#",
        "#322222#",
        "#222221#",
        "########",
    ],
    "obelisk": [
        "...#...",
        "..#3#..",
        "..#32#.",
        ".#322#.",
        ".#322#.",
        ".#312#.",
        ".#322#.",
        ".#322#.",
        ".#322#.",
        ".#321#.",
        "#33222#",
        "#22221#",
        "#######",
    ],
    "small": [
        ".####.",
        "#3332#",
        "#3222#",
        "#3212#",
        "#3222#",
        "#2221#",
        "######",
    ],
    "big": [
        "...#######...",
        "..#3333332#..",
        ".#333222222#.",
        "#33222222222#",
        "#32222222222#",
        "#32221111222#",
        "#32222222222#",
        "#32211111222#",
        "#32222222222#",
        "#32222222122#",
        "#32222221222#",
        "#32222212222#",
        "#32222222222#",
        "#22222222221#",
        "#22222222221#",
        "#############",
    ],
}

def dead_tree(p: Pic, x: int, base_y: int, height: int, seed: int, k: str = "N0",
              lean: float = 0.0) -> None:
    """Gnarled dead tree: tapered trunk, forking crooked limbs, 1 px twigs."""
    rng = random.Random(seed)

    def brush(cx: float, cy: float, w: float) -> None:
        r = (max(1, round(w)) - 1) / 2.0
        for yy in range(int(round(cy - r)), int(round(cy + r)) + 1):
            for xx in range(int(round(cx - r)), int(round(cx + r)) + 1):
                p.put(xx, yy, k)

    def branch(cx: float, cy: float, ang: float, length: float, w: float, depth: int) -> None:
        steps = max(3, int(length))
        for i in range(steps):
            if i % 4 == 0:
                ang += rng.uniform(-0.22, 0.22)
                ang += (math.pi / 2 - ang) * 0.04   # limbs drift back toward up
            cx += math.cos(ang)
            cy -= math.sin(ang)
            brush(cx, cy, w * (1 - 0.45 * i / steps))
            if depth >= 2 and i == steps // 2 and rng.random() < 0.6:
                side = rng.choice((-1, 1))
                branch(cx, cy, ang + side * rng.uniform(0.7, 1.1), length * 0.35, max(1, w * 0.4), 0)
        if depth <= 0:
            return
        forks = 3 if rng.random() < 0.25 else 2
        for j in range(forks):
            side = -1 if j % 2 == 0 else 1
            branch(cx, cy, ang + side * rng.uniform(0.3, 0.75), length * rng.uniform(0.55, 0.75),
                   max(1, w * 0.6), depth - 1)

    trunk_w = max(2, height / 11)
    for d in (-1, 1):  # roots
        p.line(x, base_y, x + d * int(trunk_w + 3), base_y + 1, k)
        p.line(x, base_y - 1, x + d * int(trunk_w + 1), base_y, k)
    branch(x, base_y, math.pi / 2 + lean, height * 0.42, trunk_w, 4)


LANTERN = [
    "....#....",
    "...#3#...",
    "..#332#..",
    ".#33322#.",
    "#########",
    ".#gggFg#.",
    ".#ggFFg#.",
    ".#gFFgg#.",
    ".#ggggg#.",
    "#########",
    "..#332#..",
]

BAT_A = [
    "#.......#",
    "##.#.#.##",
    "###...###",
    ".#######.",
    "..#.#.#..",
]
BAT_B = [
    "...#.#...",
    "...###...",
    ".#######.",
    "##.....##",
    "#.......#",
]
BAT_SMALL = [
    "#.#.#",
    ".###.",
]


# ---------------------------------------------------------------------------------------------
# bg_battle — graveyard at night
# ---------------------------------------------------------------------------------------------

def _house(p: Pic, x: int, base: int, w: int, h: int, roof: int, lean: int, k: str,
           windows: list[tuple[int, int, str]], chimney: int | None = None, rim: str | None = None) -> None:
    top = base - h
    p.rect(x, top, w, h + 1, k)
    apex_x = x + w // 2 + lean
    p.poly([(x - 1, top + 0.5), (apex_x + 0.5, top - roof), (x + w + 1, top + 0.5)], k)
    if chimney is not None:
        cxp = x + chimney
        # chimney height relative to the roof line at that x
        p.rect(cxp, top - roof // 2 - 3, 2, roof // 2 + 3, k)
        p.put(cxp - 1, top - roof // 2 - 3, k)
        p.put(cxp + 2, top - roof // 2 - 3, k)
    if rim:
        # moonlit left roof edge
        for i in range(roof + 1):
            xx = int(round(x - 1 + (apex_x + 0.5 - (x - 1)) * i / max(1, roof)))
            yy = top - i
            if p.get(xx, yy) == k:
                p.put(xx, yy, rim)
    for wx, wy, key in windows:
        p.put(x + wx, top + wy, key)


def _bell_tower(p: Pic, x: int, base: int, k: str, rim: str) -> None:
    rows = [
        ".......#.......",
        ".......#.......",
        "......###......",
        "......###......",
        ".....#####.....",
        ".....#####.....",
        "....#######....",
        "....#######....",
        "...#########...",
        "...#########...",
        "..###########..",
        "...#########...",
        "...##.....##...",
        "...#...o...#...",
        "...#..ooo..#...",
        "...##.....##...",
        "..###########..",
        "...#########...",
        "...#########...",
        "...####g####...",
        "...####g####...",
        "...#########...",
        "...#########...",
        "...#########...",
        "...##g######...",
        "...#########...",
        "...#########...",
        "...#########...",
        "...######g##...",
        "...######g##...",
        "...#########...",
        "...#########...",
    ]
    top = base - len(rows) + 1
    p.stamp(rows, x, top, {"#": k, "o": "G0"})
    # opening shows the sky behind it: keep the hole transparent by not painting '.'
    for j in range(0, 11):
        for i in range(15):
            if rows[j][i] == "#" and (i == 0 or rows[j][i - 1] == "."):
                p.put(x + i, top + j, rim)


def _fence(p: Pic, rng: random.Random, x0: int, x1: int, base_y, broken_at: set[int]) -> None:
    """Crooked wooden picket fence: posts, two sagging rails, 2 px pickets that lean per
    section, some short or missing; sections listed in `broken_at` have a fallen rail."""
    x = x0
    while x < x1:
        sec_w = rng.randint(30, 42)
        lean = rng.choice((-1, 0, 0, 0, 1))
        sag = rng.choice((0, 1, 1, 2))
        broken = any(x <= b < x + sec_w for b in broken_at)
        # post: 3 px face, taller, with a cap
        by = int(round(base_y(x)))
        ph = 14 + rng.randint(0, 2)
        p.vline(x - 1, by - ph, by, "N0")
        p.vline(x, by - ph, by, "N3")
        p.vline(x + 1, by - ph, by, "N2")
        p.vline(x + 2, by - ph, by, "N1")
        p.vline(x + 3, by - ph, by, "N0")
        p.hline(x - 1, x + 3, by - ph - 1, "N0")
        p.hline(x, x + 2, by - ph - 2, "N0")
        p.put(x + 1, by - ph - 1, "N3")
        # rails (behind the pickets)
        for c in range(x + 4, x + sec_w):
            t = (c - x) / sec_w
            s_ = sag * math.sin(math.pi * t)
            bc = base_y(c)
            for k_off, rail in ((3, 0), (8, 1)):
                if broken and rail == 1:
                    ry = int(round(bc - 8 + 6 * t + s_))  # one end fallen
                else:
                    ry = int(round(bc - k_off + s_))
                p.put(c, ry, "N2")
                p.put(c, ry + 1, "N0")
        # pickets
        c = x + 6
        while c < x + sec_w - 2:
            if broken and rng.random() < 0.45:
                c += 4
                continue
            if rng.random() < 0.06:
                c += 4
                continue
            bc = int(round(base_y(c)))
            h = rng.randint(9, 11)
            short = rng.random() < 0.1
            if short:
                h = rng.randint(5, 7)
            pl = lean + (rng.random() < 0.2) * rng.choice((-1, 1))
            for j in range(h + 1):
                off = int(round(pl * j / h))
                yy = bc - j
                p.put(c + off - 1, yy, "N0")
                p.put(c + off, yy, "N3")
                p.put(c + off + 1, yy, "N2")
                p.put(c + off + 2, yy, "N0")
            off = int(round(pl))
            top = bc - h
            if short:
                p.put(c + off, top - 1, "N0")
                p.put(c + off + 1, top, "N0")
            else:
                p.put(c + off, top - 1, "N0")
                p.put(c + off + 1, top - 1, "N0")
                p.put(c + off, top - 2, "N0") if pl <= 0 else p.put(c + off + 1, top - 2, "N0")
            c += 4
        x += sec_w


def _village(p: Pic, rng: random.Random, ridge, houses, rim: str = "N2") -> None:
    """houses: (x, w, h, roof, lean, windows, chimney); windows (dx, dy, key) or (dx, dy, key, w, h)."""
    for hx, hw, hh, roof, lean, wins, chim in houses:
        base = int(round(ridge(hx + hw // 2))) + 3
        flat = []
        for wdw in wins:
            if len(wdw) == 3:
                flat.append(wdw)
            else:
                dx, dy, key, ww, wh = wdw
                flat += [(dx + i, dy + j, key) for i in range(ww) for j in range(wh)]
        _house(p, hx, base, hw, hh, roof, lean, "N0", flat, chim, rim=rim)


def bg_battle():
    rng = random.Random("bg_battle")
    p = Pic(W, H)
    horizon = 91
    sky(p, [(0, "N0"), (22, "N0"), (42, "N1"), (56, "N1"), (82, "N2"), (300, "N2")], seed=3)
    sky_keys = {"N0", "N1", "N2"}

    # moon top-right of the stage (inside the centre column on both canvas sizes)
    mcx, mcy, mr = 414, 52, 12
    moon(p, mcx, mcy, mr, [(-4, -1, 2), (4, 4, 1), (3, -5, 1)], glow="N2", base_sky="N1", glow_w=7)
    stars(p, rng, 90, (0, 0, W, 66), sky_keys,
          avoid=lambda x, y: math.hypot(x - mcx, y - mcy) < mr + 12, bright=4)
    cloud(p, 384, 62, [(0, 0, 2), (9, -2, 3), (20, 0, 3), (30, 1, 2)], "N2", "N3")
    cloud(p, 150, 48, [(0, 0, 2), (9, -1, 3), (18, 0, 2)], "N1", "N2")
    cloud(p, 520, 38, [(0, 0, 2), (8, -1, 2), (15, 0, 1)], "N1", "N2")

    # far ridge with a fringe of pines (N1 against the N2 horizon glow)
    far = smooth_noise(rng, 0, W, 48, 4)
    far_top = lambda x: 77 + far(x) + 3 * math.sin(x / 90.0)  # noqa: E731
    fill_below(p, far_top, "N1")
    for _ in range(40):
        tx = rng.randrange(0, W)
        if 200 < tx < 440:
            continue
        ty = int(round(far_top(tx)))
        th = rng.randint(5, 10)
        for j in range(th):
            half = (j * 3) // th
            p.hline(tx - half, tx + half, ty - th + j + 1, "N1")
        p.put(tx, ty - th, "N1")

    # distant village (N0 silhouettes, tiny F2 windows); low behind the enemy (x 300..340)
    _village(p, rng, far_top, [
        (134, 12, 10, 8, 0, [(3, 3, "F2"), (8, 3, "F2", 1, 2)], 2),
        (147, 9, 7, 7, 1, [(4, 2, "F1")], None),
        (160, 15, 12, 10, -1, [(3, 3, "F2", 2, 2), (10, 3, "F2", 2, 2), (7, 8, "F1")], 11),
        (178, 10, 8, 11, 2, [(4, 3, "F2", 1, 2)], None),
        (190, 13, 9, 7, 0, [(2, 3, "F2"), (9, 3, "F2")], 9),
        (226, 10, 9, 8, 0, [(4, 3, "F2", 2, 2)], 2),
        (238, 14, 7, 7, -1, [(3, 2, "F1"), (10, 2, "F2")], None),
        (283, 11, 6, 6, 1, [(4, 2, "F2")], None),
        (346, 12, 6, 6, 0, [(3, 2, "F2"), (8, 2, "F2")], 2),
        (360, 10, 12, 11, -1, [(4, 3, "F2", 2, 1), (4, 6, "F2", 2, 1)], None),
        (372, 14, 9, 8, 1, [(3, 3, "F2", 2, 2), (10, 4, "F1")], 11),
        (430, 11, 10, 9, 0, [(3, 3, "F2"), (7, 3, "F2"), (5, 7, "F1")], 7),
        (443, 9, 7, 7, -1, [(4, 2, "F2", 1, 2)], None),
        (455, 14, 11, 10, 1, [(3, 3, "F2", 2, 2), (9, 6, "F2")], 2),
        (472, 10, 8, 7, 0, [(4, 3, "F2")], None),
        (494, 12, 9, 9, -1, [(3, 3, "F1"), (8, 3, "F2", 1, 2)], 9),
    ])
    _bell_tower(p, 256, int(round(far_top(263))) + 3, "N0", "N2")

    # graveyard ground: N1 field from the horizon down
    ground = smooth_noise(rng, 0, W, 64, 1.5)
    ground_top = lambda x: horizon + ground(x)  # noqa: E731
    fill_below(p, ground_top, "N1")
    for x in range(W):
        gy = int(round(ground_top(x)))
        p.put(x, gy, "N0")
        if rng.random() < 0.5:
            p.put(x, gy - 1, "N0")
        if rng.random() < 0.12:
            p.put(x, gy - 2, "N0")

    # little stones peeking over the horizon behind the fence
    for gx, kind in ((140, "small"), (176, "slab"), (214, "small"), (290, "small"), (382, "small"),
                     (418, "slab"), (466, "small"), (500, "round")):
        g = GRAVES[kind]
        p.stamp(g, gx, int(round(ground_top(gx))) - len(g) + 3)

    # crooked fence along the horizon
    fence_base = lambda x: min(97.0, ground_top(x) + 3 + 1.0 * math.sin(x / 53.0))  # noqa: E731
    _fence(p, rng, -6, W + 6, fence_base, broken_at={232, 470})

    # battlefield: N1 with sparse N2 tufts, fewer toward the centre (very low detail)
    for _ in range(170):
        x, y = rng.randrange(128, 512), rng.randrange(106, 268)
        edge = min(x - 128, 512 - x, y - 100, 268 - y)
        if rng.random() * 70 > edge or rng.random() < 0.35:
            tuft = rng.choice(([(0, 0), (2, 0), (1, -1)], [(0, 0), (1, -1)], [(0, 0)],
                               [(0, 0), (2, -1), (3, 0)]))
            for dx, dy in tuft:
                p.put(x + dx, y + dy, "N2")
    # faint grave mounds (N2 top line only)
    for mx, my, mw in ((170, 140, 14), (468, 128, 12), (196, 214, 16), (446, 238, 14), (150, 250, 10),
                       (490, 180, 12)):
        p.hline(mx + 2, mx + mw - 3, my, "N2")
        p.put(mx + 1, my + 1, "N2")
        p.put(mx + mw - 2, my + 1, "N2")

    # outside the battlefield: bigger stones and dead trees at both sides
    for gx, gy, kind, flip in ((20, 140, "big", False), (64, 124, "lean", False), (88, 182, "round", False),
                               (28, 226, "obelisk", False), (70, 262, "slab", False), (10, 284, "small", False),
                               (536, 126, "round", True), (590, 150, "big", True), (560, 210, "lean", True),
                               (612, 240, "obelisk", False), (530, 268, "small", False),
                               (104, 108, "broken", False), (520, 108, "broken", True)):
        g = GRAVES[kind]
        p.stamp(g, gx, gy - len(g), flip=flip)
    dead_tree(p, 46, 116, 46, 7, lean=0.1)
    dead_tree(p, 604, 118, 52, 19, lean=-0.15)

    # foreground grass silhouette along the very bottom (below the battlefield)
    for x in range(W):
        top = 295 + int(2 * math.sin(x / 9.0) + 2 * math.sin(x / 23.0))
        p.vline(x, top, H - 1, "N0")
        if rng.random() < 0.2:
            p.vline(x, top - rng.randint(1, 4), top, "N0")
    return p.image()


# ---------------------------------------------------------------------------------------------
# bg_title — big moon, castle on a crag, bats
# ---------------------------------------------------------------------------------------------

def pumpkin(p: Pic, x: int, y: int, face: str = "grin") -> None:
    """Glowing carved pumpkin (13x10 incl. outline): F0/F1 lobes, F2 face, N0 outline."""
    rows = [
        "......#......",
        "......##.....",
        "..####.####..",
        ".#FFfFFFfFF#.",
        "#FFfggFfggFf#",
        "#FFfggFfggff#",
        "#FFfFFgFFfff#",
        "#FgFgFgFgFff#",
        ".#fggggggff#.",
        "..#########..",
    ] if face == "grin" else [
        "......#......",
        ".....##......",
        "..####.####..",
        ".#FFfFFFfFF#.",
        "#FFgFFfFgFf#.",
        "#FggfFfFggf#.",
        "#FFfFFfFFff#.",
        "#FFgggggFff#.",
        ".#fFgFgFff#..",
        "..########...",
    ]
    p.stamp(rows, x, y)


def _castle(p: Pic, x0: int, base: int) -> None:
    """Castle silhouette (N0) with lit slit windows. Towers: (dx, w, h, roof, roof_h)."""
    k = "N0"
    towers = [
        (0, 14, 46, "cone", 18),
        (12, 34, 34, "crenel", 0),
        (24, 10, 58, "cone", 22),
        (44, 16, 40, "crenel", 0),
        (58, 12, 52, "cone", 16),
        (68, 30, 28, "crenel", 0),
        (94, 11, 44, "cone", 14),
    ]
    for dx, w, h, roof, rh in towers:
        x = x0 + dx
        top = base - h
        p.rect(x, top, w, h + 1, k)
        if roof == "cone":
            p.poly([(x - 2, top + 1), (x + w / 2, top - rh), (x + w + 2, top + 1)], k)
            p.rect(x - 2, top, w + 4, 2, k)       # eave
            p.vline(x + w // 2, top - rh - 5, top - rh, k)  # finial
            p.rect(x + w // 2 + 1, top - rh - 5, 4, 2, k)   # pennant
            p.put(x + w // 2 + 5, top - rh - 4, k)
        else:
            for cx in range(x, x + w, 4):
                p.rect(cx, top - 3, 2, 3, k)
    # windows: slits and one arched lit window
    for wx, wy, h in ((5, -36, 2), (5, -28, 2), (28, -48, 3), (28, -38, 2), (50, -30, 2), (62, -44, 2),
                      (62, -36, 2), (80, -20, 1), (86, -20, 1), (98, -34, 2), (20, -22, 1), (36, -24, 2)):
        for j in range(h):
            p.put(x0 + wx, base + wy + j, "F2")
    p.rect(x0 + 27, base - 30, 3, 3, "F1")
    p.put(x0 + 28, base - 31, "F1")
    # gate
    p.rect(x0 + 40, base - 9, 6, 9, "N1")
    p.hline(x0 + 41, x0 + 44, base - 10, "N1")


def bg_title():
    rng = random.Random("bg_title")
    p = Pic(W, H)
    sky(p, [(0, "N0"), (34, "N0"), (70, "N1"), (150, "N1"), (210, "N2"), (300, "N2")], seed=11)
    sky_keys = {"N0", "N1", "N2"}

    mcx, mcy, mr = 478, 96, 38
    moon(p, mcx, mcy, mr, [(-14, -10, 5), (8, -18, 3), (12, 6, 6), (-8, 14, 3), (-20, 4, 2), (20, -6, 2),
                           (0, 24, 2), (-4, -24, 2)], glow="N2", base_sky="N1", glow_w=12)
    calm = lambda x, y: (236 <= x <= 404 and 50 <= y <= 232)  # noqa: E731
    stars(p, rng, 120, (0, 0, W, 200), sky_keys,
          avoid=lambda x, y: math.hypot(x - mcx, y - mcy) < mr + 16 or calm(x, y), bright=6)
    cloud(p, 430, 120, [(0, 0, 3), (12, -2, 4), (26, 0, 3), (38, 2, 2)], "N2", "N3")
    cloud(p, 120, 70, [(0, 0, 2), (10, -1, 3), (20, 0, 2)], "N1", "N2")
    cloud(p, 560, 40, [(0, 0, 2), (8, -1, 2)], "N1", "N2")

    # far hills (N1) across the bottom third
    far = smooth_noise(rng, 0, W, 60, 6)
    far_top = lambda x: 214 + far(x) - 10 * math.exp(-((x - 150) / 70.0) ** 2)  # noqa: E731
    fill_below(p, far_top, "N1")
    for _ in range(30):
        tx = rng.randrange(0, W)
        if 230 < tx < 410:
            continue
        ty = int(round(far_top(tx)))
        th = rng.randint(6, 12)
        for j in range(th):
            half = (j * 3) // th
            p.hline(tx - half, tx + half, ty - th + j + 1, "N1")

    # crag + castle on the right, overlapping the moon's lower half
    crag = [(404, 300), (420, 230), (430, 214), (446, 196), (456, 176), (470, 160), (520, 158), (536, 166),
            (548, 172), (562, 190), (580, 204), (600, 226), (622, 240), (640, 252), (640, 300)]
    p.poly(crag, "N0")
    for (ax, ay), (bx, by) in zip(crag[1:6], crag[2:7]):
        p.line(ax, ay, bx, by, "N1")  # moonlit crag edge (left side faces the light)
    _castle(p, 452, 162)
    p.rect(538, 168, 40, 3, "N0")  # bridge

    # bats: a pair across the moon, a trail heading up-left above the logo
    for bx, by, b in ((456, 76, BAT_A), (498, 106, BAT_B), (482, 70, BAT_SMALL), (424, 64, BAT_SMALL),
                      (414, 92, BAT_A), (520, 126, BAT_SMALL), (186, 112, BAT_B), (150, 130, BAT_SMALL),
                      (210, 140, BAT_SMALL), (120, 100, BAT_A)):
        p.stamp(b, bx, by)

    # left: graveyard hill with a big dead tree
    hill = lambda x: 250 - 40 * math.exp(-((x - 140) / 95.0) ** 2) + 2 * math.sin(x / 17.0)  # noqa: E731
    fill_below(p, hill, "N0")
    near = smooth_noise(rng, 0, W, 50, 3)
    near_top = lambda x: 262 + near(x) + 6 * math.sin(x / 110.0)  # noqa: E731
    fill_below(p, near_top, "N0")
    dead_tree(p, 150, int(hill(150)) + 2, 84, 33, lean=0.1)
    for gx, kind in ((96, "round"), (118, "slab"), (186, "lean"), (214, "small"), (70, "obelisk")):
        g = GRAVES[kind]
        p.stamp(g, gx, int(round(hill(gx + 4))) - len(g) + 3)
    pumpkin(p, 196, int(hill(202)) - 6)
    pumpkin(p, 566, 262, face="sly")
    for x in range(W):
        y = int(round(near_top(x)))
        if rng.random() < 0.3:
            p.vline(x, y - rng.randint(1, 3), y, "N0")
    return p.image()


# ---------------------------------------------------------------------------------------------
# bg_shop — crypt interior: arcade of pillars, niches with shelves, candles
# ---------------------------------------------------------------------------------------------

CANDLE_TALL = [
    ".g.",
    ".F.",
    ".#.",
    "cBb",
    "cBb",
    "cBb",
    "cBb",
    "cBb",
    "cBb",
    "cBb",
]
CANDLE = [
    ".g.",
    ".F.",
    "cBb",
    "cBb",
    "cBb",
    "cBb",
]
CANDLE_STUB = [
    "g..",
    "F..",
    "cBb",
    "cBb",
]
CANDLE_DRIP = [
    "..g..",
    "..F..",
    ".cBb.",
    ".cBb.",
    "ccBbb",
]
SHELF_ITEMS = {
    "jar": [
        ".####.",
        "..#3..",
        ".#443#",
        "#43332#",
        "#43332#",
        "#43322#",
        ".#####.",
    ],
    "bottle": [
        ".#.",
        ".3.",
        "#43#",
        "#432#",
        "#432#",
        "####",
    ],
    "skull": [
        ".####.",
        "#BcBB#",
        "#c#B##",
        "#BBbB#",
        ".#bb#.",
    ],
    "books": [
        "##.##..",
        "#4#3#.#",
        "#4#3##3#",
        "#4#3#33#",
        "#3#2#32#",
        "########",
    ],
    "urn": [
        "..##..",
        ".#33#.",
        "#4332#",
        "#43322#",
        ".#332#",
        "..###.",
    ],
    "box": [
        "#######",
        "#44333#",
        "#3#2#2#",
        "#######",
    ],
}


def _brick_wall(p: Pic, rng: random.Random, x0: int, y0: int, x1: int, y1: int) -> list[tuple]:
    """Running-bond stone blocks; returns the block rects (x, y, w, h) for lighting."""
    row_h = 9
    blocks = []
    y = y0
    while y < y1:
        x = x0 - rng.randint(0, 20)
        while x < x1:
            bw = rng.randint(14, 26)
            lit = rng.random() < 0.55
            for yy in range(y, min(y + row_h, y1)):
                for xx in range(x, x + bw):
                    if x0 <= xx < x1:
                        k = "N1"
                        if yy == y + row_h - 1 or xx == x + bw - 1:
                            k = "N0"
                        elif yy == y and lit:
                            k = "N2"
                        p.put(xx, yy, k)
            if rng.random() < 0.12:  # crack
                cx, cy = x + rng.randint(3, bw - 4), y + 1
                for _ in range(rng.randint(3, 6)):
                    p.put(cx, cy, "N0")
                    cx += rng.choice((-1, 0, 1))
                    cy += 1
                    if cy >= y + row_h - 1:
                        break
            if rng.random() < 0.08:  # chipped corner
                p.put(x, y, "N0")
                p.put(x + 1, y, "N0")
                p.put(x, y + 1, "N0")
            blocks.append((x, y, bw, row_h))
            x += bw
        y += row_h
    return blocks


def _pillar(p: Pic, cx: int, top: int, bottom: int) -> None:
    w = 16
    x = cx - w // 2
    p.rect(x, top, w, bottom - top, "N2")
    p.vline(x, top, bottom, "N0")
    p.vline(x + w - 1, top, bottom, "N0")
    p.vline(x + 1, top, bottom, "N3")
    p.vline(x + w - 3, top, bottom, "N1")
    p.vline(x + w - 2, top, bottom, "N1")
    for yy in range(top + 14, bottom, 14):  # stone courses
        p.hline(x + 1, x + w - 2, yy, "N1")
    for yy, ww in ((top, w + 6), (top + 3, w + 2)):  # capital
        p.rect(cx - ww // 2, yy, ww, 3, "N2")
        p.hline(cx - ww // 2, cx - ww // 2 + ww - 1, yy, "N3")
        p.hline(cx - ww // 2, cx - ww // 2 + ww - 1, yy + 3, "N0")
        p.vline(cx - ww // 2 - 1, yy, yy + 3, "N0")
        p.vline(cx - ww // 2 + ww, yy, yy + 3, "N0")
    p.rect(cx - (w + 6) // 2, bottom - 5, w + 6, 5, "N2")  # base
    p.hline(cx - (w + 6) // 2, cx + (w + 6) // 2 - 1, bottom - 5, "N3")
    p.hline(cx - (w + 6) // 2 - 1, cx + (w + 6) // 2, bottom - 6, "N0")


def _arch(p: Pic, cx: int, spring: int, half: int, band: int = 5) -> None:
    """Rib between two pillars; the vault above it is in shadow (N0)."""
    ry = half * 0.62
    for y in range(0, spring + 1):
        for x in range(cx - half, cx + half + 1):
            dx, dy = x - cx, spring - y
            d = math.hypot(dx, dy * half / ry)
            if d >= half:
                p.put(x, y, "N0")
            elif d >= half - band:
                k = "N2"
                if d < half - band + 1:
                    k = "N0"
                elif d >= half - 1:
                    k = "N3" if dx < 0 else "N1"
                p.put(x, y, k)


def _niche(p: Pic, rng: random.Random, cx: int, top: int, bottom: int, half: int, shelves: list[int]) -> None:
    mask = set()
    for y in range(top - half, bottom):
        for x in range(cx - half, cx + half + 1):
            if y >= top or (x - cx) ** 2 + ((top - y) * 1.4) ** 2 <= half * half:
                mask.add((x, y))
    for (x, y) in mask:
        p.put(x, y, "N0")
    # frame ring: lit on the left / top, shaded on the right
    ring = {(x + dx, y + dy) for (x, y) in mask for dx in (-1, 0, 1) for dy in (-1, 0)} - mask
    for (x, y) in ring:
        if y < bottom:
            p.put(x, y, "N3" if x < cx else "N2")
    for sy in shelves:
        p.hline(cx - half, cx + half, sy, "N3")
        p.hline(cx - half, cx + half, sy + 1, "N2")
        p.hline(cx - half, cx + half, sy + 2, "N1")
        x = cx - half + 2
        while x < cx + half - 6:
            kind = rng.choice(list(SHELF_ITEMS) + ["candle", "gap"])
            if kind == "gap":
                x += rng.randint(3, 6)
                continue
            g = rng.choice((CANDLE, CANDLE_STUB, CANDLE_DRIP)) if kind == "candle" else SHELF_ITEMS[kind]
            gw = max(len(r) for r in g)
            if x + gw > cx + half - 1:
                break
            p.stamp(g, x, sy - len(g))
            x += gw + rng.randint(1, 3)


def _coffin(p: Pic, cx: int, bottom: int, h: int = 60) -> None:
    """Standing coffin: hexagonal lid, lit left edge, lid inset, small bone plaque."""
    w_sh = 13          # half width at the shoulders
    w_top, w_bot = 8, 9
    sh = h // 4
    rows = []
    for j in range(h):
        if j < sh:
            hw = w_top + (w_sh - w_top) * j / sh
        else:
            hw = w_sh - (w_sh - w_bot) * (j - sh) / (h - sh)
        rows.append(int(round(hw)))
    y0 = bottom - h
    for j, hw in enumerate(rows):
        y = y0 + j
        for x in range(cx - hw, cx + hw + 1):
            p.put(x, y, "N2")
        p.put(cx - hw, y, "N0")
        p.put(cx + hw, y, "N0")
        p.put(cx - hw + 1, y, "N3")
        p.put(cx + hw - 1, y, "N1")
        if 3 <= j < h - 3:   # lid inset
            p.put(cx - hw + 3, y, "N1")
            p.put(cx + hw - 3, y, "N1")
    p.hline(cx - rows[0], cx + rows[0], y0, "N0")
    p.hline(cx - rows[0] + 1, cx + rows[0] - 1, y0 + 1, "N3")
    p.hline(cx - rows[-1], cx + rows[-1], bottom - 1, "N0")
    p.hline(cx - rows[3] + 3, cx + rows[3] - 3, y0 + 3, "N1")
    p.hline(cx - rows[-4] + 3, cx + rows[-4] - 3, bottom - 4, "N1")
    p.stamp(SHELF_ITEMS["skull"], cx - 3, y0 + sh - 1)


def _oculus(p: Pic, cx: int, cy: int, r: int) -> None:
    """Round wall niche with a bone skull inside."""
    for y in range(cy - r - 1, cy + r + 2):
        for x in range(cx - r - 1, cx + r + 2):
            d = math.hypot(x - cx, y - cy)
            if d <= r:
                p.put(x, y, "N0")
            elif d <= r + 1.2:
                p.put(x, y, "N3" if (x - cx) + (y - cy) < 0 else "N2")
    p.stamp(SHELF_ITEMS["skull"], cx - 3, cy - 2)


def _warm_light(p: Pic, blocks: list[tuple], cx: int, cy: int, r: int) -> None:
    """Candle light picked out block by block: faces of nearby blocks N1 -> N2, the closest
    blocks also get an N3 top edge. Only untouched wall pixels change."""
    for bx, by, bw, bh in blocks:
        mx, my = bx + bw / 2, by + bh / 2
        d = math.hypot(mx - cx, (my - cy) * 1.3)
        if d > r:
            continue
        for y in range(by, by + bh - 1):
            for x in range(bx, bx + bw - 1):
                k = p.get(x, y)
                if y == by and k == "N2" and d < r * 0.5:
                    p.put(x, y, "N3")
                elif k == "N1" and y > by:
                    p.put(x, y, "N2")
                elif k == "N1" and y == by:
                    p.put(x, y, "N3" if d < r * 0.5 else "N2")


def _sconce(p: Pic, cx: int, y: int) -> None:
    p.stamp([
        ".g.",
        ".F.",
        "cBb",
        "cBb",
        "#3#",
        ".##",
        "..#",
    ], cx - 1, y)
    p.hline(cx - 2, cx + 2, y + 4, "N0")
    p.hline(cx - 1, cx + 1, y + 4, "N3")


def _chain(p: Pic, x: int, y0: int, length: int) -> None:
    for j in range(length):
        if j % 3 == 0:
            p.put(x - 1, y0 + j, "N2")
            p.put(x + 1, y0 + j, "N2")
        else:
            p.put(x, y0 + j, "N3" if j % 3 == 1 else "N2")


def _cobweb(p: Pic, x: int, y: int, size: int, flip: bool) -> None:
    s = -1 if flip else 1
    for i in range(size):
        p.put(x + s * i, y, "N3")
        p.put(x, y + i, "N3")
        if i < size * 0.7:
            p.put(x + s * i, y + i, "N3")
    for r in (size // 3, (2 * size) // 3):
        for t in range(r + 1):
            p.put(x + s * t, y + r - t, "N3")


def bg_shop():
    rng = random.Random("bg_shop")
    p = Pic(W, H, "N1")
    floor_y = 258
    blocks = _brick_wall(p, rng, 0, 0, W, floor_y)
    spring = 70
    # bay centres between pillars at x = 0, 128, ... 640; each bay gets its own dressing
    bays = [(64, "shelves", 126, [156, 190]), (192, "coffin", 0, []), (320, "shelves", 132, [168, 204]),
            (448, "shelves", 122, [150, 182, 214]), (576, "coffin", 0, [])]
    for cx, *_ in bays:
        _arch(p, cx, spring, 64)
    for cx, kind, top, shelves in bays:
        if kind == "shelves":
            _niche(p, rng, cx, top, floor_y - 30, 28 if len(shelves) < 3 else 30, shelves)
            p.rect(cx - 24, floor_y - 22, 49, 20, "N0")      # low recess with a candle row
            p.hline(cx - 24, cx + 24, floor_y - 2, "N3")
            p.hline(cx - 24, cx + 24, floor_y - 1, "N2")
            x = cx - 20
            for g in rng.sample([CANDLE, CANDLE_STUB, CANDLE_TALL, SHELF_ITEMS["skull"], SHELF_ITEMS["urn"],
                                 CANDLE_DRIP], 4):
                p.stamp(g, x, floor_y - 2 - len(g))
                x += max(len(r) for r in g) + rng.randint(3, 6)
        else:
            _oculus(p, cx, 128, 9)
            _coffin(p, cx, floor_y - 1)
            p.stamp(CANDLE_TALL, cx - 18, floor_y - len(CANDLE_TALL) - 1)
            p.stamp(CANDLE_DRIP, cx + 13, floor_y - len(CANDLE_DRIP) - 1)
            p.stamp(CANDLE_STUB, cx + 19, floor_y - len(CANDLE_STUB) - 1)
    for px_ in range(0, W + 1, 128):
        _warm_light(p, blocks, px_, 142, 26)
    for px_ in range(0, W + 1, 128):
        _pillar(p, px_, spring - 4, floor_y)
        _sconce(p, px_, 138)
    for cx, kind, *_ in bays:
        _chain(p, cx + rng.choice((-18, 14, 22)), 0, rng.randint(22, 40))
        _cobweb(p, cx - 54, spring - 34, 9, False)
        _cobweb(p, cx + 54, spring - 34, 9, True)

    # floor: flagstones in rough perspective
    p.rect(0, floor_y, W, H - floor_y, "N1")
    p.hline(0, W, floor_y, "N2")
    ys = [floor_y + 1, floor_y + 8, floor_y + 17, floor_y + 28, H]
    for i, (ya, yb) in enumerate(zip(ys, ys[1:])):
        p.hline(0, W, ya, "N0")
        step = 22 + 8 * i
        off = rng.randint(0, step)
        for sx in range(-off, W, step):
            x = sx + rng.randint(-3, 3)
            p.vline(x, ya, yb, "N0")
            p.put(x + 1, ya + 1, "N2")
    # bone heap in one corner, candle stubs scattered
    p.stamp([
        "....####.......",
        "..##BcB#.####..",
        ".#cBB##B#cBBb#.",
        "#BcbBcBBBbcBBb#",
        "###############",
    ], 600, floor_y + 6)
    for cx in (128, 256, 384, 512):
        p.stamp(CANDLE, cx + 13, floor_y + 6 - len(CANDLE))
        p.stamp(CANDLE_STUB, cx + 17, floor_y + 6 - len(CANDLE_STUB))
    return p.image()


# ---------------------------------------------------------------------------------------------
# bg_map — winding village road with three lantern posts along the bottom
# ---------------------------------------------------------------------------------------------

def _lantern_post(p: Pic, x: int, lamp_top: int, ground: int) -> None:
    """Lantern (9x11) on a 2 px post from lamp_top down to `ground`, centred on x."""
    p.stamp(LANTERN, x - 4, lamp_top)
    for y in range(lamp_top + 11, ground):
        p.put(x - 2, y, "N0")
        p.put(x - 1, y, "N3")
        p.put(x, y, "N2")
        p.put(x + 1, y, "N0")
    p.stamp(["..##..", ".#32#.", "#3322#", "######"], x - 3, ground - 3)


def bg_map():
    rng = random.Random("bg_map")
    p = Pic(W, H)
    sky(p, [(0, "N0"), (16, "N0"), (40, "N1"), (60, "N1"), (84, "N2"), (300, "N2")], seed=5)
    sky_keys = {"N0", "N1", "N2"}
    stars(p, rng, 100, (0, 0, W, 76), sky_keys, bright=5)

    far = smooth_noise(rng, 0, W, 50, 5)
    far_top = lambda x: 84 + far(x) + 4 * math.sin(x / 70.0)  # noqa: E731
    fill_below(p, far_top, "N1")
    _village(p, rng, far_top, [
        (60, 12, 9, 8, 0, [(3, 3, "F2"), (8, 3, "F2")], 2),
        (300, 14, 10, 9, 1, [(3, 3, "F2", 2, 2), (9, 4, "F1")], 10),
        (316, 10, 7, 8, 0, [(4, 2, "F2")], None),
        (332, 12, 12, 10, -1, [(3, 3, "F2"), (8, 3, "F2"), (5, 8, "F2")], 2),
        (520, 12, 9, 7, 0, [(4, 3, "F2", 1, 2)], 9),
    ])
    _bell_tower(p, 286, int(round(far_top(293))) + 3, "N0", "N2")

    # fields: N1 with N2 furrows
    near = smooth_noise(rng, 0, W, 40, 2)
    ground_top = lambda x: 96 + near(x)  # noqa: E731
    fill_below(p, ground_top, "N1")
    for hy, amp, ph in ((128, 6, 0.3), (170, 8, 1.7), (214, 7, 2.9)):  # hedgerows between fields
        for x in range(W):
            y = int(hy + amp * math.sin(x / 60.0 + ph))
            p.put(x, y, "N0")
            if rng.random() < 0.55:
                p.put(x, y - 1, "N0")
            if rng.random() < 0.08:
                p.vline(x, y - 3, y, "N0")
    for _ in range(260):
        x, y = rng.randrange(0, W), rng.randrange(100, 250)
        if p.get(x, y) == "N1":
            p.put(x, y, "N2")

    # the road winds up from the bottom band to the village on the horizon
    def road_centre(y: float) -> float:
        t = (y - 92) / (300 - 92)
        return 320 + 140 * math.sin(t * 3.4 + 0.6) * t

    for y in range(int(ground_top(320)), 280):
        c, hw = road_centre(y), 2 + (y - 92) * 0.09
        for x in range(int(c - hw), int(c + hw) + 1):
            p.put(x, y, "N2")
        p.put(int(c - hw) - 1, y, "N3")
        p.put(int(c + hw) + 1, y, "N0")
    # bottom band: the road runs left -> right past the three lantern posts
    band = lambda x: 285 + 4 * math.sin((x - 40) / 70.0)  # noqa: E731
    for x in range(-2, W + 2):
        c = band(x)
        for y in range(int(c - 8), int(c + 8) + 1):
            p.put(x, y, "N2")
        p.put(x, int(c - 9), "N3")
        p.put(x, int(c + 9), "N0")
    for x in range(W):  # wheel ruts
        c = band(x)
        if (x // 3) % 4:
            p.put(x, int(c - 3), "N1")
            p.put(x, int(c + 4), "N1")
    for _ in range(140):  # cobbles
        x = rng.randrange(0, W)
        y = int(band(x)) + rng.randint(-7, 7)
        if p.get(x, y) == "N2":
            p.put(x, y, "N3")
            p.put(x + 1, y, "N1")
    for x in range(W):  # verge below the road
        c = int(band(x)) + 10
        for y in range(c, H):
            p.put(x, y, "N1")
        if rng.random() < 0.35:
            p.vline(x, c - rng.randint(1, 3), c, "N0")
    for x in range(W):  # tufts above the road
        c = int(band(x)) - 10
        if rng.random() < 0.3:
            p.vline(x, c - rng.randint(1, 3), c, "N0")

    # lantern posts under the three encounter cards (base x 8/164/320 + 80 -> centres 164/320/476)
    for lx in (164, 320, 476):
        g = int(band(lx)) - 9
        _lantern_post(p, lx, 255, g)
        for x in range(lx - 10, lx + 11):  # flat warm pool on the road below the lamp
            for y in range(g + 2, g + 8):
                if ((x - lx) / 10.0) ** 2 + ((y - g - 5) / 3.0) ** 2 <= 1 and p.get(x, y) in ("N2", "N1"):
                    p.put(x, y, "N3")
    pumpkin(p, 236, int(band(236)) - 22)
    pumpkin(p, 404, int(band(404)) - 21, face="sly")
    for gx, kind in ((90, "small"), (560, "round"), (612, "slab")):
        g = GRAVES[kind]
        p.stamp(g, gx, int(band(gx)) - 10 - len(g) + 2)
    dead_tree(p, 40, int(band(40)) - 10, 40, 19, lean=0.1)
    return p.image()


# ---------------------------------------------------------------------------------------------
# logo — "RATTLE & ROLL": hand-drawn bold letters (F1 body, F2 top light, F0 underside),
# a bone across the middle, the O of ROLL is a skull-faced die. N0 outline + 1 px drop shadow.
# ---------------------------------------------------------------------------------------------

LETTERS = {
    "R": [
        "############..",
        "#############.",
        "##############",
        "####......####",
        "####......####",
        "####......####",
        "####.....#####",
        "#############.",
        "############..",
        "##########....",
        "####...####...",
        "####....####..",
        "####....####..",
        "####.....####.",
        "####.....####.",
        "####......####",
        "####......####",
        "####......####",
    ],
    "A": [
        "...########...",
        "..##########..",
        ".############.",
        "#####....#####",
        "####......####",
        "####......####",
        "####......####",
        "####......####",
        "##############",
        "##############",
        "##############",
        "####......####",
        "####......####",
        "####......####",
        "####......####",
        "####......####",
        "####......####",
        "####......####",
    ],
    "T": [
        "##############",
        "##############",
        "##############",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
        ".....####.....",
    ],
    "L": [
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "############",
        "############",
        "############",
    ],
    "E": [
        "############",
        "############",
        "############",
        "####........",
        "####........",
        "####........",
        "####........",
        "##########..",
        "##########..",
        "##########..",
        "####........",
        "####........",
        "####........",
        "####........",
        "####........",
        "############",
        "############",
        "############",
    ],
    "&": [
        "....#####.....",
        "...#######....",
        "..####.####...",
        "..###...###...",
        "..###..####...",
        "..########....",
        "...######.....",
        "..########.###",
        ".####.####.###",
        "####...######.",
        "####....####..",
        "####....#####.",
        "####...#######",
        ".############.",
        "..#######..###",
    ],
}

# skull-faced die (the O of ROLL): B2 face, B1 inner bevel, B0 side (matches dice/die_body)
DIE_O = [
    ".cccccccccccccccc.",
    "ccccccccccccccccBc",
    "ccccccccccccccccBc",
    "cccc##cccccc##ccBc",
    "ccc#7##cccc#7##cBc",
    "ccc####cccc####cBc",
    "ccc####cccc####cBc",
    "cccc##cccccc##ccBc",
    "ccccccccccccccccBc",
    "ccccccc####cccccBc",
    "cccccccc##ccccccBc",
    "ccccccccccccccccBc",
    "ccccc#######ccccBc",
    "ccccc#c#c#c#ccccBc",
    "cBBBBBBBBBBBBBBBBc",
    "bbbbbbbbbbbbbbbbbb",
    ".bbbbbbbbbbbbbbbb.",
]

BONE_END = [
    ".##....",
    "####...",
    "#####..",
    ".######",
    "..#####",
    "..#####",
    ".######",
    "#####..",
    "####...",
    ".##....",
]


def _mask(rows: list[str]) -> set[tuple[int, int]]:
    return {(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == "#"}


def _shade(p: Pic, mask: set, ox: int, oy: int, light: str, mid: str, dark: str) -> None:
    """Top edge light, underside dark, rest mid (light from the top-left)."""
    for (x, y) in mask:
        k = mid
        if (x, y - 1) not in mask:
            k = light
        elif (x, y + 1) not in mask:
            k = dark
        elif (x - 1, y) not in mask and (x, y - 2) not in mask:
            k = light
        p.put(ox + x, oy + y, k)


def _ring(p: Pic, painted: set, k: str = "N0", shadow: bool = True) -> None:
    ring = {(x + dx, y + dy) for (x, y) in painted for dx in (-1, 0, 1) for dy in (-1, 0, 1)} - painted
    for (x, y) in ring:
        p.put(x, y, k)
    if shadow:
        body = painted | ring
        for (x, y) in body:
            if (x, y + 1) not in body:
                p.put(x, y + 1, k)


def logo():
    p = Pic(160, 48)
    # a long bone across the middle, behind both lines
    bone_y, bx0, bx1 = 17, 4, 155
    bone = Pic(160, 48)
    bone.stamp(BONE_END, bx0, bone_y)
    bone.stamp([r[::-1] for r in BONE_END], bx1 - 6, bone_y)
    bone.rect(bx0 + 7, bone_y + 3, bx1 - bx0 - 13, 4, "B1")
    bmask = {(x, y) for y in range(48) for x in range(160) if bone.get(x, y)}
    _ring(p, bmask, shadow=True)
    _shade(p, bmask, 0, 0, "B2", "B1", "B0")
    for x, y in ((24, 21), (25, 22), (26, 22), (134, 22), (135, 21), (136, 22)):  # nicks in the shaft
        p.put(x, y, "B0")

    def word(items: list[tuple], y0: int) -> None:
        painted: set = set()
        for kind, x, dy in items:
            m = ({(i, j) for j, r in enumerate(DIE_O) for i, ch in enumerate(r) if ch != "."}
                 if kind == "O" else _mask(LETTERS[kind]))
            painted |= {(x + i, y0 + dy + j) for (i, j) in m}
        _ring(p, painted)
        for kind, x, dy in items:
            y = y0 + dy
            if kind == "O":
                p.stamp(DIE_O, x, y)
            elif kind == "&":
                _shade(p, _mask(LETTERS["&"]), x, y, "B2", "B1", "B0")
            else:
                _shade(p, _mask(LETTERS[kind]), x, y, "F2", "F1", "F0")

    # line 1: RATTLE, letters bounce +-1 px (it rattles)
    word([("R", 32, 0), ("A", 49, -1), ("T", 66, 1), ("T", 83, 0), ("L", 100, -1), ("E", 115, 1)], 2)
    # line 2: & ROLL, the die-O sits a little higher, mid-roll
    word([("&", 37, 2), ("R", 56, 0), ("O", 73, -2), ("L", 95, 1), ("L", 110, 0)], 27)
    return p.image()


# ---------------------------------------------------------------------------------------------
# app icon — a skull-faced die with glowing eyes (32x32)
# ---------------------------------------------------------------------------------------------

APP_ICON = [
    "................................",
    "................................",
    "..############################..",
    ".#cccccccccccccccccccccccccccc#.",
    "#ccccccccccccccccccccccccccccBc#",
    "#ccBcccccccccccccccccccccccccBc#",
    "#cccBccccccccccccccccccccccccBc#",
    "#ccccBBccccccccccccccccccccccBc#",
    "#ccccccc#####cccccc#####cccccBc#",
    "#cccccc#######cccc#######ccccBc#",
    "#ccccc###gg####cc###gg####cccBc#",
    "#ccccc###gF####cc###gF####cccBc#",
    "#ccccc#########cc#########cccBc#",
    "#ccccc#########cc#########cccBc#",
    "#cccccc#######cccc#######ccccBc#",
    "#ccccccc#####cccccc#####cccccBc#",
    "#ccccccccccccccccccccccccccccBc#",
    "#ccccccccccccc####cccccccccccBc#",
    "#cccccccccccccc##ccccccccccccBc#",
    "#ccccccccccccccccccccccccccccBc#",
    "#ccccccc################cccccBc#",
    "#ccccccc#cc#cc#cc#cc#cc#cccccBc#",
    "#ccccccc#cc#cc#cc#cc#cc#cccccBc#",
    "#cccccccc##############ccccccBc#",
    "#ccccccccccccccccccccccccccccBc#",
    "#cBBBBBBBBBBBBBBBBBBBBBBBBBBBBc#",
    "#bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#",
    "#bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#",
    "#bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb#",
    ".#bbbbbbbbbbbbbbbbbbbbbbbbbbbb#.",
    "..############################..",
    "................................",
]


def app_icon_32():
    return grid(APP_ICON, width=32)


# ---------------------------------------------------------------------------------------------
# stamp_defeated — R1 rubber stamp, double border, pre-rotated (staircase shear, ~6 deg)
# ---------------------------------------------------------------------------------------------

STAMP_FONT = {
    "D": ["####.", "##.##", "##.##", "##.##", "##.##", "##.##", "####."],
    "E": ["#####", "##...", "##...", "####.", "##...", "##...", "#####"],
    "F": ["#####", "##...", "##...", "####.", "##...", "##...", "##..."],
    "A": [".###.", "##.##", "##.##", "#####", "##.##", "##.##", "##.##"],
    "T": ["#####", ".###.", ".###.", ".###.", ".###.", ".###.", ".###."],
}


def stamp_defeated():
    """Flat 60x15 stamp, then a staircase shear that steps up 1 px in each letter gap (~5 deg)."""
    flat = Pic(60, 15)
    for x in range(60):          # outer border
        flat.put(x, 0, "R1")
        flat.put(x, 14, "R1")
    for y in range(15):
        flat.put(0, y, "R1")
        flat.put(59, y, "R1")
    for x in range(2, 58):       # inner border
        flat.put(x, 2, "R1")
        flat.put(x, 12, "R1")
    for y in range(2, 13):
        flat.put(2, y, "R1")
        flat.put(57, y, "R1")
    for x, y in ((9, 0), (10, 0), (27, 14), (44, 0), (52, 14), (53, 14), (0, 6), (59, 9), (33, 2),
                 (48, 12), (15, 12), (57, 5)):
        flat.px[y][x] = None     # worn ink
    x = 6
    for ch in "DEFEATED":
        flat.stamp(STAMP_FONT[ch], x, 4, {"#": "R1"})
        x += 6
    steps = (5, 17, 29, 41, 53)  # letter gaps after E, E, T, after the text
    out = Pic(64, 20)
    for y in range(15):
        for x in range(60):
            k = flat.px[y][x]
            if k:
                out.put(x + 2, y + 5 - sum(1 for s_ in steps if x >= s_), k)
    return out.image()


# ---------------------------------------------------------------------------------------------
# VFX (ART_SPEC §10) — every frame a hand-placed grid
# ---------------------------------------------------------------------------------------------

def spark():
    return grid([
        ".WW.",
        "WWWW",
        "WWWW",
        ".WW.",
    ], {"W": "#ffffff"})


PUFF_FRAMES = [
    [
        "........",
        "........",
        "...77...",
        "..7776..",
        "..7665..",
        "...55...",
        "........",
        "........",
    ],
    [
        "...77...",
        ".77776..",
        "7777666.",
        "77766665",
        ".7666655",
        ".6665555",
        "..555...",
        "........",
    ],
    [
        ".77..7..",
        "7766.766",
        "766..665",
        ".6....5.",
        "..7...7.",
        ".766.765",
        ".655.55.",
        "........",
    ],
    [
        "........",
        ".7....7.",
        ".65...5.",
        "........",
        "........",
        ".6...6..",
        "..5..5..",
        "........",
    ],
]

COIN_FRAMES = [
    [
        ".oooo.",
        "o7OOOo",
        "oOOoOo",
        "oOOoOo",
        "oOOOoo",
        ".oooo.",
    ],
    [
        "..ooo.",
        ".o7Oo.",
        ".oOOo.",
        ".oOOo.",
        ".oOoo.",
        "..ooo.",
    ],
    [
        "..oo..",
        "..7o..",
        "..Oo..",
        "..Oo..",
        "..Oo..",
        "..oo..",
    ],
    [
        ".ooo..",
        ".oOOo.",
        ".oOOo.",
        ".oOOo.",
        ".oooo.",
        ".ooo..",
    ],
]

SOUL_FRAMES = [
    [
        "..77..",
        ".7jj7.",
        ".7jjj.",
        "..jjI.",
        "...jI.",
        "..I...",
    ],
    [
        "..77..",
        ".7jj7.",
        ".jjj7.",
        ".Ijj..",
        ".Ij...",
        "...I..",
    ],
]


SLASH_FRAMES = [
    [
        "................",
        "..............7.",
        ".............77.",
        "............57..",
        "...........577..",
        "...........577..",
        "...........77...",
        "...........77...",
        "...........7....",
        "...........7....",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
    ],
    [
        "................",
        "................",
        "..............7.",
        "............57..",
        "...........577..",
        "..........5577..",
        "........55577...",
        ".......555677...",
        "......555677....",
        "......556777....",
        ".....556777.....",
        "....557777......",
        "...57777........",
        "...777..........",
        "..7.............",
        "................",
    ],
    [
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        ".......5777.....",
        "......77.7......",
        "...5777.........",
        "..7777..........",
        ".7..............",
        "................",
    ],
]

RING_FRAMES = [
    [
        "................",
        "................",
        "................",
        "................",
        ".......66.......",
        ".....667766.....",
        ".....677776.....",
        "....677gg776....",
        "....677gg776....",
        ".....677776.....",
        ".....667766.....",
        ".......66.......",
        "................",
        "................",
        "................",
        "................",
    ],
    [
        "................",
        "................",
        "......6666......",
        "....66777766....",
        "...6677777766...",
        "...677....776...",
        "..677......776..",
        "..677......776..",
        "..677......776..",
        "..677......776..",
        "...677....776...",
        "...6677777766...",
        "....66777766....",
        "......6666......",
        "................",
        "................",
    ],
    [
        "......55........",
        "....5556655.....",
        "...566....665...",
        "..5.............",
        ".56..........65.",
        ".56.............",
        "5.............55",
        "5.............65",
        "56............65",
        "55............5.",
        ".56..........65.",
        ".56..........65.",
        "..56........65..",
        "...566....6.5...",
        "....5.5.6555....",
        "......5555......",
    ],
]

AURA_FRAMES = [
    [
        "......................r.................",
        "......................r.................",
        "......................r.................",
        "............r........rRr................",
        ".........r..r........rRr................",
        "............rr..r...rRRr....r...........",
        "...........rRr..rr..rRRRr.r.............",
        "...........rRRrrRRr.rRRRRrr.............",
        "...........rRRRRRRRrRRRRRRRr.....r......",
        "..........rRRRRRRRRRRRRRRRRr....r.......",
        "..........rRRRRRRRRRRRRRRRRRr..rr.......",
        "..........rRRRRRRRRRRRRRRRRRr.rRr.......",
        ".........rRRRRR.........RRRRRrRRr.......",
        ".......rrRRRR.............RRRRRRr.......",
        "......rRRRRR...............RRRRRRr......",
        "......rRRRR.................RRRRRr......",
        "......rRRR...................RRRRr......",
        ".....rRRR.....................RRRr......",
        ".....rRRR.....................RRRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        "......rRR.....................RRr.......",
        "......rRR.....................RRr.......",
        "......rRRR...................RRRr.......",
        ".......rRRR.................RRRr........",
        "........rRRR...............RRRr.........",
        ".........rRRR.............RRRr..........",
        "..........rRRRR.........RRRRr...........",
        "...........rRRRRRRRRRRRRRRRr............",
        "............rrrRRRRRRRRRrrr.............",
        "...............rrrrrrrrr................",
        "........................................",
    ],
    [
        "........................................",
        "........................................",
        "........................................",
        "..........r......r...r..................",
        ".................r...r.......r..........",
        "...........r....rRr.rRr....r............",
        "...........rr...rRRrRRr...rr............",
        "...........rr..rRRRRRRRr..rr......r.....",
        "..........rRRr.rRRRRRRRr.rRRr...........",
        "..........rRRRrRRRRRRRRRrRRRr.rr........",
        ".........rRRRRRRRRRRRRRRRRRRRrRr........",
        ".......rrRRRRRRRRRRRRRRRRRRRRRRr........",
        ".......rRRRRRRR.........RRRRRRRRr.......",
        ".......rRRRRR.............RRRRRRr.......",
        "......rRRRRR...............RRRRRr.......",
        "......rRRRR.................RRRRr.......",
        "......rRRR...................RRRRr......",
        ".....rRRR.....................RRRr......",
        ".....rRRR.....................RRRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        "......rRR.....................RRr.......",
        "......rRR.....................RRr.......",
        "......rRRR...................RRRr.......",
        ".......rRRR.................RRRr........",
        "........rRRR...............RRRr.........",
        ".........rRRR.............RRRr..........",
        "..........rRRRR.........RRRRr...........",
        "...........rRRRRRRRRRRRRRRRr............",
        "............rrrRRRRRRRRRrrr.............",
        "...............rrrrrrrrr................",
        "........................................",
    ],
    [
        "........................................",
        "......................r.................",
        ".........r..r.........r.................",
        "............r........rr.....r...........",
        "............rr.......rRr................",
        "............rr....r..rRr..r.............",
        "...........rRr..r...rRRr..r......r......",
        "...........rRRrrRr..rRRRrrr.............",
        "...........rRRRRRRrrRRRRRRRr....r.......",
        "..........rRRRRRRRRRRRRRRRRr...rr.......",
        "..........rRRRRRRRRRRRRRRRRRr..rr.......",
        "..........rRRRRRRRRRRRRRRRRRr.rRr.......",
        "........rrRRRRR.........RRRRRrRRr.......",
        "......rrRRRRR.............RRRRRRRr......",
        "......rRRRRR...............RRRRRRr......",
        "......rRRRR.................RRRRRr......",
        ".....rRRRR...................RRRRr......",
        ".....rRRR.....................RRRr......",
        ".....rRRR.....................RRRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        "......rRR.....................RRr.......",
        "......rRR.....................RRr.......",
        "......rRRR...................RRRr.......",
        ".......rRRR.................RRRr........",
        "........rRRR...............RRRr.........",
        ".........rRRR.............RRRr..........",
        "..........rRRRR.........RRRRr...........",
        "...........rRRRRRRRRRRRRRRRr............",
        "............rrrRRRRRRRRRrrr.............",
        "...............rrrrrrrrr................",
        "........................................",
    ],
    [
        "........................................",
        "..........r.............................",
        ".....................r.......r..........",
        ".....................r..................",
        ".................r.rrRr....r............",
        ".................rr.rRr....r......r.....",
        "...........r....rRRrRRr...rr............",
        "...........rr..rRRRRRRRr.rRRr...........",
        "..........rRRr.rRRRRRRRr.rRRr...........",
        "..........rRRRrRRRRRRRRRrRRRr...........",
        ".......rr.rRRRRRRRRRRRRRRRRRRrrr........",
        ".......rRrRRRRRRRRRRRRRRRRRRRRRr........",
        ".......rRRRRRRR.........RRRRRRRr........",
        "......rRRRRRR.............RRRRRRr.......",
        "......rRRRRR...............RRRRRr.......",
        "......rRRRR.................RRRRr.......",
        "......rRRR...................RRRr.......",
        ".....rRRR.....................RRRr......",
        ".....rRRR.....................RRRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        ".....rRR.......................RRr......",
        "......rRR.....................RRr.......",
        "......rRR.....................RRr.......",
        "......rRRR...................RRRr.......",
        ".......rRRR.................RRRr........",
        "........rRRR...............RRRr.........",
        ".........rRRR.............RRRr..........",
        "..........rRRRR.........RRRRr...........",
        "...........rRRRRRRRRRRRRRRRr............",
        "............rrrRRRRRRRRRrrr.............",
        "...............rrrrrrrrr................",
        "........................................",
    ],
]


def puff():
    return sheet([grid(f) for f in PUFF_FRAMES])


def coin():
    return sheet([grid(f) for f in COIN_FRAMES])


def soul():
    return sheet([grid(f) for f in SOUL_FRAMES])


def slash():
    return sheet([grid(f) for f in SLASH_FRAMES])


def impact_ring():
    return sheet([grid(f) for f in RING_FRAMES])


def aura():
    return sheet([grid(f) for f in AURA_FRAMES])


# ---------------------------------------------------------------------------------------------

ASSETS = {
    "bg_battle": bg_battle,
    "bg_title": bg_title,
    "bg_shop": bg_shop,
    "bg_map": bg_map,
    "logo": logo,
    "app_icon_32": app_icon_32,
    "stamp_defeated": stamp_defeated,
    "vfx_spark": spark,
    "vfx_puff": puff,
    "vfx_slash": slash,
    "vfx_coin": coin,
    "vfx_soul": soul,
    "vfx_impact_ring": impact_ring,
    "vfx_aura": aura,
}

if __name__ == "__main__":
    sys.exit(run(ASSETS, sys.argv[1:]))
