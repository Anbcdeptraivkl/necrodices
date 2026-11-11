"""Scenery art: VFX, logo, app icon and the DEFEATED stamp (ART_SPEC §7, §10, §11).

    python tools/art/scenery.py                         # create missing files only
    python tools/art/scenery.py --only logo             # rewrite named ids
    python tools/art/scenery.py --preview out.png       # x6 contact sheet, writes nothing

The app icon, the stamp lettering and every VFX frame are hand-placed grids. The logo is built
from block letters (stems and arms) and the skull die.
Backgrounds are not here: bg_title / bg_battle are hand-drawn by the designer (no generator
owns them) and bg_map / bg_shop come from tools/art/backgrounds.py (D-R11).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelgrid import BASE_LEGEND, canvas, grid, outline, rgba, run, sheet  # noqa: E402

W, H = 640, 300


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


# ---------------------------------------------------------------------------------------------
# Prop grids (hand-placed). '#' N0, digits N1..N7, letters per BASE_LEGEND.
# ---------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------------------
# logo — "NECRODICER" (D-A20): block capitals that stand on a lip like the designer's dice
# (flat face, darker rows at the bottom, corner glint, N0 outline). NECRO in bone, DICER in fire;
# the O is the skull die of the app icon.
# ---------------------------------------------------------------------------------------------

LOGO_STEM, LOGO_ARM = 5, 4
BONE_INK = ("B2", ("B1", "B0", "B0"), "N7")   # face, lip rows top to bottom, glint
FIRE_INK = ("F1", ("F0", "F0", "F0"), "F2")


def _box(x0: int, y0: int, x1: int, y1: int) -> set[tuple[int, int]]:
    return {(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)}


def _letter(ch: str, h: int) -> tuple[set[tuple[int, int]], int]:
    """Mask and width of a block capital `h` px tall: 5 px stems, 4 px arms, stepped corners."""
    s, a, b = LOGO_STEM, LOGO_ARM, h - 1
    mid = (h - a) // 2
    stem = _box(0, 0, s - 1, b)
    if ch == "I":
        return stem, s
    if ch == "N":
        w = 14
        m = stem | _box(w - s, 0, w - 1, b)
        for y in range(h):
            x = round(y * (w - s) / b)
            m |= _box(x, y, x + s - 1, y)
        return m, w
    if ch == "E":
        w = 13
        return stem | _box(0, 0, w - 1, a - 1) | _box(0, mid, w - 3, mid + a - 1) | _box(0, h - a, w - 1, b), w
    if ch == "C":
        w = 13
        m = stem | _box(0, 0, w - 1, a - 1) | _box(0, h - a, w - 1, b)
        m |= _box(w - s, 0, w - 1, a + 2) | _box(w - s, b - a - 2, w - 1, b)
        return m - {(0, 0), (1, 0), (0, 1), (0, b), (1, b), (0, b - 1)}, w
    if ch == "D":
        w = 14
        return stem | _box(0, 0, w - 3, a - 1) | _box(0, h - a, w - 3, b) | _box(w - s, 2, w - 1, b - 2), w
    if ch == "R":
        w = 14
        m = stem | _box(0, 0, w - 3, a - 1) | _box(w - s, 2, w - 1, mid + 1) | _box(0, mid, w - 3, mid + a - 1)
        m |= _box(w - s - 1, mid + a, w - 2, mid + a + 1) | _box(w - s, mid + a + 2, w - 1, b)
        return m, w
    raise KeyError(ch)


# The app icon's face on a 20 px wide die: slanted sockets, nose, a smirk with dashed teeth.
SKULL_FACE = [
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "..######....######..",
    "..######....######..",
    "...####......####...",
    "....##........##....",
    "....................",
    "........####........",
    ".........##.........",
    "...............#....",
    "....#..........#....",
    ".....##.###.###.....",
    "....................",
    "....................",
    "....................",
]


def _skull_die(p: Pic, x0: int, y0: int, h: int, lip: int) -> int:
    """The skull die as the letter O, 20 px wide; the caller's outline pass adds its N0 ring."""
    w = 20
    for y in range(h + lip):
        cut = 1 if y in (0, h + lip - 1) else 0  # with the outline this is the 2 px chamfer
        for x in range(cut, w - cut):
            p.put(x0 + x, y0 + y, "B2" if y < h else ("B1" if y == h else "B0"))
    for y in range(2, h - 1):
        p.put(x0 + w - 2, y0 + y, "B1")
    face_y = y0 + (h - len(SKULL_FACE)) // 2
    for j, row in enumerate(SKULL_FACE):
        for i, ch in enumerate(row):
            if ch == "#":
                p.put(x0 + i, face_y + j, "N0")
    p.put(x0 + 1, y0, "N7")
    p.put(x0, y0 + 1, "N7")
    return w


