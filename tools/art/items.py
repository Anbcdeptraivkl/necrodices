"""Final item icons (ART_SPEC §5, GAME_SPEC §6.6, §6.7, §6.9): potions, gems and coffers.

    python tools/art/items.py --only elixir_*          # (re)write matching ids
    python tools/art/items.py --preview out.png        # x6 contact sheet, writes nothing

`tools/art/icons.py` merges these ASSETS, so its documented commands cover them as well.

Families read by silhouette first:
  - potions: glass bottles with a cork (S0), glass glint N7, coloured liquid; the six elixirs share
    one round flask and differ only by the element ramp, every other potion has its own bottle;
  - gems: faceted cuts, one highlight facet, each gem a different cut (brilliant, oval, teardrop,
    triangle, round cabochon, shard, step-cut octagon, hexagon);
  - coffers: upright wooden coffins (S1 / S0 / B0), an emblem of their contents in the middle;
    normal < jumbo (bigger, iron-nail bands) < mega (biggest, G1 gold trim instead of the S1 light).
16x16, 1 px transparent margin, N0 outline, <= 6 colours each.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelgrid import canvas, grid, outline, paste, run  # noqa: E402

from PIL import Image  # noqa: E402


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


# ============================================================================ potions (§6.6)
# Liquid letters in potion grids: h = light, M = mid, d = dark (set per potion).

ROUND_FLASK = [  # ELIXIR_<E>: cork, short neck, round body full of liquid
    "................",
    "......####......",
    "......#ss#......",
    "......#ss#......",
    ".....######.....",
    "......#7h#......",
    "....##7hhh##....",
    "...#7hhMMMMd#...",
    "..#7hMMMMMMMd#..",
    "..#7MMMMMMMMd#..",
    "..#hMMMhMMMMd#..",
    "..#MMMMMMMMdd#..",
    "..#MMMMMMMddd#..",
    "...#dMMMMddd#...",
    "....########....",
    "................",
]

ELIXIR_RAMPS = {
    "bone": ("B2", "B1", "B0"),
    "fire": ("F2", "F1", "F0"),
    "ice": ("I2", "I1", "I0"),
    "leaf": ("L2", "L1", "L0"),
    "volt": ("V2", "V1", "V0"),
    "metal": ("M2", "M1", "M0"),
}


def elixir(element: str) -> Image.Image:
    h, m, d = ELIXIR_RAMPS[element]
    return icon(ROUND_FLASK, {"h": h, "M": m, "d": d, "s": "S0"})


for _e in ELIXIR_RAMPS:
    ASSETS[f"elixir_{_e}"] = (lambda e=_e: elixir(e))


@asset("strength_tonic")
def strength_tonic():  # tall test-tube vial of red tonic, rising bubbles
    return icon([
        "................",
        "......####......",
        "......#ss#......",
        ".....######.....",
        ".....#7RRr#.....",
        ".....#7RRr#.....",
        ".....#7R7r#.....",
        ".....#7RRr#.....",
        ".....#7RRr#.....",
        ".....#RR7r#.....",
        ".....#RRRr#.....",
        ".....#RRrr#.....",
        ".....#RRrr#.....",
        "......#rr#......",
        ".......##.......",
        "................",
    ], {"s": "S0"})


@asset("whetstone_oil")
def whetstone_oil():  # square bottle of red oil, a steel blade standing beside it
    return icon([
        "................",
        "...........#....",
        "...####...#u#...",
        "...#tt#...#uT#..",
        "..######..#uT#..",
        "...#uR#...#uT#..",
        "..#uRRr#..#uT#..",
        ".#uRRRRr#.#uT#..",
        ".#RRRRRr#######.",
        ".#RRRRrr##tttt#.",
        ".#RRRRrr#######.",
        ".#RRRRrr#.#r#...",
        ".#RRRrrr#.#r#...",
        ".#rrrrrr#.#r#...",
        "..######...#....",
        "................",
    ])


@asset("swarm_brew")
def swarm_brew():  # conical flask of green brew, foam spilling over, bubbles rising
    return icon([
        "................",
        "...#........#...",
        "..#m#......#m#..",
        "...#..#mm#..#...",
        ".....#mmmm#.....",
        ".....######.....",
        "......#7L#......",
        "......#7L#......",
        ".....#mmLl#.....",
        "....#7mLLLl#....",
        "...#7LLmLLLl#...",
        "..#7LLLLLmLll#..",
        ".#LLmLLLLLLlll#.",
        ".#llllllllllll#.",
        "..############..",
        "................",
    ])


@asset("wild_spirits")
def wild_spirits():  # long-necked spirits bottle, a swirl of element colours inside
    return icon([
        "................",
        "......####......",
        "......####......",
        "......#7I#......",
        "......#7F#......",
        "......#VF#......",
        ".....#7VFL#.....",
        "....#7VFFLL#....",
        "....#VFFLLI#....",
        "....#FFLLII#....",
        "....#FLLIIV#....",
        "....#LLIIVV#....",
        "....#LIIVVF#....",
        "....#IIVVFF#....",
        ".....######.....",
        "................",
    ])


@asset("glass_draught")
def glass_draught():  # clear cyan pear-shaped bottle with a crack down its side
    return icon([
        "................",
        "......####......",
        "......#ss#......",
        ".....######.....",
        "......#7j#......",
        ".....#7jjI#.....",
        ".....#7jjI#.....",
        "....#7jjj#I#....",
        "...#7jjjjj#I#...",
        "...#7jjjj#jI#...",
        "..#7jjjjjj#jI#..",
        "..#jjjjjjj#II#..",
        "..#jjjjjjII#I#..",
        "...#IjjjIIii#...",
        "....########....",
        "................",
    ], {"s": "S0"})


@asset("iron_draught")
def iron_draught():  # flat steel hip flask: screw cap, riveted iron band
    return icon([
        "................",
        "................",
        ".......####.....",
        ".......#tt#.....",
        "......##uT##....",
        ".....#uuuuTt#...",
        "....#uTTTTTTt#..",
        "....#uTTTTTTt#..",
        "....#tttttttt#..",
        "....#tuttttut#..",
        "....#tttttttt#..",
        "....#uTTTTTTt#..",
        "....#uTTTTTtt#..",
        "....#TTTTTttt#..",
        ".....########...",
        "................",
    ])


@asset("grave_dust")
def grave_dust():  # squat corked jar of grey grave dust with a little cross on it
    return icon([
        "................",
        "................",
        "................",
        ".....######.....",
        ".....#ssss#.....",
        "....########....",
        ".....#7656#.....",
        "...##656565##...",
        "..#76656565#4#..",
        "..#7656#56545#..",
        "..#665###6544#..",
        "..#6565#65454#..",
        "..#5656#54544#..",
        "...#55454444#...",
        "....########....",
        "................",
    ], {"s": "S0", "7": "N7", "6": "N6", "5": "N5", "4": "N4"})


@asset("liquid_gold")
def liquid_gold():  # diamond-shaped bottle of molten gold, a drop on the stopper
    return icon([
        "................",
        "......####......",
        "......#ss#......",
        ".....######.....",
        "......#7w#......",
        ".....#7wOO#.....",
        "....#7wOOOO#....",
        "...#7wOOOOOo#...",
        "..#7wOOOOOOoo#..",
        "...#wOOOOOOo#...",
        "....#OOOOOoo#...",
        "....#OOOOooo#...",
        ".....#OOooo#....",
        "......#ooo#.....",
        ".......###......",
        "................",
    ], {"s": "S0", "w": "V2"})


@asset("lucky_clover")
def lucky_clover():  # small green bottle, a four-leaf clover sprouting from its mouth
    return icon([
        "................",
        ".....##.##......",
        "....#mL#mL#.....",
        "...#mLLlLLl#....",
        "....#lLLLl#.....",
        "...#mLLlLLl#....",
        "....#lllll#.....",
        "......#l#.......",
        ".....##l##......",
        ".....#7lL#......",
        "...##7mLLL##....",
        "..#7mLLLLLLl#...",
        "..#LLLLLLLll#...",
        "...#lllllll#....",
        "....#######.....",
        "................",
    ])


@asset("mirror_draught")
def mirror_draught():  # silver double-gourd flask: the lower bulb mirrors the upper one
    return icon([
        "................",
        "......####......",
        "......#ss#......",
        ".....######.....",
        ".....#7uuT#.....",
        "....#7uTTTt#....",
        "....#uTTTTt#....",
        ".....#tTTt#.....",
        "......#77#......",
        ".....#tTTu#.....",
        "....#tTTTTu#....",
        "....#tTTTu7#....",
        "....#ttTu77#....",
        ".....#tttt#.....",
        "......####......",
        "................",
    ], {"s": "S0"})


@asset("hermit_brew")
def hermit_brew():  # dark squat jug with a ring handle, a gold coin on its belly
    return icon([
        "................",
        "......####......",
        "......#55#......",
        ".....######.....",
        "......#53#......",
        "....##5333##....",
        "...#5333333###..",
        "..#533####32#3#.",
        "..#53#OOo#32#3#.",
        "..#53#OoO#322#..",
        "..#53#Ooo#32#...",
        "..#333####22#...",
        "..#3333332222#..",
        "...#22222222#...",
        "....########....",
        "................",
    ], {"5": "N5", "3": "N3", "2": "N2"})


# =============================================================================== gems (§6.7)

@asset("garnet")
def garnet():  # classic brilliant (side view): table, crown, pointed pavilion
    return icon([
        "................",
        "................",
        "................",
        "....########....",
        "...#7SRRRRRr#...",
        "..#7SRRrRRrRr#..",
        ".##############.",
        "..#RRRRrRRrrr#..",
        "...#RRRrRrrr#...",
        "....#RRrRrr#....",
        ".....#RRrr#.....",
        "......#Rr#......",
        ".......##.......",
        "................",
        "................",
        "................",
    ], {"S": "S1"})


@asset("opal")
def opal():  # milky oval cabochon with flecks of fire
    return icon([
        "................",
        "................",
        "......####......",
        ".....#7766#.....",
        "....#76666j#....",
        "...#766S6665#...",
        "...#76666j65#...",
        "...#6j666S65#...",
        "...#666S6665#...",
        "...#6666j655#...",
        "...#66S66655#...",
        "....#666655#....",
        ".....#5555#.....",
        "......####......",
        "................",
        "................",
    ], {"S": "S1"})


@asset("amber")
def amber():  # honey teardrop, point up, a tiny spider trapped inside
    return icon([
        "................",
        ".......##.......",
        "......#gg#......",
        "......#go#......",
        ".....#7ggo#.....",
        ".....#gggo#.....",
        "....#7gggoo#....",
        "...#7gggggoo#...",
        "...#ggg#g#oo#...",
        "...#gggg#ooo#...",
        "...#ggg#g#oo#...",
        "...#ggggoooo#...",
        "....#ggooof#....",
        ".....#ffff#.....",
        "......####......",
        "................",
    ])


@asset("prism")
def prism():  # point-down trillion gem, every facet a different colour of the rainbow
    return icon([
        "................",
        "................",
        ".##############.",
        ".#7VVVVVVVVVVV#.",
        "..#RVVVVVVVVI#..",
        "..#RRVVVVVVII#..",
        "...#RRRVVIII#...",
        "...#RRRRIIII#...",
        "....#RRRIII#....",
        "....#RRLLII#....",
        ".....#RLLI#.....",
        ".....#LLLL#.....",
        "......#LL#......",
        ".......##.......",
        "................",
        "................",
    ])


@asset("moonstone")
def moonstone():  # round pale-blue cabochon, a crescent of moonlight along its rim
    return icon([
        "................",
        "................",
        ".....######.....",
        "...##77jjjj##...",
        "..#7766jjjjjj#..",
        ".#776jjjjjjjjI#.",
        ".#76jjjjjjjjjI#.",
        ".#76jjjjjjjjjI#.",
        ".#76jjjjjjjjII#.",
        ".#j6jjjjjjjjII#.",
        ".#jj6jjjjjjIII#.",
        "..#jj66jjjIII#..",
        "...##IIIIII##...",
        ".....######.....",
        "................",
        "................",
    ], {"6": "N6"})


@asset("obsidian")
def obsidian():  # jagged black glass shard with a bright cutting edge
    return icon([
        "................",
        "..........##....",
        ".........#5#....",
        "........#53#....",
        ".......#533#....",
        "......#5331##...",
        ".....#53311#5#..",
        "....#533111#3#..",
        "...#5331111#3#..",
        "...#533111113#..",
        "..#5531111113#..",
        "..#5331111133#..",
        "..#533111133#...",
        "...#3311333#....",
        "....#######.....",
        "................",
    ], {"5": "N5", "3": "N3", "1": "N1"})


@asset("emerald")
def emerald():  # step-cut emerald: octagonal rectangle with stepped facets
    return icon([
        "................",
        "................",
        "....########....",
        "...#mmmmmmmL#...",
        "..#mL######Ll#..",
        "..#mL#mmmL#Ll#..",
        "..#mL#m7mL#Ll#..",
        "..#mL#mmmL#Ll#..",
        "..#mL#mmLL#Ll#..",
        "..#mL#LLLL#Ll#..",
        "..#mL######Ll#..",
        "..#Llllllllll#..",
        "...#lllllllll#..",
        "....#########...",
        "................",
        "................",
    ])


@asset("bloodstone")
def bloodstone():  # pointed hexagon: bright top-left facets, dark red table with black spots
    return icon([
        "................",
        "......####......",
        "....##RRRR##....",
        "..##RRRRRRR2##..",
        ".#RRrrrrrrrr22#.",
        ".#R7rrrr2rrrr2#.",
        ".#Rrrr2rrrrrr2#.",
        ".#Rrrrrrrr2rr2#.",
        ".#Rr2rrrrrrrr2#.",
        ".#Rrrrrr2rrrr2#.",
        ".#RRrrrrrrrr22#.",
        "..##R2222222##..",
        "....##2222##....",
        "......####......",
        "................",
        "................",
    ], {"2": "N2"})


# ============================================================================= coffers (§6.9)
# Upright coffins: S1 left light (G1 gold trim on mega), S0 wood, B0 right shade and lid bands.
# The contents emblem (5 px wide interior + its own N0 ring) is pasted centred on col 7.

COFFIN_SMALL = [  # shoulder 9 px
    "................",
    "................",
    ".....#####......",
    "....#SSSSs#.....",
    "...#Ssssssb#....",
    "..#Ssssssssb#...",
    "..#Ssssssssb#...",
    "..#Ssssssssb#...",
    "...#Ssssssb#....",
    "...#Ssssssb#....",
    "...#Ssssssb#....",
    "....#Sssbb#.....",
    "....#Sssbb#.....",
    "....#bbbbb#.....",
    ".....#####......",
    "................",
]

COFFIN_JUMBO = [  # shoulder 11 px, two B0 lid bands
    "................",
    "....#######.....",
    "...#SSSSSSs#....",
    "..#SSssssssb#...",
    ".#bbbbbbbbbbb#..",
    ".#Ssssssssssb#..",
    ".#Ssssssssssb#..",
    ".#Ssssssssssb#..",
    "..#Ssssssssb#...",
    "..#Ssssssssb#...",
    "..#Ssssssssb#...",
    "...#Ssssssb#....",
    "...#bbbbbbb#....",
    "...#Sssssbb#....",
    "....#######.....",
    "................",
]

COFFIN_MEGA = [  # shoulder 12 px, G1 corner caps and lid bands
    "................",
    "...##########...",
    "..#OssssssssO#..",
    ".#OssssssssssO#.",
    ".#OOOOOOOOOOOO#.",
    ".#Ossssssssssb#.",
    ".#ssssssssssbb#.",
    ".#ssssssssssbb#.",
    "..#ssssssssbb#..",
    "..#ssssssssbb#..",
    "..#ssssssssbb#..",
    "...#ssssssbb#...",
    "...#OOOOOOOO#...",
    "...#ObbbbbbO#...",
    "....########....",
    "................",
]

EMBLEMS = {  # interiors only (e = light, E = mid); an N0 ring is added around them
    "potion": [  # round bottle
        "..e..",
        ".eEE.",
        "eEEEE",
        "EEEEE",
        ".EEE.",
    ],
    "gem": [  # cut gem, flat top
        ".eeE.",
        "eeEEE",
        ".eEE.",
        "..E..",
    ],
    "trinket": [  # heart charm
        "ee.EE",
        "eEEEE",
        ".EEE.",
        "..E..",
    ],
    "bone": [  # bone die with two pips
        "eeeeE",
        "e#eeE",
        "eee#E",
        "EEEEE",
    ],
}
EMBLEM_COLOURS = {
    "potion": ("I2", "I1"),
    "gem": ("L2", "L1"),
    "trinket": ("R1", "R0"),
    "bone": ("B2", "B1"),
}
COFFINS = {  # suffix -> (grid, emblem top row)
    "": (COFFIN_SMALL, 5),
    "_jumbo": (COFFIN_JUMBO, 5),
    "_mega": (COFFIN_MEGA, 6),
}


def emblem(kind: str) -> Image.Image:
    e1, e2 = EMBLEM_COLOURS[kind]
    rows = EMBLEMS[kind]
    img = canvas(len(rows[0]) + 2, len(rows) + 2)
    paste(img, grid(rows, {"e": e1, "E": e2}), 1, 1)
    return outline(img)


def coffer(kind: str, size: str) -> Image.Image:
    rows, ey = COFFINS[size]
    img = icon(rows, {"S": "S1", "s": "S0", "b": "B0", "O": "G1"})
    em = emblem(kind)
    paste(img, em, 7 - em.width // 2, ey + (6 - em.height) // 2)
    return img


for _k in EMBLEMS:
    for _s in COFFINS:
        ASSETS[f"coffer_{_k}{_s}"] = (lambda k=_k, s=_s: coffer(k, s))


if __name__ == "__main__":
    sys.exit(run(ASSETS, sys.argv[1:]))
