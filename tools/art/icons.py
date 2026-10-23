"""Final icons (ART_SPEC §5): trinkets (relics), gear (equipment) and stat icons.

    python tools/art/icons.py                       # create missing files only
    python tools/art/icons.py --only blood_moon     # (re)write matching ids
    python tools/art/icons.py --preview captures/icons_preview.png

16x16 icons: 1 px transparent margin (live area 14x14), N0 outline, <= 6 colours, light from
the top-left, one idea per icon, no text. Stat icons are 8x8. Tier-2 gear is drawn as the
upgraded twin of its tier-1 icon (same silhouette idea, bigger / darker / gold trim).

Potions, gems and coffers live in tools/art/items.py; their ASSETS are merged here, so this
module's commands cover every 16x16 item icon.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelgrid import canvas, grid, paste, run  # noqa: E402

from PIL import Image  # noqa: E402

# Manifest ids are unique (vfx ids carry a vfx_ prefix), so pixelgrid's lookup is used as is.


def icon(rows: list[str], legend: dict | None = None, size: int = 16) -> Image.Image:
    """Exact-size grid: `size` rows, every row `size` wide."""
    if len(rows) != size:
        raise ValueError(f"{len(rows)} rows, expected {size}")
    for y, r in enumerate(rows):
        if len(r) != size:
            raise ValueError(f"row {y} is {len(r)} wide, expected {size}: {r!r}")
    return grid(rows, legend, size)


ASSETS: dict = {}


def asset(asset_id: str):
    def deco(fn):
        ASSETS[asset_id] = fn
        return fn
    return deco


# =========================================================================== relics (§5.1)

@asset("rattle_drum")
def rattle_drum():  # drum with two bone sticks
    return icon([
        "................",
        "..##........##..",
        ".#cc#......#cc#.",
        ".#cB#......#cB#.",
        "..##c#....#c##..",
        "....#c#..#c#....",
        ".....#c##c#.....",
        "...####cc####...",
        "..#cccccccccB#..",
        "..#BBBBBBBBBB#..",
        "..#OOOOOOOOOO#..",
        "..#cRRcRRcRRr#..",
        "..#RccRccRccr#..",
        "..#OOOOOOOOOO#..",
        "...##########...",
        "................",
    ])


@asset("ember_jar")
def ember_jar():  # squat glass jar, red lid, glowing embers
    return icon([
        "................",
        "....########....",
        "....#gFFFFf#....",
        "....#ffffff#....",
        "...##########...",
        "..#6333333333#..",
        "..#63333g3333#..",
        "..#633333333g#..",
        "..#63g3333333#..",
        "..#6333333F33#..",
        "..#633F3FgF33#..",
        "..#63FgFFgFf3#..",
        "..#3fFgfFgFff#..",
        "..#ffffffffff#..",
        "...##########...",
        "................",
    ])


@asset("wisp_jar")
def wisp_jar():  # round bottle with a cork, tiny ghost wisp inside
    return icon([
        "................",
        "......####......",
        ".....#BBBB#.....",
        ".....######.....",
        "......#63#......",
        "....###33###....",
        "...#66333333#...",
        "..#6333jj3333#..",
        "..#633jjjj333#..",
        "..#63jj#j#jI3#..",
        "..#63jjjjjjI3#..",
        "..#63jjjjjjI3#..",
        "..#633jIjIj33#..",
        "...#33333333#...",
        "....########....",
        "................",
    ])


@asset("frost_lantern")
def frost_lantern():  # boxy metal lantern with a ring, blue flame
    return icon([
        "................",
        "......####......",
        ".....#T##T#.....",
        "....#TTTTTt#....",
        "...#TTTTTTTt#...",
        "...##########...",
        "...#tiiiIiit#...",
        "...#tiiIIiit#...",
        "...#tiIjjIit#...",
        "...#tiIjjIit#...",
        "...#tiIjjIit#...",
        "...#tiiIIiit#...",
        "..############..",
        "..#TTTTTTTTTt#..",
        "..############..",
        "................",
    ])


@asset("gravedigger_lamp")
def gravedigger_lamp():  # brass oil lamp, glowing glass chimney
    return icon([
        "................",
        "......####......",
        "......#wg#......",
        ".....#wggg#.....",
        "....#wggFgg#....",
        "....#wgFFgg#....",
        "....#wgFFgg#....",
        ".....#ggFg#.....",
        "....#oooooo#....",
        "...#wOOOOOOo#...",
        "..#wOOOOOOOOo#..",
        "..#OOOOOOOOoo#..",
        "...#oooooooo#...",
        "....#OOOOOo#....",
        "....########....",
        "................",
    ], {"w": "V2"})


@asset("moss_charm")
def moss_charm():  # round stone amulet on a cord, mossy patches
    return icon([
        "................",
        "..5..........5..",
        "...5........5...",
        "....5......5....",
        ".....5....5.....",
        "......5..5......",
        ".......55.......",
        "....########....",
        "...#555mm444#...",
        "..#55mmLLm444#..",
        "..#5mLLLLl444#..",
        "..#54lLll4444#..",
        "..#4444444mLl#..",
        "...#44444lll#...",
        "....########....",
        "................",
    ])


@asset("lightning_rod")
def lightning_rod():  # iron rod with a spark bolt beside its tip
    return icon([
        "................",
        "....#......##...",
        "...#u#....#wV#..",
        "...#u#...#wV#...",
        "..#uTt#.#wV###..",
        "...#Tt#.#wwwwV#.",
        "...#Tt#..##wV#..",
        "...#Tt#..#wV#...",
        "...#Tt#.#wV#....",
        "...#Tt#.#V#.....",
        "...#Tt#..#......",
        "..#uTTt#........",
        ".#uTTTTt#.......",
        ".#tttttt#.......",
        "..######........",
        "................",
    ], {"w": "V2"})


@asset("iron_nail")
def iron_nail():  # big bent nail
    return icon([
        "................",
        "....#######.....",
        "...#uuuuuuT#....",
        "...#TTTTTTt#....",
        "....###uT###....",
        "......#uT#......",
        "......#uT#......",
        "......#uT#......",
        "......#uTt#.....",
        ".......#uTt#....",
        "........#uTt#...",
        ".........#uTt#..",
        "..........#uT#..",
        "...........#T#..",
        "............#...",
        "................",
    ])


@asset("grave_robber")
def grave_robber():  # tied sack, coins spilling out
    return icon([
        "................",
        "....#....#......",
        "...#B#..#B#.#...",
        "....#B##B#.#O#..",
        ".....#bb#..#o#..",
        "....#cBb#...#...",
        "...#cBBBb#......",
        "..#cBBBBBb#.....",
        ".#cBBBBBBBb#....",
        ".#BBBBBBBBb#....",
        ".#BBBBBB###.....",
        "..#bbbb#OOo#....",
        "...####ooo###...",
        "........###Oo#..",
        "...........##...",
        "................",
    ])


@asset("bone_saw")
def bone_saw():  # saw blade with a bone handle
    return icon([
        "................",
        "................",
        "................",
        "..........##....",
        "..#######.#cc#..",
        ".#uuuuuuu##ccB#.",
        ".#TTTTTTTcccBB#.",
        ".#TTTTTTT##cBB#.",
        ".#TTTTTTT#.#cB#.",
        ".#ttttttt#..##..",
        ".#t#t#t#t#......",
        "..#.#.#.#.......",
        "................",
        "................",
        "................",
        "................",
    ])


@asset("deep_freeze")
def deep_freeze():  # ice cube with a skull inside
    return icon([
        "................",
        "....#########...",
        "...#jjjjjjjjj#..",
        "..#jjjjjjjjjI#..",
        "..###########I#.",
        "..#jIIIIIIIIjI#.",
        "..#jIIccccIIjI#.",
        "..#jIcccccBIjI#.",
        "..#jIc#c#cBIjI#.",
        "..#jIcccccBIji#.",
        "..#jIIcBcBIIji#.",
        "..#jIIIIIIIIji#.",
        "..#jjjjjjjjjj#..",
        "..#iiiiiiiiii#..",
        "..############..",
        "................",
    ])


@asset("cold_hearth")
def cold_hearth():  # stone fireplace gone cold: snowy mantel, icicles, snow on the logs
    return icon([
        "................",
        "..############..",
        ".#777777777777#.",
        ".#555555555555#.",
        ".##############.",
        "..#54######54#..",
        "..#5472227254#..",
        "..#5472222254#..",
        "..#5422222254#..",
        "..#5422777254#..",
        "..#542BBBBB54#..",
        "..#54BBBBBB54#..",
        ".#555555555555#.",
        ".#444444444444#.",
        "..############..",
        "................",
    ], {"S": "N4"})


@asset("bone_pile")
def bone_pile():  # small heap of bones topped by a skull
    return icon([
        "................",
        "................",
        ".....######.....",
        "....#cccccB#....",
        "....#c#cc#B#....",
        "....#c#cc#B#....",
        "....#cccccB#....",
        "..##.#cBcB#.##..",
        ".#cc#.####.#cc#.",
        "..#cc#....#cc#..",
        "..##cc####cc##..",
        ".#cBcccccccccB#.",
        ".#B##########B#.",
        "..#..........#..",
        "................",
        "................",
    ])


@asset("grand_procession")
def grand_procession():  # banner on a pole, three marching skull-dots
    return icon([
        "................",
        "..#.............",
        ".#O##########...",
        ".#b#RRRRRRRR#...",
        ".#b#RRROORRr#...",
        ".#b#RROOOORr#...",
        ".#b#RRROORRr#...",
        ".#b#rrrrrrrr#...",
        ".#b#rrr##rrr#...",
        ".#b#r##..##r#...",
        ".#b##....###....",
        ".#b#..###cc###..",
        ".#b#.#cc#cc#cc#.",
        ".#b#.#cc####cc#.",
        "..#...##....##..",
        "................",
    ])


@asset("thrifty_ghost")
def thrifty_ghost():  # little ghost clutching a coin
    return icon([
        "................",
        "......####......",
        ".....#7777#.....",
        "....#777776#....",
        "...#77777776#...",
        "...#7#77#776#...",
        "...#7#77#776#...",
        "...#77777776#...",
        "..##77##776###..",
        ".#77#OOO#76#O#..",
        "..##OwOOO#6#O#..",
        "...#OOOOo#6##...",
        "...#7OOOo#66#...",
        "...#76###6#6#...",
        "....#.#..#.#....",
        "................",
    ], {"w": "N7"})


@asset("hybrid_vigor")
def hybrid_vigor():  # round potion, half leaf-green, half fire-orange
    return icon([
        "................",
        "......####......",
        "......#66#......",
        "......####......",
        "......#66#......",
        ".....#6666#.....",
        "....#6....6#....",
        "...#mmLLgFFF#...",
        "..#mmLLLgFFFF#..",
        "..#mLLLLgFFFF#..",
        "..#LLLLLgFFFF#..",
        "..#LLLLLgFFFF#..",
        "...#LLLLgFFF#...",
        "....#LLLgFF#....",
        ".....######.....",
        "................",
    ])


COFFIN = [  # 8x11 upright coffin, reused twice by COPYCAT_COFFIN
    "..####..",
    ".#5544#.",
    "#554443#",
    "#544443#",
    "#544443#",
    ".#5443#.",
    ".#5443#.",
    ".#5443#.",
    ".#5443#.",
    ".#5433#.",
    "..####..",
]


@asset("copycat_coffin")
def copycat_coffin():  # two identical coffins, one a step behind the other
    img = canvas(16, 16)
    coffin = grid(COFFIN, {"3": "N3"})
    paste(img, coffin, 7, 2)   # the copy, behind
    paste(img, coffin, 1, 4)   # the original, in front
    return img


@asset("piggy_coffin")
def piggy_coffin():  # pink coffin-shaped piggy bank: snout, ear, legs, coin dropping in
    return icon([
        "................",
        ".........##.....",
        "........#OO#....",
        "........#Oo#....",
        ".....##..##.....",
        "....#ss#######..",
        "....##SSSSSSS##.",
        ".####SSSSSSSSs#.",
        ".#SSS#SSSSSSSs#.",
        ".#S#S#SSSSSSss#.",
        ".#SSS#ssssssss#.",
        ".####ssssssss#..",
        ".....#s####s#...",
        ".....###..###...",
        "................",
        "................",
    ])


@asset("overgrowth")
def overgrowth():  # skull with a vine sprouting out of it
    return icon([
        "................",
        "..........##....",
        "...##....#mm#...",
        "..#mL#..#mLl#...",
        "..#mLl##mLl#....",
        "...#lLLL#l#.....",
        "....###L###.....",
        "...#cccLccc#....",
        "..#cccclccccB#..",
        "..#cc##cc##cB#..",
        "..#cc##cc##cB#..",
        "..#cccc#ccccB#..",
        "...#BcccccBB#...",
        "....#c#c#c#.....",
        ".....#####......",
        "................",
    ])


@asset("spirit_board")
def spirit_board():  # wooden talking board: rows of marks and a planchette (no brand marks)
    return icon([
        "................",
        "................",
        ".##############.",
        ".#SSSSSSSSSSSS#.",
        ".#s#s#s#s#s#ss#.",
        ".#ssss#####sss#.",
        ".#sss#ccccB#ss#.",
        ".#sss#ccscB#ss#.",
        ".#ssss#ccB#sss#.",
        ".#sssss#B#ssss#.",
        ".#s#ssss#sss#s#.",
        ".#ssssssssssss#.",
        ".#bbbbbbbbbbbb#.",
        ".##############.",
        "................",
        "................",
    ], {"S": "S1", "s": "S0"})


@asset("tactician_skull")
def tactician_skull():  # skull wearing a crested war helmet
    return icon([
        "................",
        ".......##.......",
        "......#RR#......",
        ".....#RRRR#.....",
        "....##RRRR##....",
        "...#cTTTTTTt#...",
        "..#TTTTTTTTTt#..",
        ".#tttttttttttt#.",
        "..#cccccccccB#..",
        "..#c##cccc##B#..",
        "..#c##cccc##B#..",
        "..#cccc##cccB#..",
        "...#cBccccBB#...",
        "....#c#c#c#.....",
        ".....######.....",
        "................",
    ])


@asset("crown_of_the_lich")
def crown_of_the_lich():  # spiked gold crown with a ghoul-green gem
    return icon([
        "................",
        "................",
        "...#....#....#..",
        "..#w#..#w#..#w#.",
        "..#O#.#wOo#.#O#.",
        "..#Oo##OOo##Oo#.",
        "..#wOOOOOOOOOo#.",
        "..#OOOO#mm#OOo#.",
        "..#OOO#mLLL#Oo#.",
        "..#OOOO#LL#OOo#.",
        "..#ooooooooooo#.",
        "..#wOOOOOOOOOo#.",
        "..#ooooooooooo#.",
        "...###########..",
        "................",
        "................",
    ], {"w": "V2"})


@asset("black_grimoire")
def black_grimoire():  # black book, gold eye clasp on the cover
    return icon([
        "................",
        "...###########..",
        "..#O333333333O#.",
        "..#32222222222#.",
        "..#32222OOO222#.",
        "..#3222O777O22#.",
        "..#322O7R#R7O2#.",
        "..#3222O777O22#.",
        "..#32222OOO222#.",
        "..#32222222222#.",
        "..#32222222222#.",
        "..#O222222222O#.",
        "..#77777777777#.",
        "...###########..",
        "................",
        "................",
    ], {"3": "N3", "2": "N2"})


@asset("elemental_convergence")
def elemental_convergence():  # ring of six element-coloured dots (metal = holed nut)
    return icon([
        "................",
        "................",
        "......###.......",
        ".....#FFF#......",
        "..####FFF####...",
        ".#ccc#FFF#VVV#..",
        ".#ccc#####VVV#..",
        ".#ccc#...#VVV#..",
        "..###.....###...",
        ".#ccc#...#LLL#..",
        ".#c#c#####LLL#..",
        ".#ccc#III#LLL#..",
        "..####III####...",
        ".....#III#......",
        "......###.......",
        "................",
    ])


@asset("trio_totem")
def trio_totem():  # carved totem pole: winged beaked head over two more faces
    return icon([
        "................",
        ".....######.....",
        ".##.#SSSSSs#.##.",
        ".#F##S#SS#s##F#.",
        ".#FF#SSFFSs#FF#.",
        "..#F#SSFFSs#F#..",
        "...##SSSSSs##...",
        "....#bbbbbb#....",
        "....#S#SS#s#....",
        "....#SSSSSs#....",
        "....#S7777s#....",
        "....#bbbbbb#....",
        "....#s#ss#b#....",
        "....#ss##sb#....",
        "....########....",
        "................",
    ], {"S": "S1", "s": "S0", "b": "B0", "F": "F1", "7": "N7"})


@asset("moon_charm")
def moon_charm():  # pale crescent moon charm hanging from a cord
    return icon([
        "................",
        "...55........5..",
        ".....555....5...",
        "........55.5....",
        ".........###....",
        ".......##wwV#...",
        ".....##7wwV#....",
        "....#7wwwV#.....",
        "...#7wwwV#......",
        "...#7wwwV#......",
        "...#7wwwV#......",
        "....#wwwwV#.....",
        ".....##wwwV#....",
        ".......##wwV#...",
        ".........###....",
        "................",
    ], {"w": "V2", "7": "N7"})


@asset("loaded_bone")
def loaded_bone():  # bone die with a heavy lead weight hooked to its corner
    return icon([
        "................",
        "................",
        "................",
        "..#######.......",
        ".#ccccccB#......",
        ".#c##cccB#......",
        ".#c##cccB#......",
        ".#ccc##cB####...",
        ".#ccc##cB#t#t#..",
        ".#ccccccB#ttt#..",
        ".#cccccc#TTTtt#.",
        ".#BBBBBB#TTTtt#.",
        ".#bbbbbb#TTttt#.",
        "..######.#####..",
        "................",
        "................",
    ])


@asset("gilded_tooth")
def gilded_tooth():  # big gold molar with two roots and a glint
    return icon([
        "................",
        "................",
        "...####..####...",
        "..#wOOO##OOOo#..",
        ".#w7OOOOOOOOOo#.",
        ".#wOOOOOOOOOoo#.",
        ".#wOOOOOOOOOoo#.",
        ".#OOOOOOOOOooo#.",
        "..#OOOOOOOOoo#..",
        "..#OOOOOOOooo#..",
        "..#OOOo##OOoo#..",
        "..#OOo#..#Ooo#..",
        "..#Oo#....#oo#..",
        "...##......##...",
        "................",
        "................",
    ], {"w": "V2", "7": "N7"})


@asset("last_rites")
def last_rites():  # last candle burning on a skull, wax dripping down its brow
    return icon([
        "................",
        ".......##.......",
        "......#gg#......",
        ".....#gFFg#.....",
        ".....#gFFg#.....",
        "......#gg#......",
        ".....#777B#.....",
        ".....#777B#.....",
        "..####777B####..",
        "..#ccc7cc7ccB#..",
        "..#c##cccc##B#..",
        "..#c##cccc##B#..",
        "..#ccccc#cccB#..",
        "...#c#c#c#cB#...",
        "....#########...",
        "................",
    ], {"7": "N7"})


@asset("blood_moon")
def blood_moon():  # full moon turned blood red, darker maria, pale rim light
    return icon([
        "................",
        ".....######.....",
        "...##SSRRRR##...",
        "..#SSRRRRRRRr#..",
        "..#SRRrRRRRrr#..",
        ".#SRRrrRRRRRrr#.",
        ".#SRRRRRRRrRrr#.",
        ".#RRRRRRRrrRrr#.",
        ".#RRRrRRRRRRrr#.",
        ".#RRrrrRRRRrrr#.",
        ".#RRRrRRRRrrrr#.",
        "..#RRRRRRrrrr#..",
        "..#rRRRRrrrrr#..",
        "...##rrrrrr##...",
        ".....######.....",
        "................",
    ], {"S": "S1"})


# ======================================================================= equipment (§5.3)

@asset("grave_bell")
def grave_bell():  # bronze bell on a hook with its clapper
    return icon([
        "................",
        ".......##.......",
        "......#tt#......",
        ".....######.....",
        ".....#wOOo#.....",
        "....#wOOOOo#....",
        "....#wOOOOo#....",
        "....#OOOOOo#....",
        "...#wOOOOOOo#...",
        "...#OOOOOOOo#...",
        "..#wOOOOOOOoo#..",
        "..#oooooooooo#..",
        "...####oo####...",
        "......#tt#......",
        ".......##.......",
        "................",
    ], {"w": "V2"})


@asset("loaded_cup")
def loaded_cup():  # leather dice cup, a die peeking over the rim
    return icon([
        "................",
        "................",
        "......####......",
        ".....#c#cB#.....",
        ".....#cc#B#.....",
        ".....#BBBB#.....",
        "..############..",
        "..#OOOOOOOOOO#..",
        "...#RRRRRRRr#...",
        "...#RRRRRRrr#...",
        "...#RRRRRRrr#...",
        "...#RRRRRRrr#...",
        "...#RRRRRrrr#...",
        "...#OOOOOOOO#...",
        "....########....",
        "................",
    ])


CUP = [  # 9x9 dice cup, reused twice by SECOND_CUP
    "#########",
    "#OOOOOOO#",
    ".#RRRRr#.",
    ".#RRRRr#.",
    ".#RRRrr#.",
    ".#RRRrr#.",
    ".#RRRrr#.",
    ".#OOOOO#.",
    "..#####..",
]


@asset("second_cup")
def second_cup():  # two dice cups, the second one a step behind
    img = canvas(16, 16)
    cup = grid(CUP)
    paste(img, cup, 6, 1)   # the second cup, behind
    paste(img, cup, 1, 6)   # the first, in front
    return img


@asset("reliquary")
def reliquary():  # ornate gold box with an arched lid and a red gem
    return icon([
        "................",
        "................",
        "......####......",
        "....##wOOo##....",
        "...#wOOOOOOo#...",
        "..#wOOOOOOOOo#..",
        "..############..",
        "..#wOOO##OOOo#..",
        "..#OOO#RR#OOo#..",
        "..#OOO#Rr#OOo#..",
        "..#OOOO##OOOo#..",
        "..#oooooooooo#..",
        "..#o#oooooo#o#..",
        "..############..",
        "................",
        "................",
    ], {"w": "V2"})


@asset("pocket_crypt")
def pocket_crypt():  # tiny stone mausoleum with a dark door
    return icon([
        "................",
        ".......##.......",
        "......#66#......",
        ".....#6655#.....",
        "....#666555#....",
        "...#66666555#...",
        "..############..",
        "...#6#5555#5#...",
        "...#6#5##5#5#...",
        "...#6#5#1#5#5#..",
        "...#6#5#1#5#5#..",
        "...#6#5#1#5#5#..",
        "..#66655555544#.",
        "..#############.",
        "................",
        "................",
    ])


@asset("haggler_lantern")
def haggler_lantern():  # warm lantern with a price tag on a string
    return icon([
        "................",
        "................",
        ".....####.......",
        "....#t##t#......",
        "...#TTTTTt#.....",
        "..#########.....",
        "..#tFFgFFt#.#...",
        "..#tFgggFt#.#...",
        "..#tFgggFt#.#...",
        "..#tFFgFFt##c#..",
        "..#tFFFFFt#c#c#.",
        "..#########ccc#.",
        "..#TTTTTTt#ccc#.",
        "..#############.",
        "................",
        "................",
    ])


@asset("death_knell")
def death_knell():  # GRAVE_BELL's big brother: a large black iron bell with a gold band
    return icon([
        "................",
        "......####......",
        ".....#o##o#.....",
        ".....######.....",
        "....#544443#....",
        "...#54444443#...",
        "...#54444443#...",
        "...#54444433#...",
        "..#5444444433#..",
        "..#5444444333#..",
        ".#OOOOOOOOOOOo#.",
        ".#544444443333#.",
        ".##############.",
        "......#oo#......",
        ".......##.......",
        "................",
    ], {"5": "N5", "4": "N4", "3": "N3"})


@asset("ossuary")
def ossuary():  # RELIQUARY's big brother: a bone shrine box with a skull front and gold bands
    return icon([
        "................",
        "......####......",
        "....##cccB##....",
        "...#cccccccB#...",
        "..#ccccccccBB#..",
        ".##############.",
        ".#OOOOOOOOOOOo#.",
        ".#BBBccccccBBb#.",
        ".#BBc##cc##cBb#.",
        ".#BBc##cc##cBb#.",
        ".#BBccc##cccBb#.",
        ".#BBBc#cc#cBBb#.",
        ".#OOOOOOOOOOOo#.",
        ".##############.",
        "................",
        "................",
    ])


@asset("black_market")
def black_market():  # HAGGLER_LANTERN's twin: hooded black lantern, ghost-green flame, a gold coin
    return icon([
        "................",
        "....#####.......",
        "...#43333#......",
        "..#4333333#.....",
        ".#433333333#....",
        ".###########....",
        "..#3LLmLL3#.#...",
        "..#3LmmmL3#.#...",
        "..#3LmmmL3#.#...",
        "..#3LLmLL3####..",
        "..#3LLLLL3#OO3#.",
        "..#########OO3#.",
        "..#4444443#333#.",
        "..#############.",
        "................",
        "................",
    ], {"4": "N4", "3": "N3"})


CRATE = [  # 7x7 wooden crate: light frame top-left, dark bottom-right, one diagonal brace
    "#######",
    "#SSSSb#",
    "#SssSb#",
    "#SsSsb#",
    "#SSssb#",
    "#bbbbb#",
    "#######",
]


@asset("overstock")
def overstock():  # three stacked crates
    img = canvas(16, 16)
    crate = grid(CRATE, {"S": "S1", "s": "S0", "b": "B0"})
    paste(img, crate, 1, 8)
    paste(img, crate, 7, 8)
    paste(img, crate, 4, 2)
    return img


@asset("overflowing_crypt")
def overflowing_crypt():  # OVERSTOCK's twin: one big crate, coins and a potion spilling out of it
    return icon([
        "................",
        "..........##....",
        ".........#ss#...",
        ".........#RR#...",
        "........#SRRR#..",
        "...###..#SRRR#..",
        "..#OOO#.#RRRR#..",
        ".#OO#OO##RRRR#..",
        ".#O#OOO#OO#OOO#.",
        ".#SSSSSSSSSSSS#.",
        ".#sssbsssbsssb#.",
        ".#sssbsssbsssb#.",
        ".#sssbsssbsssb#.",
        ".#bbbbbbbbbbbb#.",
        ".##############.",
        "................",
    ], {"S": "S1", "s": "S0", "b": "B0"})


@asset("grave_goods")
def grave_goods():  # clay funeral urn heaped with gold coins
    return icon([
        "................",
        "......#####.....",
        ".....#OOOOo#....",
        "....#OOoOOoo#...",
        "...#SSSSSSSSb#..",
        ".....#bsssb#....",
        "....#Ssssssb#...",
        "...#Sssssssbb#..",
        "..#Sssssssssbb#.",
        "..#Sssssssssbb#.",
        "..#ssssssssbbb#.",
        "...#sssssbbbb#..",
        ".....#sbbbb#....",
        "....#bbbbbbb#...",
        "....#########...",
        "................",
    ], {"S": "S1", "s": "S0", "b": "B0"})


@asset("dragon_hoard")
def dragon_hoard():  # GRAVE_GOODS's big brother: a mound of gold coins crowned by a skull
    return icon([
        "................",
        "................",
        ".....######.....",
        "....#cccccB#....",
        "....#c#cc#B#....",
        "....#cccccB#....",
        "...##BcBcBB##...",
        "..#OwOOOOOOOo#..",
        ".#OOOooOOwOOoo#.",
        ".#wOOOOOooOOOo#.",
        ".#OooOwOOOOOoo#.",
        ".#OOOOOOooOwoo#.",
        ".#OwOooOOOOooo#.",
        ".#oooooooooooo#.",
        ".##############.",
        "................",
    ], {"w": "V2"})


# ==================================================================== stat icons 8x8 (§5.4)

@asset("coin")
def coin():
    return icon([
        "..####..",
        ".#wOOo#.",
        "#wO#OOo#",
        "#OO#OOo#",
        "#OO#OOo#",
        "#OO#Ooo#",
        ".#oooo#.",
        "..####..",
    ], {"w": "V2"}, 8)


@asset("power")
def power():  # sword, I1
    return icon([
        ".....###",
        "....#jI#",
        "...#jI#.",
        "#.#jI#..",
        "#I#I#...",
        ".#i#....",
        "#i##I#..",
        "##..##..",
    ], None, 8)


@asset("count")
def count():  # skull, R1
    return icon([
        ".######.",
        "#7RRRRR#",
        "#R##R##R",
        "#R##R##R",
        "#RRRRRRr",
        ".#rR#Rr#",
        "..#r#r#.",
        "...###..",
    ], {"7": "N7"}, 8)


@asset("reroll")
def reroll():  # circular arrows
    return icon([
        "..####..",
        ".#uTTT#.",
        "#u###TT#",
        "#T#.TTTT",
        "###.####",
        "TTTT.#T#",
        "#TT###T#",
        ".#TTTT#.",
    ], None, 8)


@asset("summon")
def summon():  # candle
    return icon([
        "...#....",
        "..#g#...",
        "..#F#...",
        ".##f##..",
        ".#ccB#..",
        ".#ccB#..",
        ".#cBB#..",
        ".#####..",
    ], None, 8)


@asset("hp")
def hp():  # heart, R1
    return icon([
        ".##.##..",
        "#7R#RR#.",
        "#RRRRr#.",
        "#RRRRr#.",
        ".#RRr#..",
        "..#r#...",
        "...#....",
        "........",
    ], {"7": "N7"}, 8)


@asset("lock")
def lock():  # padlock
    return icon([
        "..####..",
        ".#T##T#.",
        ".#T##T#.",
        "########",
        "#uTTTTt#",
        "#TT##Tt#",
        "#tttttt#",
        ".######.",
    ], None, 8)


@asset("info")
def info():  # "i" in a round badge
    return icon([
        "..####..",
        ".#IIii#.",
        "#Iii7ii#",
        "#iiiiii#",
        "#ii77ii#",
        "#iii7ii#",
        ".#ii7i#.",
        "..####..",
    ], {"7": "N7"}, 8)


@asset("book")
def book():  # recipe book
    return icon([
        ".######.",
        "#bcBBBB#",
        "#bBBBBB#",
        "#bBcccB#",
        "#bBBBBB#",
        "#bBBBBB#",
        "#bccccc#",
        ".######.",
    ], None, 8)


@asset("gear")
def gear():  # settings cog: eight teeth around an open hub (M ramp, top-left light)
    return icon([
        "...uT...",
        ".u.uT.T.",
        "..uTTt..",
        "uuT##Ttt",
        "uTT##ttt",
        "..Tttt..",
        ".T.tt.t.",
        "...tt...",
    ], None, 8)


# Potions, gems and coffers (tools/art/items.py) are generated through this module as well.
from items import ASSETS as ITEM_ASSETS  # noqa: E402

ASSETS.update(ITEM_ASSETS)


if __name__ == "__main__":
    sys.exit(run(ASSETS, sys.argv[1:]))
