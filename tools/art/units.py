"""Final unit sprites, legion banner and crowd minis (ART_SPEC §4.2–§4.4).

    python tools/art/units.py                       # write changed unit / mini PNGs
    python tools/art/units.py --preview captures/units_preview.png

Every sprite is a hand-placed fill grid (legend: see pixelgrid.BASE_LEGEND). The exterior
1 px N0 outline is added by `pixelgrid.outline`, so fills keep a 1 px margin on every side
(feet on row 14 -> outline on row 15). Interior seams and faces are placed by hand with '#'.
Grounded frame 2 = `squash`; floating frame 2 = `bob` over an N0 shadow run on row 15, or a
hand-drawn blink/flicker variant where that reads better.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelgrid as pg  # noqa: E402


# ---------------------------------------------------------------- helpers

def _rows(rows: list[str], w: int) -> list[str]:
    for y, r in enumerate(rows):
        if len(r) != w:
            raise ValueError(f"row {y} is {len(r)} wide, expected {w}: {r!r}")
    return rows


def fill(rows: list[str], w: int = 16) -> "pg.Image.Image":
    """Fill grid -> outlined frame."""
    return pg.outline(pg.grid(_rows(rows, w), width=w))


def edit(rows: list[str], changes: dict[int, str]) -> list[str]:
    """Copy of a grid with some rows replaced (hand-drawn frame 2)."""
    out = list(rows)
    for y, r in changes.items():
        out[y] = r
    return out


def grounded(rows: list[str], frame2: list[str] | None = None):
    f1 = fill(rows)
    f2 = fill(frame2) if frame2 else pg.squash(f1)
    return pg.sheet([f1, f2])


def _with_shadow(frame, width: int):
    bbox = frame.getbbox()
    cx = (bbox[0] + bbox[2]) // 2
    x0 = cx - width // 2
    shadow = pg.grid(["#" * width])
    return pg.paste(frame, shadow, x0, 15)


def floating(rows: list[str], frame2: list[str] | None = None, shadow: int = 5):
    """Body rows 0..12 (fill <= 11); frame 2 bobs down 1 px (or uses frame2), row 14 stays empty."""
    f1 = _with_shadow(fill(rows), shadow)
    f2 = _with_shadow(pg.shift(fill(frame2), 0, 1), shadow) if frame2 else pg.bob(f1)
    return pg.sheet([f1, f2])


def mini(rows: list[str], frame2: list[str] | None = None):
    """8x8 crowd mini: frame 2 hops 1 px (fill rows 2..6, so both frames keep their outline)."""
    f1 = fill(rows, 8)
    f2 = fill(frame2, 8) if frame2 else pg.shift(f1, 0, -1)
    return pg.sheet([f1, f2])


# ---------------------------------------------------------------- tier 1

SKELETON_WARRIOR = [
    "................",
    ".............u..",
    "...ccccc.....u..",
    "..cccccccB...u..",
    "..c##c##cB...u..",
    "..c##c##cB...u..",
    "..cccc#ccB..bbb.",
    "...cBcBcB....c..",
    "...######...Bc..",
    ".c..cccc#BBBB...",
    ".c..bBbB#.......",
    ".c..cccc........",
    "....bBbB........",
    "....BBBBB.......",
    "....c...c.......",
    "................",
]

FIRE_IMP = [
    "................",
    "...g......g.....",
    "....g....g......",
    "...gFFFFFFf.....",
    "..gFFFFFFFFf....",
    "..gF#FFFF#Ff....",
    "..gFF#FF#FFf....",
    "..gFFFFFFFFf....",
    "..gF#FFFF#Ff..g.",
    "...FF#g##Ff..gF.",
    "....fFFFFf...FF.",
    "...gFFFFFFf...f.",
    "..gF.FFFFff..f..",
    ".....FFFfffff...",
    ".....Ff..Ff.....",
    "................",
]

FROST_BAT = [
    "................",
    "......j..I......",
    ".....jjIIIi.....",
    ".j...j#II#i...I.",
    ".jj..jIIIIi..Ii.",
    ".jjjjjIIIIIiIIi.",
    ".jjjjjIIIIIiIIi.",
    ".j.j.jIIIIi.I.i.",
    ".i....iIIi....i.",
    "......i..i......",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]

PUMPKINLING = [
    "................",
    "..mmL.....mmL...",
    ".mLLLL...mLLLl..",
    "..LLlllllLLll...",
    ".......l........",
    "....FF.l.FF.....",
    "...FFFFFFFFF....",
    "...FF#FFF#FF....",
    "...FFFF#FFFF....",
    "....FFFFFFF.....",
    "......lLl.......",
    "...mLLlLlLLm....",
    "......lLl.......",
    ".....Ll.lL......",
    "....Ll...lL.....",
    "................",
]

VOLT_GHOST = [
    "................",
    "......wwwV......",
    ".....wwVVVv.....",
    "....wVVVVVVv....",
    "....wV#VV#Vv....",
    "..wwwVVVVVVvvv..",
    ".7wVVVV##VVVVv..",
    "..V.wVVVVVVv.v7.",
    ".....wVVVVv.....",
    "......VVVv......",
    ".......Vv.......",
    "......vv........",
    "................",
    "................",
    "................",
    "................",
]

HAUNTED_ARMOR = [
    "................",
    ".....uuuuT......",
    "....uuuTTTt.....",
    "...uuTTTTTTt....",
    "...uT######t....",
    "...uT#w##w#t....",
    "...uTTTTTTTt....",
    "....tTTtTTt.....",
    "..uuuuTTTTttt...",
    "..uTtuTTTTtTt...",
    "..uTtuuTTTtTt...",
    "...t.uTTTTt.t...",
    ".....tttttt.....",
    ".....uT..uT.....",
    ".....tt..tt.....",
    "................",
]

# ---------------------------------------------------------------- tier 2 hybrids

FLAME_SKULL = [
    "...g...g..g.....",
    "...gF.gFg.gF....",
    "..fgFgFFgFF.....",
    "..fFcccccFFf....",
    "..fcccccccBf....",
    "..fc##c##cBf....",
    "...c##c##cB.....",
    "...cccbcccB.....",
    "....BcBcBb......",
    "....bBbBbb......",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]

SCARECROW = [
    "................",
    "......Bb........",
    ".....BBbb.......",
    ".....B#Bb.......",
    "...bBBBBBbb.....",
    "....ccccBB......",
    "....c#c#cB......",
    "....ccbccB......",
    ".B..LLmLLl..B...",
    ".BcLLLlLLLLlcB..",
    "..b.LmLLLl..b...",
    "....LLlLLl......",
    "....B.bb.B......",
    "......bb........",
    "......bb........",
    "................",
]

SHIELD_SKELETON = [
    "................",
    "....ccccccB.....",
    "...ccccccccB....",
    "...c##cc##cB....",
    "...c##cc##cB....",
    "...cccc#cccB....",
    "..uccuuuuccuT...",
    "..uTTTTTTTTTt...",
    "..uTTTcTcTTTt...",
    "..uTTTTcTTTTt...",
    "..uTTTcTcTTTt...",
    "..uTTTTTTTTTt...",
    "...tTTTTTTTt....",
    "....c.....c.....",
    "...cc....cc.....",
    "................",
]

STEAM_SLIME = [
    "................",
    ".........jjj....",
    "......jjjjj.....",
    ".......jj.......",
    "................",
    ".....FFFIIi.....",
    "....gFFFIIIi....",
    "...gFFFFIIIIi...",
    "..gF#FFFII#Ii...",
    "..gFFFFFIIIIi...",
    "..FFF##IIIIIi...",
    "..FFFFFIIIIIi...",
    "..fFFFFIIIIii...",
    "..ffffFIiiiii...",
    "...ffffiiiii....",
    "................",
]

JACK_O_LANTERN = [
    ".......lLm......",
    "......lL........",
    "...FFFFlFFFF....",
    "..gFFFFFFFFFf...",
    ".gFfggFFFggfFf..",
    ".gFFggFfFggFFf..",
    ".gFFFFFFFFFFFf..",
    ".gFgfgfgfgfgFf..",
    ".gFfgfgfgfgfFf..",
    "..fFFFFFFFFFf...",
    "...lLLmLLmLl....",
    "..LmL.lLl..LmL..",
    "...lL.lLl..Ll...",
    "......lLl.......",
    ".....Ll.lL......",
    "................",
]

BOG_WITCH = [
    ".lL.............",
    "..LmL...........",
    "...LmLl.........",
    "....LmLLl.......",
    "..lLLLLLLLLl....",
    "....mmmmmL..j...",
    "....m#mm#mm.jjj.",
    "...ImmmmmLm..j..",
    "..jIIIIIIIjm.i..",
    ".jIIIIIIIIi..i..",
    ".jIIIIIIIIi..i..",
    ".IIIIIIIIIi..i..",
    "..IIIIIIIIi..i..",
    "..iIiIiIiIi..i..",
    "..iiiiiiiii..i..",
    "................",
]

STORM_BANSHEE = [
    "................",
    "...wVwjjjjI.....",
    "..wV.wjjjIIi....",
    ".VwVVjjIIIIIi...",
    "..V.wjI#II#Ii...",
    ".wVwVjIIIIIIi...",
    ".V.VwjII##IIi...",
    "..wV.jII##IIi...",
    ".V...jIIIIIi....",
    "....jIIIIIi.....",
    "...jIIIi.ii.....",
    "..ii..i.........",
    "................",
    "................",
    "................",
    "................",
]

TESLA_SPIDER = [
    "................",
    ".......w........",
    "......VwV.......",
    ".....VVVVv......",
    "......tTt.......",
    ".....VVVVv......",
    "....uuTTTTt.....",
    "...uuTTTTTTt....",
    "..uuTVTTVTTtt...",
    "..T.uTTTTTt.T...",
    ".T..tTTTTTt..T..",
    ".T.T.tttttt.T.T.",
    ".T.T..T..T..T.T.",
    "...T..T..T..T...",
    "...t..t..t..t...",
    "................",
]

WISP_MASK = [
    "................",
    ".....y....y.....",
    ".....yX..yX.....",
    "....yyX.yXx.....",
    "....yXXyXXx.....",
    "...yyXXXXXXx....",
    "...yXXyyXXXx..q.",
    "...yXyyyyXXx.qZ.",
    "...XXXyyXXxx..Z.",
    "....XXXXXxx.....",
    ".....xxxxx......",
    "................",
    "................",
    "................",
    "................",
    "................",
]

# ---------------------------------------------------------------- tier 3

LICH = [
    "...O.O.O........",
    "...OOOOO...ccB..",
    "..cccccccB.c#B..",
    "..c##c##cB.cBb..",
    "..c##c##cB..b...",
    "..ccccbccB..b...",
    "...cBcBcB...b...",
    "..55555554.cb...",
    ".5555455544.b...",
    ".555545544..b...",
    ".55554554...b...",
    ".55554554...b...",
    "555554554...b...",
    "5555545544444...",
    "4444444444444...",
    "................",
]

HEADLESS_HORSEMAN = [
    "..........L.....",
    "...OOOO..FFFF...",
    "....bb...OFOF...",
    "...LLLLLLFFFF...",
    "..LLLLLL........",
    "..LLLLLL...ccB..",
    "..LLLLLL..cc#cB.",
    ".bLLLLLLcccc....",
    ".bccLLcccccc....",
    ".bBcLLBcBcBc....",
    "..cccccccccc....",
    "..c.c.....c.c...",
    "..c.c.....c.c...",
    "..c.c.....c.c...",
    "..c.c.....c.c...",
    "................",
]

STITCHED_GOLEM = [
    ".....O.O.O......",
    ".....OOOOO......",
    ".....tTTTt......",
    "....tTTTTTt.....",
    "....TVTTVTt.....",
    "..cccTTTTTtuu...",
    ".ccccTVTTuuuTt..",
    ".cccTTVTTTTTTt..",
    ".uTTTTTVVVTccTt.",
    ".uTVVVTTTVTccTt.",
    ".uTTTVTTTVTTTt..",
    "..u.TTVTTTTt.t..",
    "....tTVTTTTt....",
    "....ccc..TTt....",
    "...cccc..uTTt...",
    "................",
]

WITCH_QUEEN = [
    "...O.L.O.L.O....",
    "...LLLLLLLLL....",
    "...ijjjjjjji....",
    "...ij#jjj#ji....",
    "...ijjjjjjji....",
    "...iijjjjjii.jV.",
    "....iIjjjIi.VVV.",
    "...iIIIIIIIijVV.",
    "..iIIjIIIIIjj...",
    "..iIjIIIIIIi....",
    "..iIjIIIIIIi....",
    "..IIjIIIIIIIi...",
    ".IIIjIIIIIIIIi..",
    ".IIjIIIIIIIIIi..",
    ".iiiiiiiiiiiii..",
    "................",
]

LEGION_BANNER = [
    "..cc............",
    "..cB............",
    "..Bb5555555555..",
    "..Bb5333333333..",
    "..Bb5333333333..",
    "..Bb5333333333..",
    "..Bb5333333333..",
    "..Bb5333333333..",
    "..Bb5333333333..",
    "..Bb5333333333..",
    "..Bb533.3333.3..",
    "..Bb53...33.....",
    "..Bb5.....3.....",
    "..Bb............",
    "..Bb............",
    "................",
]

# ---------------------------------------------------------------- crowd minis (8x8)

MINI_BONE = [
    "........",
    "........",
    "..cccB..",
    ".ccccBB.",
    ".c#cc#B.",
    ".ccBcBb.",
    "..cbcb..",
    "........",
]

MINI_FIRE = [
    "........",
    "........",
    "...g.F..",
    "..gFFf..",
    ".gF#F#f.",
    ".gFFFFf.",
    "..fFFf..",
    "........",
]

MINI_ICE = [
    "........",
    "........",
    "..j..I..",
    ".jjIIIi.",
    ".j#I#Ii.",
    ".i.II.i.",
    "........",
    "........",
]

MINI_LEAF = [
    "........",
    "....l...",
    "...l....",
    "..LLLL..",
    ".m#LL#l.",
    ".mLLLLl.",
    "..llll..",
    "........",
]

MINI_VOLT = [
    "........",
    "........",
    "..wwV...",
    ".wVVVv..",
    ".w#V#v..",
    ".VVVVv..",
    ".Vv.Vv..",
    "........",
]

MINI_METAL = [
    "........",
    "........",
    "..uuTt..",
    ".uuTTTt.",
    ".u####t.",
    ".uTTTTt.",
    ".tTttTt.",
    "........",
]

MINI_WISP = [
    "........",
    "........",
    "...y....",
    "..yX..Z.",
    ".yXXX...",
    ".yXXX...",
    "..XX....",
    "........",
]


ASSETS = {
    "skeleton_warrior": lambda: grounded(SKELETON_WARRIOR),
    "fire_imp": lambda: grounded(FIRE_IMP),
    "frost_bat": lambda: floating(FROST_BAT),
    "pumpkinling": lambda: grounded(PUMPKINLING),
    "volt_ghost": lambda: floating(VOLT_GHOST),
    "haunted_armor": lambda: grounded(HAUNTED_ARMOR),
    "flame_skull": lambda: floating(FLAME_SKULL),
    "scarecrow": lambda: grounded(SCARECROW),
    "shield_skeleton": lambda: grounded(SHIELD_SKELETON),
    "steam_slime": lambda: grounded(STEAM_SLIME),
    "jack_o_lantern": lambda: grounded(JACK_O_LANTERN),
    "bog_witch": lambda: grounded(BOG_WITCH),
    "storm_banshee": lambda: floating(STORM_BANSHEE),
    "tesla_spider": lambda: grounded(TESLA_SPIDER),
    "wisp_mask": lambda: floating(WISP_MASK),
    "lich": lambda: grounded(LICH),
    "headless_horseman": lambda: grounded(HEADLESS_HORSEMAN),
    "stitched_golem": lambda: grounded(STITCHED_GOLEM),
    "witch_queen": lambda: grounded(WITCH_QUEEN),
    "legion_banner": lambda: fill(LEGION_BANNER),
    "mini_bone": lambda: mini(MINI_BONE),
    "mini_fire": lambda: mini(MINI_FIRE),
    "mini_ice": lambda: mini(MINI_ICE),
    "mini_leaf": lambda: mini(MINI_LEAF),
    "mini_volt": lambda: mini(MINI_VOLT),
    "mini_metal": lambda: mini(MINI_METAL),
    "mini_wisp_mask": lambda: mini(MINI_WISP),
}


if __name__ == "__main__":
    sys.exit(pg.run(ASSETS, sys.argv[1:]))
