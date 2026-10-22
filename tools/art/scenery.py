"""Scenery art: VFX, logo, app icon and the DEFEATED stamp (ART_SPEC §7, §10, §11).

    python tools/art/scenery.py                         # create missing files only
    python tools/art/scenery.py --only logo             # rewrite named ids
    python tools/art/scenery.py --preview out.png       # x6 contact sheet, writes nothing

Logo letters, the app icon, the stamp lettering and every VFX frame are hand-placed grids.
Backgrounds are not here: bg_title / bg_battle are hand-drawn by the designer (no generator
owns them) and bg_map / bg_shop come from tools/art/backgrounds.py (D-R11).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelgrid import BASE_LEGEND, canvas, grid, rgba, run, sheet  # noqa: E402

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
# logo — "ROLL THE BONES": hand-drawn bold letters (top light, mid body, dark underside),
# a bone between the lines, the O of BONES is a skull-faced die. N0 outline + 1 px drop shadow.
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


LETTERS.update({
    "B": [
        "###########...",
        "############..",
        "#############.",
        "####.....####.",
        "####......###.",
        "####......###.",
        "####.....####.",
        "############..",
        "###########...",
        "############..",
        "####.....####.",
        "####......####",
        "####......####",
        "####......####",
        "####.....#####",
        "##############",
        "#############.",
        "############..",
    ],
    "N": [
        "#####.....####",
        "######....####",
        "#######...####",
        "########..####",
        "####.###..####",
        "####.####.####",
        "####..###.####",
        "####..########",
        "####...#######",
        "####...#######",
        "####....######",
        "####....######",
        "####.....#####",
        "####.....#####",
        "####......####",
        "####......####",
        "####......####",
        "####......####",
    ],
    "S": [
        "..##########.",
        ".############",
        "#############",
        "####.....####",
        "####.........",
        "####.........",
        "#####........",
        ".##########..",
        "..##########.",
        "...##########",
        "........#####",
        ".........####",
        ".........####",
        "####.....####",
        "#############",
        "#############",
        ".############",
        "..##########.",
    ],
})

# small 7x10 bold letters for the "ROLL THE" line
SMALL = {
    "R": ["######.", "#######", "##...##", "##...##", "######.", "#####..", "##.##..", "##..##.", "##...##", "##...##"],
    "O": [".#####.", "#######", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "#######", ".#####."],
    "L": ["##....."] * 8 + ["#######"] * 2,
    "T": ["#######", "#######"] + ["..###.."] * 8,
    "H": ["##...##"] * 4 + ["#######"] * 2 + ["##...##"] * 4,
    "E": ["#######", "#######", "##.....", "##.....", "######.", "######.", "##.....", "##.....", "#######", "#######"],
}


def logo():
    """ROLL THE / BONES: small bone-white line over big fire letters; the O of BONES is a
    skull-faced die; a long bone runs behind, between the lines. N0 ring + 1 px drop shadow."""
    p = Pic(160, 48)
    bone_y, bx0, bx1 = 13, 8, 151
    bone = Pic(160, 48)
    bone.stamp(BONE_END, bx0, bone_y)
    bone.stamp([r[::-1] for r in BONE_END], bx1 - 6, bone_y)
    bone.rect(bx0 + 7, bone_y + 3, bx1 - bx0 - 13, 4, "B1")
    bmask = {(x, y) for y in range(48) for x in range(160) if bone.get(x, y)}
    _ring(p, bmask, shadow=True)
    _shade(p, bmask, 0, 0, "B2", "B1", "B0")
    for x, y in ((28, 17), (29, 18), (30, 18), (130, 18), (131, 17), (132, 18)):  # nicks in the shaft
        p.put(x, y, "B0")

    def word(items: list[tuple], y0: int, glyphs: dict, ramp: tuple) -> None:
        painted: set = set()
        for kind, x, dy in items:
            m = ({(i, j) for j, r in enumerate(DIE_O) for i, ch in enumerate(r) if ch != "."}
                 if kind == "DIE" else _mask(glyphs[kind]))
            painted |= {(x + i, y0 + dy + j) for (i, j) in m}
        _ring(p, painted)
        for kind, x, dy in items:
            if kind == "DIE":
                p.stamp(DIE_O, x, y0 + dy)
            else:
                _shade(p, _mask(glyphs[kind]), x, y0 + dy, *ramp)

    # line 1: ROLL THE (bone ramp, small)
    word([("R", 47, 0), ("O", 56, 0), ("L", 65, 0), ("L", 74, 0),
          ("T", 88, 0), ("H", 97, 0), ("E", 106, 0)], 2, SMALL, ("B2", "B1", "B0"))
    # line 2: BONES (fire ramp, big); the die-O sits higher, mid-roll, letters bounce ±1 px
    word([("B", 38, 0), ("DIE", 55, -2), ("N", 76, 1), ("E", 93, 0), ("S", 108, -1)], 23, LETTERS,
         ("F2", "F1", "F0"))
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
