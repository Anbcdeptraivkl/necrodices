"""Final legend sprites: Quintet units, 32x32 (category "legend", ART_SPEC §4.1-§4.2).

    python tools/art/legends.py --only bone_dragon     # (re)write one id
    python tools/art/legends.py --preview captures/legends_preview.png

Sheet 64x32 = 2 idle frames of 32x32. Every sprite is one or more hand-placed fill grids
(legend: pixelgrid.BASE_LEGEND), 32 columns wide, composed back to front; each part gets
its own exterior N0 ring, so overlapping parts (a fist over a shaft, a head over a body)
stay separated. The stack is moved down so its lowest fill row sits on row 30 (outline on
row 31, the feet row). Frame 2 = `squash` (top half down 1 px: a breath), optionally with a
per-part recolour (a flicker). Max 12 colours per sheet including the outline.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelgrid as pg  # noqa: E402

FRAME = 32
Part = "list[str] | tuple[list[str], dict[str, str]]"


def _part(rows: list[str]) -> "pg.Image.Image":
    for y, r in enumerate(rows):
        if len(r) != FRAME:
            raise ValueError(f"row {y} is {len(r)} wide, expected {FRAME}: {r!r}")
    return pg.grid(rows, width=FRAME)


def legend(*parts: Part):
    """Parts back to front -> 64x32 sheet. A part may be (rows, swap): `swap` recolours that
    part in frame 2 only (palette keys, e.g. {"I1": "I2"})."""
    norm = [(p, None) if isinstance(p, list) else p for p in parts]
    height = max(len(rows) for rows, _ in norm)
    dy = (FRAME - 2) - (height - 1)
    if dy < 0:
        raise ValueError(f"{height} rows do not fit above the feet row")

    def frame(second: bool) -> "pg.Image.Image":
        out = pg.canvas(FRAME, FRAME)
        for rows, swap in norm:
            img = _part(rows)
            if second and swap:
                img = pg.recolor(img, swap)
            ring = pg.outline(pg.shift(_pad(img), 0, dy))
            pg.paste(out, ring, 0, 0)
        return out

    f1 = frame(False)
    f2 = pg.squash(frame(True))
    return pg.sheet([f1, f2])


def _pad(img: "pg.Image.Image") -> "pg.Image.Image":
    out = pg.canvas(FRAME, FRAME)
    out.paste(img, (0, 0), img)
    return out


BONE_DRAGON = [
    "................................",
    "...cc.......c......B.......BB...",
    "..cBBc......cB....bB......BbbB..",
    "..B54Bc......cB..bB......Bb44b..",
    ".cB544Bc.....cBcBbB.....Bb444bB.",
    ".B5c444Bc...cBBBbbbB...Bb444B4b.",
    ".B5c4444Bc.cBBBBbbbbB.Bb4444B4b.",
    ".B5c44444BcB#R#Bb#R#bBb44444B4b.",
    ".B4c444444BcB#BBbb#bBb444444B4b.",
    ".b4B4c44444BcBBBbbbBb44444B4b4b.",
    ".b4B4c444444cbBBbbbB444444B4b4b.",
    "..b4B4c4444..cB##bB..4444B4b4b..",
    "..b.B4c4444..cBBbbB..4444B4b.b..",
    "....b.Bb4.4..c#c#c#..4.4bb.b....",
    "......b......bcBcBb......b......",
    "...........cB2BBbb2bB...........",
    "..........cBc2BBbb2BbB..........",
    "..........B2B22Bb22b2b..........",
    "..........cBc2BBbb2BbB..........",
    "..........B2B22Bb22b2b..........",
    "...........bBb2Bb2bbb...........",
    "............bBBBbbbbbBBc........",
    "...........cB.b..b.bB.bBBb......",
    "..........cBb......bbB..bBBb....",
    "..........cBb......bbB...bBBb...",
    "...........cB......bB.....bBBc..",
    "...........cB......bB......bBc..",
    "..........cBBb....bbbB.....bBB..",
    ".........cBBBBb..bbbbbB....cB...",
    "........c.c.B.b..b.b.B.B....c...",
]

EMBER_COLOSSUS = [
    "..............g..g..............",
    "............g.gFFg.g............",
    "............gFgFFgFg............",
    "...........gFFgFFgFFg...........",
    "...........5544444444...........",
    "....5555...54Og44gO44...4444....",
    "...554F44..5444444444..44F444...",
    "..55444F44.53fFFFFf34.44F44444..",
    ".5544FFg4445333333334444gFF4444.",
    ".5444Fg4F4455FF44FF4444F4gF4444.",
    ".54F44FF4F445FgFFgF444F4FF44F44.",
    ".54gF444FF445gOggOg444FF444Fg44.",
    ".3FF4F4FF43345FggF44334FF4F4FF3.",
    ".33F44Fg33.355FOOF443.33gF44F33.",
    "..3FF4F33..35FgFFgF43..33F4FF3..",
    "..5554F3...35Fg44gF43...3F4444..",
    ".554F4FF...354FFFF443...FF4F444.",
    ".5FFFgFF...33F4444F33...FFgFFF4.",
    ".5FgOgFF....33F44F33....FFgOgF4.",
    ".4FFgFF3...5544444444...3FFgFF4.",
    "..3FFF3...554F4444F444...3FFF3..",
    "...333...5544Fg44gF4444...333...",
    ".........54FF433334FF44.........",
    ".........5F44......44F4.........",
    ".........5Fg4......4gF4.........",
    ".........54F4......4F44.........",
    "........55FF4......4FF44........",
    ".......554gF43....34Fg444.......",
    ".......3333333....3333333.......",
]

FROST_WYRM_WING = [
    "................................",
    "................................",
    "................................",
    ".7..............................",
    ".j7.............................",
    ".jj7............................",
    ".jIj7...........................",
    ".jIIj7..........................",
    "..iIIj7.........................",
    "..iIIIj7........................",
    "...iIIIj7.......................",
    "...iiIIIj.......................",
    "....iiIIIj......................",
    ".....iiIIj......................",
    ".......iIj......................",
]

FROST_WYRM_BODY = [
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    ".........7.7.7.7.7.7............",
    "........jjjjjjjjjjjjjjjj........",
    ".......jIIIIIIIIIIIIIIIIjj......",
    ".......IIIIIIIIIIIIIIIIIIIjj....",
    ".......iIIIIIIIIIIIIIIIIIIIIj...",
    "........i66666666666iIIIIIIIj7..",
    ".........iiiiiiiiiiii6IIIIIIi...",
    ".....................6IIIIIIi7..",
    "....................66IIIIIi....",
    "....7.7.7.7.7.7.7.66IIIIIi......",
    "....jjjjjjjjjjjjjjIIIIIii.......",
    "..jjIIIIIIIIIIIIIIIIIIii........",
    "jjIIIIIIIIIIIIIIIIIIIi..........",
    ".ii66666666666666666i...........",
    "...iiiiiiiiiiiiiiiii............",
]

FROST_WYRM_HEAD = [
    "...........7....................",
    "...........j7...7...............",
    "............jj..j7..............",
    ".............jjjjjjj............",
    "............jIIIIIIIjjjjj.......",
    "...........jII7#IIIIIIIIIjjjj...",
    "...........jIIIIIIIIIIIIIIIIIIj.",
    "...........IIIIIIIIIIiiiiiiiii..",
    "..........jIIIIIIIi7.7.7.7......",
    ".........jIIIIIIII..............",
    "........jIIIIIIIIi7.7.7.........",
    ".......jIIIIIii..iiiiiiii.......",
    "......jIIIIIi...................",
    "......jIIIIi....................",
    "......jIIIIi....................",
    "......iIIIIi....................",
]

ELDER_HOLLOW = [
    ".B........mm........LL........b.",
    "..B...mm.mLLm.m..L.LLLL.LL...b..",
    "..bBmmLLmLLLLmLmLLLLLLLLLLLLbb..",
    "...mLLLLLLLLLLLLLLLLLLLLLLLLL...",
    "..mLLmLLLLLlLLLLLLLLlLLLLLLLLL..",
    ".mLLLLLLLlLLLLmLLLLLLLlLLLLLLLL.",
    ".LLLlLLLLLLLLLLLLLLLLLLLLLLlLLL.",
    ".lLLLLLlLLLlLLLLLLLLlLLLlLLLLLl.",
    "..lllLlLLLLLLLLllLLLLLLLLlLlll..",
    "...l.l.llBlllBllllblllbll.l.l...",
    ".......lBb.BbbBbbbbbb.bbl.......",
    ".Bb.....Bbbbbbbbbbbbbbbb.....bb.",
    "B.Bb....Bbb222bbbb222bbb....bb.b",
    "...Bb..Bbb22O22bb22O22bbb..bb...",
    "....BbbBbbb222bbbb222bbbbbbb....",
    ".....bbBbbbbbbbbbbbbbbbbbbb.....",
    "........Bbbbbb2222bbbbbb........",
    "........Bbbbb2g22g2bbbbb........",
    "........Bbb22gOggOg22bbb........",
    "........Bbbb22222222bbbb........",
    "........Bbbbbbbbbbbbbbbb........",
    "........Bb3bbbbbbbbbb3bb........",
    ".......BBb3bBb3bb3bbb3bbb.......",
    "......BBb3.Bb3bbbb3bb.3bbb......",
    ".....BBb3..Bb3.bb.3bb..3bbb.....",
    "....BBb3...BBb3..3bbb...3bbb....",
    "...BBb3....BBb3..3bbb....3bbb...",
    "..BBb3.....bBBb33bbbb.....3bbb..",
    ".bbb3.....bbb3.33.3bbb.....3bbb.",
]

STORM_TITAN_BOLT = [
    ".....jj.........................",
    "....jjI.........................",
    "...jjI..........................",
    "...jjjjI........................",
    ".....jjI........................",
    "....jjI.........................",
    "................................",
    "................................",
    "................................",
    "...jjI..........................",
    "..jjI...........................",
    "..jjjjI.........................",
    "....jjI.........................",
    "...jjI..........................",
    "...jI...........................",
    "..........................j.....",
    ".........................j.I....",
    "..........................j..j..",
    "............................jI..",
]

STORM_TITAN = [
    "................................",
    "..............w..w..w...........",
    ".............wV.wV.wV...........",
    ".............VwwVwwVwv..........",
    ".............wVVVVVVVv..........",
    ".............VVVVVVVVv..........",
    ".............VjI#VjI#v..........",
    ".............VVVVVVVVv..........",
    "......wVv....v6666666v..........",
    "......VVVv..56666666665.........",
    ".......VVVwV5566666655VVVv......",
    ".......vVVVV555666655VVVVVv.....",
    "........VVVVVV555555VVVVVVVv....",
    "........vVVwVVVVVVVVVVVVvVVv....",
    ".........vVVVVvVVVVvVVVvVVVv....",
    "...........wVVVIvVVvVVVv.VVv....",
    "...........VVVIVVVVVVVvv.VVv....",
    "...........VVVVIVvVVVVVv.VVv....",
    "...........vVVIVVVVVVVvv.VVv....",
    "...........44445555544444.VVv...",
    "..........5444455544445544VVVv..",
    "..........4455444444455444wVVVv.",
    "...........4.44.4444.44.4.VVVVv.",
    "............wVVv....wVVv..vvvv..",
    "............VVVv....VVVv........",
    "............VVVv....VVVv........",
    "............vVVv....vVVv........",
    "...........wVVVv...wVVVv........",
    "..........wVVVVv..wVVVVv........",
    "..........vvvvvv..vvvvvv........",
]

STORM_TITAN_FIST = [
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "...wwVv.........................",
    "..wVVVVv........................",
    "..VVwVVv........................",
    "..vVVVvv........................",
    "...vvvv.........................",
]

IRON_JUGGERNAUT_HAMMER = [
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "...........................uT...",
    "...........................uT...",
    "...........................uT...",
    "........................uuuTTTt.",
    "........................uTTTTTt.",
    "........................ooooooo.",
    "........................uTTTTTt.",
    "........................uTTTTTt.",
    "........................ttttttt.",
]

IRON_JUGGERNAUT = [
    "................................",
    "..66........................66..",
    ".6556......................6556.",
    "..55........................55..",
    "..t#t......................t#t..",
    "..uTt......................tTT..",
    "..uTt......................tTT..",
    "..uTt.......tttttttt.......tTT..",
    ".uuuuuTt...ttTTTTTTtt...tTTTTTT.",
    "uuTTTTTTt.tTTTTTTTTTTt.tTTTTTTTT",
    "uTToTTTTTtuTTTTTTTTTTTtTTTTToTTT",
    "tTTTTTTTTtuTTTTTTTTTTTtTTTTTTTTt",
    "uuTTTTTTTtuTTTTuTTTTTTtTTTTTTTTT",
    "tTTTTTTTt.uTTTTuTTTTTT.tTTTTTTTt",
    ".tttttttt.uTTTTuTTTTTT.tttttttt.",
    "..uTTt...tuTTTTuTTTTTTt...tTTT..",
    "..uTTt...uTTTTTuTTTTTTT...tTTT..",
    ".uuTTtt..tTTTTTTTTTTTTt..ttTTTT.",
    ".uTTTTt..ttttttOOtttttt..tTTTTT.",
    ".uTTTTt..uTTTTTTTTTTTTT..tttttt.",
    ".tTTTTt..uTtTTt..tTTtTT.........",
    "..tttt...uTtTTt..tTTtTT.........",
    ".........tttttt..tttttt.........",
    "..........uTTt....tTTT..........",
    "..........uTTt....tTTT..........",
    ".........uuTTTt..tTTTTT.........",
    ".........uTtTTt..tTTtTT.........",
    "........uTTTTTt..tTTTTTT........",
    "........ttttttt..ttttttt........",
]

IRON_JUGGERNAUT_HELM = [
    "................................",
    "...............TT...............",
    "..............uTTt..............",
    "............uuuTTttt............",
    "...........uuTTTTTTTt...........",
    "...........uTTTTTTTTt...........",
    "...........u########t...........",
    "...........u#RRRRRR#t...........",
    "...........u########t...........",
    "...........uTT#T#T#Tt...........",
    "...........uTTTTTTTTt...........",
    "............tttttttt............",
]


ASSETS = {
    "bone_dragon": lambda: legend(BONE_DRAGON),
    "ember_colossus": lambda: legend(EMBER_COLOSSUS),
    "frost_wyrm": lambda: legend(FROST_WYRM_WING, FROST_WYRM_BODY, FROST_WYRM_HEAD),
    "elder_hollow": lambda: legend(ELDER_HOLLOW),
    "storm_titan": lambda: legend((STORM_TITAN_BOLT, {"I1": "I2", "I2": "I1"}), STORM_TITAN, STORM_TITAN_FIST),
    "iron_juggernaut": lambda: legend(IRON_JUGGERNAUT_HAMMER, IRON_JUGGERNAUT, IRON_JUGGERNAUT_HELM),
}


if __name__ == "__main__":
    sys.exit(pg.run(ASSETS, sys.argv[1:]))
