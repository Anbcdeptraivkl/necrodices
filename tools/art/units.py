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


def layered(*parts: list[str]) -> "pg.Image.Image":
    """Part grids back to front, each with its own N0 ring, so overlapping parts stay separated."""
    out = pg.canvas(16, 16)
    for rows in parts:
        pg.paste(out, fill(rows), 0, 0)
    return out


def grounded_parts(*parts: list[str]):
    f1 = layered(*parts)
    return pg.sheet([f1, pg.squash(f1)])


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

# ---------------------------------------------------------------- ritual, elites, rainbow

# Ritual FIRE+ICE+METAL: steel dome with a wind-up key, brass-ringed ice eye, boiler grille.
CLOCKWORK_KRAKEN = [
    "......o.o.......",
    "......ooo.......",
    ".......o........",
    ".....uuTTTt.....",
    "....uuTTTTTt....",
    "...uTToooTTTt...",
    "...uToIIIoTTt...",
    "...uToI#IoTTt...",
    "...uTToooTTtt...",
    "...tTF#F#FTtt...",
    "..uTttttttttTt..",
    ".uT.uT.TT.Tt.Tt.",
    ".T..oT.Tt.To..T.",
    ".uT.Tt.oT.tT.Tt.",
    "..t..t..t..t..t.",
    "................",
]

# Elites carry a G1 mark (crown or horns).
HELLHOUND = [
    "................",
    "...g......O..O..",
    "..gF..g..gORRO..",
    "..gFg.gFgFRRRR..",
    "...FFgFFFRRgRRR.",
    "..gFFFFFFRRRRRR.",
    ".g.FFFFFFrRRr##.",
    ".gFRRRRRRRrrr...",
    "..FRRRRRRRrrr...",
    "...rrrrrrrrr1...",
    "...r1rrrrrr11...",
    "...r1.Rr.r1.Rr..",
    "...r1.Rr.r1.Rr..",
    "...r1.Rr.r1.Rr..",
    "..rr.RR.rr.RR...",
    "................",
]

FROST_WRAITH = [
    "......O.O.O.....",
    "......OOOOO.....",
    ".....jjIIIIi....",
    "....jjI1111Ii...",
    "...jjI171171Ii..",
    "...jI11111111i..",
    "..jjII111111Ii..",
    ".jjjIIIIIIIIIii.",
    ".j.jIIIjIIIIi.i.",
    "...jIIjIIIIIi...",
    "...jIjIIiIIIi...",
    "...i.ji.i.ii....",
    "................",
    "................",
    "................",
    "................",
]

MANDRAKE_BRUTE = [
    "....m.O.m.......",
    "...mLmOmLm......",
    "..mLLlLlLLm.....",
    "....LLLLLl......",
    "....L#LL#l......",
    "..mLLL##LLLll...",
    ".mLLLLLLLLLLll..",
    ".mLLmLLLLLlLLl..",
    ".LLlmLLLLLllLl..",
    ".Ll.LLLLLLl.Ll..",
    ".sS.lLLLLLl.Ss..",
    "sS.slLLLll..sSs.",
    "....lsSlsS......",
    "...sS....sS.....",
    "..sS......Ss....",
    "................",
]

THUNDER_GHOUL = [
    "................",
    "................",
    "................",
    "..wVv......wVv..",
    ".wVVVv....wVVVv.",
    ".VVVVVVVVVVVVVv.",
    ".VVwVVVVVVVVVVv.",
    ".VV.VVVVVVVVvVv.",
    ".VV.wVwVwVwV.Vv.",
    ".VV..444444..Vv.",
    ".Vv..444444..Vv.",
    ".wVw.44..44.wVw.",
    ".w.w.VV..VV.w.w.",
    ".....Vv..Vv.....",
    "....VVv..VVv....",
    "................",
]

THUNDER_GHOUL_HEAD = [
    "................",
    ".....O....O.....",
    ".....wVVVVV.....",
    ".....V#VV#v.....",
    ".....VVVVVv.....",
    ".....V#w#wv.....",
    "......VVVv......",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]

THUNDER_GHOUL_SPARKS = [
    "................",
    ".w...........w..",
    "..w.........w...",
    ".w...........w..",
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
    "................",
    "................",
]

GARGOYLE = [
    ".u............t.",
    ".uT..O....O..Tt.",
    ".uTT.uO..Ot.TTt.",
    ".uTTuuTTTTTtTTt.",
    ".uTTuTOTTOTtTTt.",
    ".uT3uTTTTTTt3Tt.",
    ".u33.uT##Tt.33t.",
    ".u33uuTTTTTtt33.",
    ".u3.uTTTTTTt.3t.",
    "..t.uTuTTtTt.t..",
    "...uTTTTTTTTt...",
    "..uTt.TTTt.uTt..",
    "..uTt.TTTt.uTt..",
    "..TTt.tttt.TTt..",
    ".uTtt......uTtt.",
    "................",
]

# Rainbow: three tiny element ghosts in a procession, the lead one carrying a candle.
PHANTOM_PARADE = [
    "............O...",
    "............O...",
    "............7...",
    "......7L....7...",
    ".....7LLL..7F...",
    "..7I.L#L#.7FFF..",
    ".7III LLLL7F#F#.",
    ".I#I#.LLLLFFFFF.",
    ".IIII.LLLLFFFF..",
    ".IIII.L.L.FFFF..",
    ".I.I......F.F...",
    "................",
    "................",
    "................",
    "................",
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
    "clockwork_kraken": lambda: grounded(CLOCKWORK_KRAKEN),
    "hellhound": lambda: grounded(HELLHOUND),
    "frost_wraith": lambda: floating(FROST_WRAITH),
    "mandrake_brute": lambda: grounded(MANDRAKE_BRUTE),
    "thunder_ghoul": lambda: grounded_parts(THUNDER_GHOUL_SPARKS, THUNDER_GHOUL, THUNDER_GHOUL_HEAD),
    "gargoyle": lambda: grounded(GARGOYLE),
    "phantom_parade": lambda: floating(PHANTOM_PARADE),
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
