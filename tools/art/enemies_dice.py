"""Final art: enemies (ART_SPEC §4.5), shopkeeper, dice, glyphs, pips, overlays (§4.6).

Rune die bodies / face tiles and the num_<n> point badges live in tools/art/dice_runes.py and
are merged into ASSETS here.

    python tools/art/enemies_dice.py                       # write changed assets
    python tools/art/enemies_dice.py --only glyph_*        # only matching ids
    python tools/art/enemies_dice.py --preview captures/enemies_preview.png

Characters are hand-placed row grids of the *interior* (no exterior outline); the N0
outline is a final pass so every frame (breathing squash, hurt recoil) stays enclosed.
Eye letters let one grid serve every frame:
    e / E  eye pixel        open: N0          hurt: skin (S1 / S0)
    k / K  shut-eye pixel   open: skin        hurt: N0
so the hurt frame shows a closed-eye dash on the lower eye row.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelgrid import BASE_LEGEND, canvas, grid, outline, paste, run, sheet, squash  # noqa: E402

from PIL import Image  # noqa: E402

FRAME = 32
EYES_OPEN = {"e": "N0", "E": "N0", "k": "S1", "K": "S0"}
EYES_SHUT = {"e": "S1", "E": "S0", "k": "N0", "K": "N0"}


# --------------------------------------------------------------------------- helpers

def place(interior: Image.Image, dx: int = 0, size: tuple[int, int] = (FRAME, FRAME)) -> Image.Image:
    """Centre an interior grid horizontally, its lowest row on size[1]-2 (outline goes on the last row)."""
    w, h = size
    bbox = interior.getbbox()
    x = (w - (bbox[0] + bbox[2])) // 2 + dx
    y = (h - 1) - bbox[3]
    out = canvas(w, h)
    out.paste(interior, (x, y), interior)
    return out


def lean(img: Image.Image, bands: list[tuple[int, int]]) -> Image.Image:
    """Recoil shear: every row above `row` moves by `dx` (later bands win, list top-down last)."""
    w, h = img.size
    out = canvas(w, h)
    src = img.load()
    dst = out.load()
    for y in range(h):
        dx = 0
        for row, d in bands:
            if y < row:
                dx = d
        for x in range(w):
            if src[x, y][3] and 0 <= x + dx < w:
                dst[x + dx, y] = src[x, y]
    return out


def _count(img: Image.Image) -> int:
    return sum(1 for p in img.getdata() if p[3])


def character(rows: list[str], legend: dict | None = None, *, dx: int = 0,
              hurt_bands: list[tuple[int, int]] | None = None,
              idle1_legend: dict | None = None,
              props: list[tuple[list[str], int, int]] | None = None) -> Image.Image:
    """Grid -> 96x32 sheet: idle0, idle1 (1 px breath, feet fixed), hurt (recoil, eyes shut).

    `props` are grounded part grids (x, y in body-grid coordinates) that do not breathe or
    recoil; each gets its own N0 ring so it stays separated from the body it overlaps.
    """
    leg = dict(legend or {})
    props = props or []
    body0 = grid(rows, {**leg, **EYES_OPEN})
    whole = canvas(max([body0.width] + [len(p[0][0]) + p[1] for p in props]),
                   max([body0.height] + [len(p[0]) + p[2] for p in props]))
    paste(whole, body0, 0, 0)
    for prows, px_, py_ in props:
        paste(whole, grid(prows, leg), px_, py_)
    bbox = whole.getbbox()
    ox = (FRAME - (bbox[0] + bbox[2])) // 2 + dx
    oy = (FRAME - 1) - bbox[3]

    def body(extra: dict) -> Image.Image:
        out = canvas(FRAME, FRAME)
        img = grid(rows, {**leg, **extra})
        out.paste(img, (ox, oy), img)
        return out

    def with_props(frame: Image.Image) -> Image.Image:
        for prows, px_, py_ in props:
            part = canvas(FRAME, FRAME)
            pimg = grid(prows, leg)
            part.paste(pimg, (ox + px_, oy + py_), pimg)
            paste(frame, outline(part), 0, 0)
        return outline(frame)

    idle0 = body(EYES_OPEN)
    idle1 = squash(body({**EYES_OPEN, **(idle1_legend or {})}))
    hurt_src = body(EYES_SHUT)
    hurt = lean(hurt_src, hurt_bands or [(20, 1), (14, 2)])
    if _count(hurt) != _count(hurt_src):
        raise ValueError("hurt recoil pushed pixels off the canvas")
    return sheet([with_props(f) for f in (idle0, idle1, hurt)])


def ring_of(mask: Image.Image, key: str, size: int = 22, off: int = 1) -> Image.Image:
    """1 px ring hugging a silhouette (used for die_select / die_bound)."""
    base = canvas(size, size)
    base.paste(mask, (off, off), mask)
    ring = outline(base, key)
    px = ring.load()
    bp = base.load()
    for y in range(size):
        for x in range(size):
            if bp[x, y][3]:
                px[x, y] = (0, 0, 0, 0)
    return ring


# --------------------------------------------------------------------------- enemies

TORCH_VILLAGER = [
    "...............F....",  # 0  torch flame
    "..............FF....",
    "..............FgF...",
    ".............FFggF..",
    ".............FgggF..",
    ".............fFgFf..",  # 5
    "...33333333...fFf...",  #    messy hair
    "..3443333333..Bbb...",
    ".344333333333..Bb...",
    ".33S3SSS3SS33..Bb...",
    ".3SSSSSSSSSS3.SSS...",  # 10 fist over the torch
    ".SSSeSSSSeSSs.SSs...",
    ".SSk#SSSk#SSs.544...",
    ".SSSSSSSSSSss.544...",
    "..SSSSSSSSss..544...",
    "...sSSSSSss...544...",  # 15
    "..5########444544...",  #    chin line, raised arm
    ".5544333344444......",
    ".5454444443.........",
    ".5454BB4443.........",  #    patched tunic
    ".5454Bb4443.........",  # 20
    ".SSbbbbbbbb.........",  #    rope belt, hand
    ".Ss54444443.........",
    "...54444443.........",
    "...22222222.........",
    "...22222222.........",  # 25
    "...222..222.........",
    "...bbb..bbb.........",
    "..bbbb..bbbb........",
]

PITCHFORK_FARMER = [
    "................u.u.u.",  # 0 tines
    "................T.T.T.",
    "................T.T.T.",
    "....cccccccc....TTTTt.",  #   straw hat crown
    "...cBBBBBBBBb....tTt..",
    "...BBBBBBBBBb.....b...",  # 5
    "...3333333333.....b...",  #   hat band
    "ccccccBBBBBBBBbb..b...",  #   brim
    ".bbbbbbbbbbbbbb...b...",
    "..SSSSSSSSSSSs....b...",
    "..SSSeSSSSeSSs....b...",  # 10
    "..SSk#SSSk#SSs....b...",
    "..SSSSSSSSSSss....b...",
    "...SSSSSSSSss.....b...",
    "....sSSSSSss.....SSs..",  #   fist on the shaft
    "..55########55555SSs..",  # 15
    "..544544445455555.b...",
    "..544u4444u4......b...",  #   overall buttons
    "..5444444443......b...",
    "..SS44444443......b...",
    "..Ss44444443......b...",  # 20
    "....44444443......b...",
    "....44444443......b...",
    "....444..443......b...",
    "....444..443......b...",
    "....bbb..bbb......b...",  # 25
    "...bbbb..bbbb.....b...",
]

LANTERN_WATCHMAN = [
    "........333333........",  # 0 hood
    "......3445444433......",
    ".....345444444433.....",
    "....34544444444433....",
    "....34522222222433....",
    "....342SSSSSSSs233....",  # 5
    "....342SSeSSeSs233....",
    "BBb.342Sk#Sk#Ss233....",  #   wooden rattle
    "BBb.342sSSSSSss233....",
    "Bbb.3442ssssss2433....",
    ".b.3344443OO3444433...",  # 10 gold clasp
    "SSs334444444444443SSs.",  #    lantern hand
    "SSs3444444444443...o..",
    ".443444444444443..ooo.",
    ".443444444444443.oO7Oo",
    ".5434444444444443o7O7o",  # 15
    "..54444444444443.oOOOo",
    "..5444444444443...ooo.",
    "..54444444444443......",
    "..544444444444443.....",
    ".5444444444444443.....",  # 20
    ".54444444444444443....",
    ".54444443444444443....",
    ".5444443.34444444443..",
    ".333333...3333333333..",
]

GUARD_CAPTAIN = [
    "....................u...",  # 0 halberd spike
    "........RRr.........Tu..",  #   red plume
    ".......RRRRr.......tTuu.",
    ".......RRRrr......ttTuuu",
    "........Rrr........tTuuT",
    ".....uuTTTTTt.......Tut.",  # 5 helmet
    "....uTTTTTTTTt......b...",
    "...uTTTTTTTTTTt.....b...",
    ".uuTTTTTTTTTTTTtt...b...",
    "..tttttttttttttt....b...",
    "...SSSSSSSSSSSs.....b...",  # 10
    "...SSSeSSSSeSSs.....b...",
    "...SSk#SSSk#SSs.....b...",
    "...SSSSbbbbSSss.....b...",  #    moustache
    "....sSSSSSSSss.....SSs..",
    "..uT##########TTTTTSSs..",  # 15
    "..ttttTTRRTTTtTTTTT.b...",  #    round shield, tabard
    ".tRRRRtTRRTTTt......b...",
    "tRRRRRRtRRTTTt......b...",
    "tRRuuRRtRRTTTt......b...",
    "tRRuTRrt333333......b...",  # 20
    "tRRRRrrtRR4443......b...",
    ".trrrrt4RR4443......b...",
    "..tttt44RR4443......b...",
    "....4444..4443......b...",
    "....TTTt..TTTt......b...",  # 25
    "...ttttt..ttttt.....b...",
]

MONSTER_HUNTER = [
    "......22222222..........",  # 0 messy hair
    "....22322222222.........",
    "...2232222222222........",
    "...2S2SSS2SSS222........",
    "...SSSSSSSSSSS2.........",
    "...SSSeSSSSeSS2.........",  # 5
    "...SSk#SSSk#SS2.........",
    "...SSSSSSSSSSss.........",
    "....sSSSSSSSss..........",
    "..rRRRRRRRRRRRr.........",  #   red scarf
    "RRRRBbbRRrbbbbBb..T.....",  # 10
    ".RrBBbb2rr2bbbbbb.T.....",
    "..rBBbb2222bbbbbb..T....",
    "...BBbSS22bbbSSbb..T....",  #   crossbow, both hands
    "...Bb3333333333333333TTu",
    "...BbSS22222bSSbbb.T....",  # 15
    "...Bbbb22222bbbbbb.T....",
    "...Bbbb22222bbbbbb.T....",
    "...Bb3333333333bbbT.....",  #   belt
    "...Bbbc2c2c222bbbb......",  #   stakes
    "...BbbB2B2B222bbbb......",  # 20
    "...Bbb.b.b.bb.bbbb......",
    "..Bbbb2222222bbbbb......",
    "..Bbb222...222bbbb......",
    "..Bb.333...333.bbb......",
    "....3333...3333.........",  # 25
]

EXORCIST = [
    "......o....O....o..........",  # 0 sun-disc rays
    "........OOOOOOO............",
    "......OO77OOOOOOo..........",
    "...o.O7OOOOOOOOOOo.o.......",
    "....OOOOSSSSSSSoooo........",
    "....OOOSSSSSSSSSooo........",  # 5
    ".o..OO6SSSSSSSSS6oo.o......",
    "....OO66SSSSSSS66oo........",
    "....OO66SeSSSeS66oo.....j..",
    "....oO6Sk#SSk#SS6oo...j....",
    "....oo6SSSSSSSSs6oo.....I.j",  # 10 holy water splash
    ".....o6S6666666S6o...7...I.",
    ".......666666666.....j.j...",
    "....7777776667777...jIj....",
    "...77jj777O777jj66777IIj...",
    "...77jj77OOO77jj666666SSs..",  # 15
    "...77jj777o777jj666...Ss...",
    "..777jj7777777jj666........",
    "..777jj7777777jj6665.......",
    "..777jj7777776jj6665.......",
    ".7777jj7777776jj66655......",  # 20
    ".7777jj7777766jj66655......",
    ".7777jj7777766jj666555.....",
    ".777jjj77777666jjj6655.....",
    "77777jj777776666jj66655....",
    "7777jj7777766666jj66655....",  # 25
    "OOOOOOOOOOOOOOOOOOooooo....",
    "6666666666666666665555.....",
]

WITCH_HUNTER = [
    "........222222222..........",  # 0 hat crown
    ".......23222222222.........",
    ".......32222222222.........",
    ".......22222222222.........",
    ".......uuuutTtuuuu.........",  #   silver band
    ".33333333333333333333332...",  # 5 brim
    "..222222222222222222222....",
    "......2222222222222........",
    "......SS222SSS222SS.....u..",  #   stern brows, silver dagger
    "......SSSeSSSSSeSSs.....uT.",
    "......SSk#SSSSk#SSs.....uT.",  # 10
    "......SSSSSSSSSSSss.....uT.",
    ".......sSSS222SSSs......uT.",
    "........sss222sss......tRt.",
    "..5.5.5.##########.....SSs.",
    ".5.5.5.5RR33333333332222SSs",  # 15 net over the shoulder, red sash
    "5.5.5.5.4RR3333333332222...",
    ".5.5.5.54RRR333333332......",
    "5.5.5.5.443RRR33333332.....",
    ".5.5.5.5443RRR3333332......",
    "..5.5.5.4433RRR333332......",  # 20
    ".5.5.5.54433RRr333332......",
    "..5.5.5.44333rRR33332......",
    "...5.5.444333rrRr3332......",
    "....5..44433333RRr332......",
    "......4443333333rr3322.....",  # 25
    ".....44433332333333322.....",
    ".....4443332.23333332......",
    "......uuuu.....uuuu........",
]

BELL_RINGER = [
    "bBBBBb......................",  # 0 wooden striker
    "BBBBBb......................",
    "bbbbbb......................",
    "..b.........................",
    "..b......3333...............",
    "..b....334444433............",  # 5 hood
    "..b...34544444443...........",
    "..b..3454444444443..........",
    "..b..345444444444333........",  #   hunch
    "..b..34522222222443333......",
    "..b..342SSSSSSs2443333......",  # 10
    "..b..342SeSSeSs24433333.....",
    "..b..342k#Sk#Ss244433333....",
    "..b..342sSsSSss24433333.....",
    ".SSs.3442sssss24443333......",  #   rope over the shoulder
    ".SSs34444222224444433B",  # 15 rope over the shoulder
    "..543444444444444444Bb",
    "..54344444444444444443",
    "..5434444b44444444443",
    "..54444444444444444443",
    "..54444444444444444443",  # 20
    "..5444444444444444444",
    "...54444444b4444444443",
    "...5444444444444444443",
    "...5444444444444444443",
    "...54444444444444444.",  # 25
    "...5444444444444444..",
    "....544444444444444..",
    "....3333333...33333..",
    "....bbbb......bbbb...",
]

BRONZE_BELL = [  # prop at (17, 15): grounded, does not breathe
    ".....ooo.....",
    ".....o#o.....",
    "....oOOOo....",
    "...oO7OOOo...",
    "...OO7OOOo...",
    "..oO77OOOOo..",
    "..OO7OOOOOo..",
    "..OO7OOOOOo..",
    ".oOO7OOOOOOo.",
    ".ooooooooooo.",
    ".OO7OOOOOOOo.",
    "oOOOOOOOOOOoo",
    "OOOOOOOOOOOOo",
    "obbbbbbbbbbbo",
    ".ooooooooooo.",
]

INQUISITOR = [
    ".........RRRRRRR...........",  # 0 tall red hat
    "........RRRRRRRRr..........",
    "........RRRRRRRRr..........",
    "........RR7777RRr..........",  #   open-eye emblem
    "........R77##77Rr..........",
    "........R7#O#7RRr..........",  # 5
    "........RR7777RRr..........",
    "........RRRRRRRrr..........",
    ".......OOOOOOOOOoo.........",  #   gold band
    "......RRRRRRRRRRRrr........",
    "........SSSSSSSSs..........",  # 10
    ".......SSeSSSSeSs..........",
    ".......Sk#SSSk#Ss..........",
    ".......SSSSSSSSss..........",
    "........sSSSSSss...........",
    "....rRR#########RRr........",  # 15
    "...rRRRRR7777RRRRRr........",
    "..rRRRRRR7RR7RRRRRRr.......",
    "..RRRSSccccccccccSSRr......",  #   scroll held in both hands
    "..RRRSSBBBBBBBBBBSSRrr.....",
    "..RRRRRc55c55c5cBRRRrc.....",  # 20
    ".RRRRRRcccccccccBRRRrcB....",
    ".RRRRRRc5c555c5cBRRRrrcB...",
    ".RRRRRRccccccccBBRRRrrrcB..",
    ".RRRRRRc55c5c55cBRRRrrr.cB.",
    "RRRRRRRccccccccBBRRRrrrr.cB",  # 25
    "RRRRRRRc5c55c5ccBRRRrrrr.cB",
    "7777777ccccccccBB77777777cB",
    "rrrrrr.BBBBBBBBB.rrrrrrrcBb",
    "................bbbbbbbbbb.",
]

SHOPKEEPER = [
    "..........22222222..............",  # 0 top hat
    "..........24222222..............",
    "..........24222222..............",
    "..........24222222..............",
    "..........OOOOOOOO..............",  #   gold band
    "........322222222222............",  # 5 brim
    "..........cccccccB..............",  #   skull
    ".........ccccccccBB.............",
    ".........c##cc##cBb.............",
    ".........c#Gc#GcBBb.............",  #   glinting eyes
    ".........cccc#ccBbb.............",  # 10
    "..........BcBcBcBb..............",
    "...........bbbbbb...............",
    ".......3444#4444#4443...........",  #   coat, bow tie
    "......34444##44##44443..........",
    "......3444c#c44#c#4443..........",  # 15 ribs under the coat
    ".....344444c4c4c4c44443.........",
    ".....3444444c4c4c4444443........",
    ".....3cc44444444444cc3..........",  #   bony hands on the lid
    "........55555555........oOo.....",  #   coffin lid, coin stack
    "......55444444445555555oOOOo....",  # 20
    "....55443333333344444445555555..",
    "..55443344444444333333344444445.",
    "5544334444444444444444433333342.",
    "5433444444444OOOOo4444444444342.",
    "5434444444444Ooooo4444444444342.",  # 25 brass plaque
    "5433444444444444444444433333342.",
    "2244334444444444333333344444442.",
    "..2244333333333344444442222222..",
    "....2244444444442222222.........",
    "......2222222222................",  # 30
]


def shopkeeper() -> Image.Image:
    """64x32: idle0, idle1 (head and hat sink 1 px, eye glints dim). The counter never moves."""
    def frame(extra: dict) -> Image.Image:
        return place(grid(SHOPKEEPER, extra))
    f0 = frame({"G": "G1"})
    f1 = squash(frame({"G": "G0"}))
    return sheet([outline(f0), outline(f1)])


# --------------------------------------------------------------------------- dice

DIE_BODY = [
    "..################..",
    ".#7ccccccccccccccc#.",
    "#7ccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#ccccccccccccccccBB#",
    "#BBBBBBBBBBBBBBBBBB#",
    "#bbbbbbbbbbbbbbbbbb#",
    ".#bbbbbbbbbbbbbbbb#.",
    "..################..",
]

DIE_ROLL = [
    [  # tilted ~20 degrees clockwise
        "....................",
        "..........####......",
        ".......###7ccB#.....",
        "....###7cccccB#.....",
        "...#7cccccccccB#....",
        "..#cccccccccccB#....",
        "..#cccccccccccB#....",
        "..#BcccccccccccB#...",
        "..#bcccccccccccB#...",
        "..#bBcccccccccccB#..",
        "...#bcccccccccccB#..",
        "...#bcccccccccccB#..",
        "....#BcccccccBBBb#..",
        "....#bccccBBBbbbb#..",
        "....#bBBBBbbbbbb#...",
        ".....#bbbbbbb###....",
        ".....#bbbb###.......",
        "......####..........",
        "....................",
        "....................",
    ],
    [  # corner-on cube: top, left and right faces
        "....................",
        ".........##.........",
        ".......##cc##.......",
        ".....##7cccccc##....",
        "...##cccccccccccc##.",
        "..#ccccccccccccccc#.",
        "..#BBccccccccccbbb#.",
        "..#BBBBccccccbbbbb#.",
        "..#BBBBBBccbbbbbbb#.",
        "..#BBBBBBBbbbbbbbb#.",
        "..#BBBBBBBbbbbbbbb#.",
        "..#BBBBBBBbbbbbbbb#.",
        "..#BBBBBBBbbbbbbbb#.",
        "..#BBBBBBBbbbbbbbb#.",
        "...##BBBBBbbbbbb##..",
        ".....##BBBbbbb##....",
        ".......##Bbb##......",
        ".........##.........",
        "....................",
        "....................",
    ],
    [  # diamond (45 degrees)
        ".........#..........",
        "........#7#.........",
        ".......#7cB#........",
        "......#7cccB#.......",
        ".....#ccccccB#......",
        "....#ccccccccB#.....",
        "...#ccccccccccB#....",
        "..#ccccccccccccB#...",
        ".#ccccccccccccccB#..",
        ".#BcccccccccccccB#..",
        ".#bBcccccccccccBb#..",
        ".#bbBcccccccccBbb#..",
        "..#bbBcccccccBbb#...",
        "...#bbBcccccBbb#....",
        "....#bbBcccBbb#.....",
        ".....#bbBBBbb#......",
        "......#bbbbb#.......",
        ".......#bbb#........",
        "........###.........",
        "....................",
    ],
    [  # squashed landing, side showing
        "....................",
        "....................",
        "....................",
        "....................",
        "..################..",
        ".#7ccccccccccccccc#.",
        "#7ccccccccccccccccB#",
        "#cccccccccccccccccB#",
        "#cccccccccccccccccB#",
        "#cccccccccccccccccB#",
        "#cccccccccccccccccB#",
        "#cccccccccccccccccB#",
        "#cccccccccccccccccB#",
        "#ccccccccccccccccBB#",
        "#BBBBBBBBBBBBBBBBBB#",
        "#bbbbbbbbbbbbbbbbbb#",
        "#bbbbbbbbbbbbbbbbbb#",
        ".#bbbbbbbbbbbbbbbb#.",
        "..################..",
        "....................",
    ],
]

# 12x12 glyphs, interior only (outline pass adds the N0 ring); drawn in a 10x10 box.
GLYPHS = {
    "bone": [
        "cc......cc",
        "cBc....cBc",
        ".cBb..cBb.",
        "..cBbcBb..",
        "...cBBb...",
        "...cBBb...",
        "..cBbcBb..",
        ".cBb..cBb.",
        "cBb....cBb",
        "cb......bb",
    ],
    "fire": [
        "....F.....",
        "....FF....",
        "...FgF....",
        "...FggF...",
        "..FFggFF..",
        "..FgggFF..",
        ".FggggggF.",
        ".FgggggFf.",
        ".fFgggFff.",
        "..ffFFff..",
    ],
    "ice": [
        "j...j...j.",
        ".I..I..I..",
        "..I.I.I...",
        "...III....",
        "IIIIjIIII.",
        "...III....",
        "..I.I.I...",
        ".I..I..I..",
        "j...j...j.",
        "..........",
    ],
    "leaf": [
        ".......mm.",
        ".....mmLL.",
        "....mLLLL.",
        "...mLLLlL.",
        "..mLLLlLL.",
        "..LLLlLLl.",
        ".mLLlLLl..",
        ".LLlLLl...",
        ".lLLll....",
        "l.........",
    ],
    "volt": [
        "....wVVV..",
        "...wVVV...",
        "..wVVV....",
        ".wVVVVVVV.",
        "....VVVv..",
        "...VVVv...",
        "..VVVv....",
        ".VVv......",
        "VVv.......",
        "Vv........",
    ],
    "metal": [
        "...uuuu...",
        "..uTTTTt..",
        ".uTTTTTTt.",
        "uTTT##TTTt",
        "uTT####TTt",
        "uTT####TTt",
        "uTTT##TTTt",
        ".TTTTTTtt.",
        "..TTTTtt..",
        "...tttt...",
    ],
    "wild": [
        "..........",
        "...7777...",
        ".77777777.",
        "777OOOO777",
        "77OOOOOO77",
        "77OOOOOO77",
        "777OOOO777",
        ".77777777.",
        "...7777...",
        "..........",
    ],
}

GLYPHS8 = {
    "bone": ["cccccc", "c#cc#c", "c#cc#c", "cccccc", ".cccc.", ".c##c."],  # skull, as glyph_bone
    "fire": ["..F...", "..FF..", ".FgF..", ".FggF.", "FggggF", ".FFFF."],
    "ice": ["j.j.j.", ".III..", "jIjIj.", ".III..", "j.j.j.", "......"],
    "leaf": ["....mL", "..mLLL", ".mLLlL", ".LLlL.", ".Ll...", "l....."],
    "volt": ["..wVV.", ".wVV..", "wVVVV.", "..VVV.", ".VV...", ".V...."],
    "metal": [".uuuu.", "uTTTTu", "uT##Tu", "uT##Tu", "uTTTTu", ".uuuu."],
    "wild": [".7777.", "77OO77", "7OOOO7", "7OOOO7", "77OO77", ".7777."],
}

PIP_RAMP = {"bone": "B", "fire": "F", "ice": "I", "leaf": "L", "volt": "V", "metal": "T"}
PIPS = {  # 4x4 marks inside a 6x6 dot
    "bone": ["cccc", "c##c", "cccc", ".cc."],
    "fire": [".g..", ".gg.", "gggg", ".gg."],
    "ice": ["j.j.", ".jj.", ".jj.", "j..j"],
    "leaf": ["..mm", ".mm.", "mmm.", "m..."],
    "volt": [".ww.", "ww..", ".ww.", "ww.."],
    "metal": [".uu.", "u##u", "u##u", ".uu."],
}

FACE_TILE = [
    ".##############.",
    "#7ccccccccccccc#",
    "#cccccccccccccc#",
    "#cccccccccccccc#",
    "#cccccccccccccc#",
    "#cccccccccccccc#",
    "#cccccccccccccc#",
    "#cccccccccccccc#",
    "#cccccccccccccc#",
    "#cccccccccccccc#",
    "#cccccccccccccc#",
    "#cccccccccccccc#",
    "#cccccccccccccc#",
    "#cccccccccccccc#",
    "#BBBBBBBBBBBBBB#",
    ".##############.",
]

SHACKLE_CHAIN = [
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "##..................",
    "TT##.###.###.###.###",
    "#tTT#TTT#TTT#TTT#TT#",
    "##t#T#tT#T#t#T#tT#t#",
    "#tTT#TTt#TTt#tTT#tT#",
    "TT##.###.###.###.###",
    "##..................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
]


def die_body() -> Image.Image:
    return grid(DIE_BODY)


def die_roll() -> Image.Image:
    return sheet([grid(f, width=20) for f in DIE_ROLL])


WILD12 = [  # own outline: lashes, almond eye, dark iris, gold star pupil
    "............",
    "..#..#..#...",
    "...#####....",
    "..#77777#...",
    ".#77###77#..",
    "#77##O##77#.",
    "#77#OOO#77#.",
    "#77##O##77#.",
    ".#77###77#..",
    "..#77777#...",
    "...#####....",
    "............",
]
WILD8 = [
    "........",
    "..####..",
    ".#7##7#.",
    "#7#OO#7#",
    "#7#OO#7#",
    ".#7##7#.",
    "..####..",
    "........",
]


def glyph(name: str) -> Image.Image:
    if name == "wild":
        return grid(WILD12, width=12)
    img = canvas(12, 12)
    paste(img, grid(GLYPHS[name], width=10), 1, 1)
    return outline(img)


def glyph8(name: str) -> Image.Image:
    if name == "wild":
        return grid(WILD8, width=8)
    img = canvas(8, 8)
    paste(img, grid(GLYPHS8[name], width=6), 1, 1)
    return outline(img)


def pip(name: str) -> Image.Image:
    r = PIP_RAMP[name]
    dark = {"T": "t"}.get(r, r.lower())
    dot = [
        ".####.",
        "#MMMM#",
        "#MMMM#",
        "#MMMM#",
        "#MMMD#",
        ".####.",
    ]
    img = grid(dot, {"M": BASE(r), "D": BASE(dark)})
    paste(img, grid(PIPS[name], width=4), 1, 1)
    return img


def BASE(letter: str) -> str:
    return BASE_LEGEND[letter]


def die_select() -> Image.Image:
    return ring_of(grid(DIE_BODY), "G1")


def die_bound() -> Image.Image:
    ring = ring_of(grid(DIE_BODY), "G1")
    return recolor_hex(ring, "G1", "#ffffff")


def recolor_hex(img: Image.Image, key: str, hexv: str) -> Image.Image:
    from palette import hex_to_rgb, rgba
    src = rgba(key)[:3]
    rgb = hex_to_rgb(hexv)
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] and px[x, y][:3] == src:
                px[x, y] = (*rgb, 255)
    return out


def die_shackle() -> Image.Image:
    body = grid(DIE_BODY)
    out = canvas(20, 20)
    bp = body.load()
    op = out.load()
    from palette import rgba
    n0 = rgba("N0")
    for y in range(20):
        for x in range(20):
            if bp[x, y][3] and (x + y) % 2 == 0:
                op[x, y] = n0
    chain = grid(SHACKLE_CHAIN, width=20)
    paste(out, chain, 0, 0)
    return out


def face_tile() -> Image.Image:
    return grid(FACE_TILE, width=16)


# --------------------------------------------------------------------------- registry

ASSETS = {
    "mob_torch_villager": lambda: character(TORCH_VILLAGER, idle1_legend={"g": "F1", "F": "F2"}),
    "mob_pitchfork_farmer": lambda: character(PITCHFORK_FARMER),
    "mob_lantern_watchman": lambda: character(LANTERN_WATCHMAN, idle1_legend={"7": "G1"}),
    "champ_guard_captain": lambda: character(GUARD_CAPTAIN),
    "champ_monster_hunter": lambda: character(MONSTER_HUNTER),
    "boss_exorcist": lambda: character(EXORCIST),
    "boss_witch_hunter": lambda: character(WITCH_HUNTER),
    "boss_bell_ringer": lambda: character(BELL_RINGER, props=[(BRONZE_BELL, 17, 15)],
                                           hurt_bands=[(22, 1), (12, 2)]),
    "boss_inquisitor": lambda: character(INQUISITOR),
    "shopkeeper_undertaker": lambda: shopkeeper(),
    "die_body": die_body,
    "die_roll": die_roll,
    "die_select": die_select,
    "die_bound": die_bound,
    "die_shackle": die_shackle,
    "face_tile": face_tile,
}
for _n in GLYPHS:
    ASSETS[f"glyph_{_n}"] = (lambda n=_n: glyph(n))
    ASSETS[f"glyph8_{_n}"] = (lambda n=_n: glyph8(n))
for _n in PIPS:
    ASSETS[f"pip_{_n}"] = (lambda n=_n: pip(n))

# Rune die bodies, rune face tiles and point badges (tools/art/dice_runes.py) are generated
# through this module as well.
from dice_runes import ASSETS as RUNE_ASSETS  # noqa: E402

ASSETS.update(RUNE_ASSETS)


if __name__ == "__main__":
    sys.exit(run(ASSETS, sys.argv[1:]))