def _logo_word(p: Pic, text: str, x: int, y: int, h: int, ink: tuple, gap: int = 2) -> int:
    """Draws `text` ('O' = the skull die) from (x, y); returns the x after the last letter."""
    face, lips, glint = ink
    for ch in text:
        if ch == "O":
            x += _skull_die(p, x, y, h, len(lips)) + gap
            continue
        mask, w = _letter(ch, h)
        for i, j in mask:
            p.put(x + i, y + j, face)
            if j == h - 1:  # the letter stands on its lip
                for k, key in enumerate(lips):
                    p.put(x + i, y + h + k, key)
        top = min(i for i, j in mask if j == 0)
        for i, j in ((top, 0), (top + 1, 0), (0, 1) if top else (0, 1)):
            p.put(x + i, y + j, glint)
        x += w + gap
    return x - gap


def _logo_width(text: str, h: int, gap: int = 2) -> int:
    return sum(20 if ch == "O" else _letter(ch, h)[1] for ch in text) + gap * (len(text) - 1)


def logo():
    """NECRO over DICER, 18 px letters: NECRO in bone with the skull die as its O, DICER in fire;
    the two lines share one outline row."""
    p = Pic(160, 48)
    h = 18
    y = (48 - 2 * (h + 3) - 1) // 2
    _logo_word(p, "NECRO", (160 - _logo_width("NECRO", h)) // 2, y, h, BONE_INK)
    _logo_word(p, "DICER", (160 - _logo_width("DICER", h)) // 2, y + h + 3 + 1, h, FIRE_INK)
    return outline(p.image())


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


# Power aura behind a big unit (ART_SPEC §10): a crown of flame tongues licking upward around a
# hollow centre, drawn in light neutrals only (7 = N7 hot inner edge, 6 = N6 body, 5 = N5 tips)
# so the game tints it per element with modulate. Tongues flicker in height and sway per frame.
FLAME_FRAMES = [
    [
        "................................",
        "...............5................",
        "..........6....5................",
        "..............565...............",
        ".....5...5....565....5..6.......",
        ".....5..565555666555565..5......",
        ".....5..566666777666665..5......",
        "....56556677..565..77665565.....",
        "....566667...........766665.....",
        "....56667.............76665.....",
        "...56665...............56665....",
        "...5667.................7665....",
        "..5667...................7665...",
        "..565.....................565...",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        "..666.....................666...",
        "..6667...................7666...",
        "...6667.................7666....",
        "...6666.................6666....",
        "....66667.............76666.....",
        ".....66667...........76666......",
        "......666677.......776666.......",
        "........666666777666666.........",
        "..........66666666666...........",
        "................................",
    ],
    [
        "................................",
        "................................",
        "................5...............",
        ".......6.55....55..655..........",
        ".........55...565...55..........",
        "........566555666555665.........",
        "......5.566666777666665.........",
        ".....5656677.......7766555......",
        "....5666675.........576665......",
        "....56667.............76665.5...",
        "..556665...............566655...",
        "..56667.................76665...",
        "..5667...................7665...",
        "..565.....................5665..",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        "..6666....................666...",
        "..6667...................7666...",
        "...6667.................7666....",
        "...6666.................6666....",
        "....66667.............76666.....",
        ".....66667...........76666......",
        "......666677.......776666.......",
        "........666666777666666.........",
        "..........66666666666...........",
        "................................",
    ],
    [
        "................................",
        "...............5................",
        "....6..........5................",
        "..............565...............",
        "..........5...565...5....5......",
        ".....5...5655566655565...5......",
        ".....5..566666777666665..5......",
        "....56556677...5...77665565.....",
        "....566667...........766665.....",
        "....56667.............76665.....",
        "...56665...............566655...",
        "..56667.................76665...",
        "..5667...................7665...",
        "..565.....................5665..",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        "..6665....................666...",
        "..6667...................7666...",
        "...6667.................7666....",
        "...6666.................6666....",
        "....66667.............76666.....",
        ".....66667...........76666......",
        "......666677.......776666.......",
        "........666666777666666.........",
        "..........66666666666...........",
        "................................",
    ],
    [
        "................................",
        "................................",
        "................................",
        ".........55..655....55..........",
        ".........55...565...55..........",
        "........566555666555665.........",
        "....5...566666777666665...5.....",
        "....55556677.......77665555.....",
        "....5666675.........5766665.....",
        "..5.56667.............76665.....",
        "..556665...............566655...",
        "..56667.................76665...",
        "..5667...................7665...",
        ".5665.....................565...",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".5667.....................7665..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        ".6667.....................7666..",
        "..666....................6666...",
        "..6667...................7666...",
        "...6667.................7666....",
        "...6666.................6666....",
        "....66667.............76666.....",
        ".....66667...........76666......",
        "......666677.......776666.......",
        "........666666777666666.........",
        "..........66666666666...........",
        "................................",
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


def flame():
    return sheet([grid(f) for f in FLAME_FRAMES])


# ---------------------------------------------------------------------------------------------

ASSETS = {
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
    "vfx_flame": flame,
}

if __name__ == "__main__":
    sys.exit(run(ASSETS, sys.argv[1:]))
