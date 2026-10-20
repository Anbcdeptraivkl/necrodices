"""Final icons (ART_SPEC §5): relics, consumable bases + consumables, equipment, stat icons.

    python tools/art/icons.py                  # write every icon that changed
    python tools/art/icons.py --only tome_*    # only matching ids
    python tools/art/icons.py --preview captures/icons_preview.png

16x16 icons: 1 px transparent margin (live area 14x14), N0 outline, <= 6 colours, light from
the top-left, one idea per icon, no text. Stat icons are 8x8.

TOME_<E> / SIGIL_<E> are composed, not drawn: base (tome_base / sigil_base, drawn here) +
`assets/sprites/dice/glyph8_<e>.png` read from disk at run time, pasted at (4, 4) — on the
cover for tomes, centred on the stone face for sigils (ART_SPEC §5.2). Re-run this module after
the glyph8 files change. The bases use only two colours besides N0 so base + glyph8 stays
within the 6-colour icon limit (glyph8 = N0 + up to 3 colours).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelgrid  # noqa: E402
from pixelgrid import MANIFEST, ROOT, canvas, grid, paste, run  # noqa: E402

from PIL import Image  # noqa: E402

GLYPH8_DIR = ROOT / "assets" / "sprites" / "dice"
ELEMENTS = ("bone", "fire", "ice", "leaf", "volt", "metal")


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


@asset("full_moon")
def full_moon():  # full moon with a sleepy, blushing face
    return icon([
        "................",
        ".....######.....",
        "...##777777##...",
        "..#7777777776#..",
        "..#7757777766#..",
        ".#777557777766#.",
        ".#777777777766#.",
        ".#77##7777##76#.",
        ".#7S77777777S6#.",
        ".#7777#77#7666#.",
        ".#77777##77566#.",
        "..#7777777666#..",
        "..#6777776666#..",
        "...##666666##...",
        ".....######.....",
        "................",
    ], {"S": "S1"})


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


# ====================================================================== consumables (§5.2)

@asset("tome_base")
def tome_base():  # closed book: N3 cover, N5 spine, corner caps and page block
    return icon([
        "................",
        "..###########...",
        ".#5#33333333#...",
        ".#5#333333355#..",
        ".#5#333333335#..",
        ".#5#333333333#..",
        ".#5#333333333#..",
        ".#5#333333333#..",
        ".#5#333333333#..",
        ".#5#333333333#..",
        ".#5#333333333#..",
        ".#5#333333335#..",
        ".#5#333333355#..",
        ".#5#5555555555#.",
        "..#############.",
        "................",
    ], {"3": "N3"})


@asset("sigil_base")
def sigil_base():  # round rune stone: N4 face, N5 top-left rim, carved ticks
    return icon([
        "................",
        ".....######.....",
        "...##555555##...",
        "..#5554##4444#..",
        ".#554444444444#.",
        ".#544444444444#.",
        ".#544444444444#.",
        ".#5#44444444#4#.",
        ".#4#44444444#4#.",
        ".#444444444444#.",
        ".#444444444444#.",
        ".#444444444444#.",
        "..#4444##4444#..",
        "...##444444##...",
        ".....######.....",
        "................",
    ])


def _glyph8(element: str) -> Image.Image:
    return Image.open(GLYPH8_DIR / f"glyph8_{element}.png").convert("RGBA")


def _compose(base_fn, element: str) -> Image.Image:
    return paste(base_fn(), _glyph8(element), 4, 4)  # §5.2: glyph8 at (4, 4)


for _e in ELEMENTS:
    ASSETS[f"tome_{_e}"] = (lambda e=_e: _compose(tome_base, e))
    ASSETS[f"sigil_{_e}"] = (lambda e=_e: _compose(sigil_base, e))


@asset("ink_wild")
def ink_wild():  # squat ink bottle with an open eye, gold pupil
    return icon([
        "................",
        "......####......",
        "......#BB#......",
        "......####......",
        ".......#3#......",
        "....###33###....",
        "...#53333333#...",
        "..#5333333333#..",
        "..#53#77777#3#..",
        "..#5#77#O#77#3#.",
        "..#5#7#OOO#7#3#.",
        "..#53#77O77#33#.",
        "..#333#####333#.",
        "...#333333333#..",
        "....#########...",
        "................",
    ], {"3": "N3"})


@asset("ink_sharp")
def ink_sharp():  # whetstone with a small red blade resting on it
    return icon([
        "................",
        "................",
        "................",
        "..####.######...",
        ".#RRRr#uuuuuu#..",
        ".#rrrr#TTTTT#...",
        ".##############.",
        ".#uuuuuuuuuuuu#.",
        ".#TTTTTTTTTTTt#.",
        ".#TTTTTTTTTTTt#.",
        ".#tttttttttttt#.",
        ".##############.",
        "................",
        "................",
        "................",
        "................",
    ])


@asset("ink_swarm")
def ink_swarm():  # drawstring seed pouch, seeds spilling
    return icon([
        "................",
        "................",
        "...#########.#..",
        "...#bbbbbbb##m#.",
        "...#ccccccB#.#..",
        "...#cccLccB#.#..",
        "...#ccmLmcB##m#.",
        "...#cmmLmmB#.#..",
        "...#cccLccB#....",
        "...#cccLccB#.#..",
        "...#ccbbbcB##m#.",
        "...#ccccccB#.#..",
        "...#BBBBBBB#....",
        "...#########....",
        "................",
        "................",
    ])


@asset("ink_hex")
def ink_hex():  # burlap voodoo doll with stitched eyes and a pin
    return icon([
        "................",
        "....#####.......",
        "...#BBBBB#..##..",
        "...#B#B#B##RR#..",
        "...#BBBBB#7#....",
        "...#BBBB7#......",
        "....#####.......",
        ".###BBBBB###....",
        ".#BBBBBBBBB#....",
        ".###BBRBb###....",
        "...#BBBBb#......",
        "...#BBbBb#......",
        "...#Bb#Bb#......",
        "...#Bb#Bb#......",
        "....##.##.......",
        "................",
    ], {"7": "N7"})


@asset("ink_gold")
def ink_gold():  # a single leaf of gold
    return icon([
        "................",
        "...........###..",
        ".........##wwO#.",
        ".......##wwOOo#.",
        "......#wwOOOOo#.",
        ".....#wOOOOOo#..",
        "....#wOOOOOOo#..",
        "....#wOOOOoOo#..",
        "...#wOOOOoOOo#..",
        "...#OOOoOOOo#...",
        "...#OOoOOOo#....",
        "...#OoOOoo#.....",
        "...#ooooo#......",
        "..#o####........",
        ".#o#............",
        "................",
    ], {"w": "V2"})


@asset("spare_die")
def spare_die():  # bone die with a green plus
    return icon([
        "................",
        "...........#....",
        "..........#m#...",
        ".........##L##..",
        "........#LLLLL#.",
        "..#########L##..",
        ".#cccccccB#L#...",
        ".#c##ccccB##....",
        ".#c##ccccB#.....",
        ".#cccc##cB#.....",
        ".#cccc##cB#.....",
        ".#ccccc##B#.....",
        ".#ccccc##B#.....",
        ".#bbbbbbbb#.....",
        "..########......",
        "................",
    ])


# ======================================================================= equipment (§5.3)

@asset("bone_pouch")
def bone_pouch():  # small drawstring pouch with a bone toggle
    return icon([
        "................",
        "................",
        "................",
        "......#..#......",
        ".....#c##c#.....",
        "......####......",
        "......#BB#......",
        ".....#bbbb#.....",
        "....#cBBBBb#....",
        "...#cBBBBBBb#...",
        "...#BBBBBBBb#...",
        "...#BBBBBBbb#...",
        "....#bbbbbb#....",
        ".....######.....",
        "................",
        "................",
    ])


@asset("bone_satchel")
def bone_satchel():  # big flap satchel with strap and bone buckle
    return icon([
        "................",
        ".....######.....",
        "....#bbbbbb#....",
        "...#b######b#...",
        "...#b#....#b#...",
        ".###b######b###.",
        ".#cBBBBBBBBBBB#.",
        ".#BBBBBBBBBBBB#.",
        ".##BBBBBBBBBB##.",
        ".#b##BBBBBB##b#.",
        ".#bbb#BccB#bbb#.",
        ".#bbbb####bbbb#.",
        ".#bbbbbbbbbbbb#.",
        "..############..",
        "................",
        "................",
    ])


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


if __name__ == "__main__":
    sys.exit(run(ASSETS, sys.argv[1:]))
