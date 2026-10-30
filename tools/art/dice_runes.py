"""Rune die bodies, rune face tiles and point badges (ART_SPEC §4.6, GAME_SPEC §4.6).

    python tools/art/dice_runes.py --only die_body_*   # (re)write matching ids
    python tools/art/dice_runes.py --preview out.png   # x6 contact sheet, writes nothing

`tools/art/enemies_dice.py` merges these ASSETS, so its documented commands cover them as well.

A rune changes the MATERIAL of the die while that face is up. Every body keeps the bone die's
silhouette and shading layout (die_body: face rows 1-15 with the top-left light and right /
bottom shade, side band rows 16-18), so the 12x12 glyph at (4, 3) and the 7x9 points badge at
(13, 11) sit on it exactly as on the bone die. Material details (teeth, rivets, crack, clover,
moss, shine) are placed where the glyph and badge leave the body visible: the top two rows, the
left three columns, the right column above the badge and the side band left of it.
TOMB shows no glyph in game, so its carved cross sits in the middle. face_tile_<rune> applies
the same materials to the 16x16 dice-inspector tile (glyph8 at (4, 4)).

The designer repainted the bodies (2026-10-29): the face is flat with a top-left light and no right
shade column; die_body_*.png on disk is the truth and BODY_* below are the older recipes. The
TILE_* grids follow the repainted bodies (glass shine in N7: the body's #ffffff is off-palette).

num_<n>: the face's points, a 7x9 N0 rounded badge with a 3x5 N7 digit (3 colours max).
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelgrid import grid, paste, run  # noqa: E402

from PIL import Image  # noqa: E402

RUNES = ("sharp", "swarm", "wild", "glass", "iron", "tomb", "gilded", "lucky")

# Letters are pixelgrid.BASE_LEGEND aliases: 7 N7, c/B/b bone, R/r red, j/I/i ice, T/t/u metal,
# 3-6 neutrals, O/o gold, g F2, v V0, m/L/l leaf, F/f fire, V volt. Wild bands cycle the element
# mids on the face (F V L I R c) and their darks on the side (f v l i r b).

BODY_SHARP = [
    "..#.##.##.##.##.##..",
    ".#R#RR#RR#RR#RR#RR#.",
    "#Rccccccccccccccccr#",
    ".#cccccccccccccccc#.",
    "#Rccccccccccccccccr#",
    "#Rccccccccccccccccr#",
    ".#cccccccccccccccc#.",
    "#Rccccccccccccccccr#",
    "#Rccccccccccccccccr#",
    ".#cccccccccccccccc#.",
    "#Rccccccccccccccccr#",
    "#Rccccccccccccccccr#",
    ".#cccccccccccccccc#.",
    "#Rccccccccccccccccr#",
    "#Rccccccccccccccccr#",
    ".#rrrrrrrrrrrrrrrr#.",
    "#RRRRRRRRRRRRRRRRRR#",
    "#rrrrrrrrrrrrrrrrrr#",
    ".#r#rr#rr#rr#rr#rr#.",
    "..#.##.##.##.##.##..",
]
TILE_SHARP = [
    ".##.##.##.##.##.",
    "#rr#rr#rr#rr#rr#",
    "#rccccccccccccr#",
    ".#cccccccccccc#.",
    "#rccccccccccccr#",
    "#rccccccccccccr#",
    ".#cccccccccccc#.",
    "#rccccccccccccr#",
    "#rccccccccccccr#",
    ".#cccccccccccc#.",
    "#rccccccccccccr#",
    "#rccccccccccccr#",
    ".#cccccccccccc#.",
    "#RRRRRRRRRRRRRR#",
    "#rr#rr#rr#rr#rr#",
    ".##.##.##.##.##.",
]
BODY_SWARM = [
    "..################..",
    ".#7mcccccccccccLmc#.",
    "#7LLmcccccccccccLlB#",
    "#clLcccccccccccccLB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#ccccccccccccccccLB#",
    "#LmcccccccccccccclB#",
    "#lLcccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#cmcccccccccccccccB#",
    "#lLcccccccccccccccB#",
    "#cccccccccccccccccB#",
    "#ccccccLlccccccccBB#",
    "#BBLmBBBBBBBBBBBBBB#",
    "#bblLlbbbLlbbbbbbbb#",
    ".#bbbbbbbbbbbbbbbb#.",
    "..################..",
]
TILE_SWARM = [
    ".##############.",
    "#7cccccccccLmlc#",
    "#cLmccccccclLll#",
    "#clLcccccccccLl#",
    "#cccccccccccclL#",
    "#cccccccccccccc#",
    "#ccccccccccccLm#",
    "#LmcccccccccclL#",
    "#lLcccccccccccc#",
    "#cccccccccccccc#",
    "#Lmcccccccccccc#",
    "#lLcccccccccccc#",
    "#cccccccccccccc#",
    "#cccccLlccccccc#",
    "#llLmllllllllll#",
    ".##############.",
]
BODY_WILD = [
    "..################..",
    ".#7VVLLLIIIRRRcccF#.",
    "#7VVLLLIIIRRRcccFFF#",
    "#VVLLLIIIRRRcccFFFV#",
    "#VLLLIIIRRRcccFFFVV#",
    "#LLLIIIRRRcccFFFVVV#",
    "#LLIIIRRRcccFFFVVVL#",
    "#LIIIRRRcccFFFVVVLL#",
    "#IIIRRRcccFFFVVVLLL#",
    "#IIRRRcccFFFVVVLLLI#",
    "#IRRRcccFFFVVVLLLII#",
    "#RRRcccFFFVVVLLLIII#",
    "#RRcccFFFVVVLLLIIIR#",
    "#RcccFFFVVVLLLIIIRR#",
    "#cccFFFVVVLLLIIIRRR#",
    "#ccFFFVVVLLLIIIRRRc#",
    "#bfffvvvllliiirrrbb#",
    "#fffvvvllliiirrrbbb#",
    ".#fvvvllliiirrrbbb#.",
    "..################..",
]
TILE_WILD = [
    ".##############.",
    "#7VVVLLLIIIRRRc#",
    "#VVVLLLIIIRRRcc#",
    "#VVLLLIIIRRRccc#",
    "#VLLLIIIRRRcccF#",
    "#LLLIIIRRRcccFF#",
    "#LLIIIRRRcccFFF#",
    "#LIIIRRRcccFFFV#",
    "#IIIRRRcccFFFVV#",
    "#IIRRRcccFFFVVV#",
    "#IRRRcccFFFVVVL#",
    "#RRRcccFFFVVVLL#",
    "#RRcccFFFVVVLLL#",
    "#RcccFFFVVVLLLI#",
    "#bbbfffvvvlllii#",
    ".##############.",
]
BODY_GLASS = [
    "..################..",
    ".#7j77jj7jjjjjijjj#.",
    "#7j77jj7jjjjjjjijjI#",
    "#j77jjjjjjjjjjjjijI#",
    "#77jjjjjjjjjjjjjijI#",
    "#7jjjjjjjjjjjjjjjiI#",
    "#jjjjjjjjjjjjjjjjiI#",
    "#jjjjjjjjjjjjjjjjjI#",
    "#jjjjjjjjjjjjjjjjjI#",
    "#jjjjjjjjjjjjjjjjjI#",
    "#jjjjjjjjjjjjjjjjjI#",
    "#jjjjjjjjjjjjjjjjjI#",
    "#jjjjjjjjjjjjjjjjjI#",
    "#jjjjjjjjjjjjjjjjjI#",
    "#jjjjjjjjjjjjjjjjjI#",
    "#jjjjjjjjjjjjjjjjII#",
    "#IIIIIIIIIIIIIIIIII#",
    "#iiiiiiiiiiiiiiiiii#",
    ".#iiiiiiiiiiiiiiii#.",
    "..################..",
]
TILE_GLASS = [
    ".##############.",
    "#j7j7j7jjjjjjjj#",
    "#7j7j7jjjjjjjjj#",
    "#j7j7jjjjjjjjjj#",
    "#7j7jjjjjjjjjjj#",
    "#j7jjjjjjjjjjjj#",
    "#7jjjjjjjjjjjjj#",
    "#jjjjjjjjjjjjjj#",
    "#jjjjjjjjjjjjjj#",
    "#jjjjjjjjjjjjjj#",
    "#jjjjjjjjjjjjjj#",
    "#jjjjjjjjjjjjjj#",
    "#jjjjjjjjjjjjjj#",
    "#jjjjjjjjjjjjjj#",
    "#IIIIIIIIIIIIII#",
    ".##############.",
]
BODY_IRON = [
    "..################..",
    ".#uuuuuuuuuuuuuuuu#.",
    "#uutTTTTTTTTTTTTutt#",
    "#uttTTTTTTTTTTTTttt#",
    "#uTTTTTTTTTTTTTTTTt#",
    "#uTTTTTTTTTTTTTTTTt#",
    "#uTTTTTTTTTTTTTTTTt#",
    "#uTTTTTTTTTTTTTTTTt#",
    "#uTTTTTTTTTTTTTTTTt#",
    "#uTTTTTTTTTTTTTTTTt#",
    "#uTTTTTTTTTTTTTTTTt#",
    "#uTTTTTTTTTTTTTTTTt#",
    "#uTTTTTTTTTTTTTTTTt#",
    "#uutTTTTTTTTTTTTutt#",
    "#uttTTTTTTTTTTTTttt#",
    "#uttttttttttttttttt#",
    "#tttttttttttttttttt#",
    "#333333333333333333#",
    ".#3333333333333333#.",
    "..################..",
]
TILE_IRON = [
    ".##############.",
    "#uuuuuuuuuuuuuu#",
    "#uutTTTTTTTTutu#",
    "#uttTTTTTTTTttu#",
    "#uTTTTTTTTTTTTu#",
    "#uTTTTTTTTTTTTu#",
    "#uTTTTTTTTTTTTu#",
    "#uTTTTTTTTTTTTu#",
    "#uTTTTTTTTTTTTu#",
    "#uTTTTTTTTTTTTu#",
    "#uTTTTTTTTTTTTu#",
    "#uutTTTTTTTTutu#",
    "#uttTTTTTTTTttu#",
    "#uuuuuuuuuuuuuu#",
    "#tttttttttttttt#",
    ".##############.",
]
BODY_TOMB = [
    "..################..",
    ".#6666666666666666#.",
    "#655555555555554554#",
    "#655555555555555554#",
    "#655555554465555554#",
    "#655555554465555554#",
    "#655554444444465554#",
    "#655554444444465554#",
    "#655556664466655544#",
    "#655555554465555554#",
    "#645555554465555554#",
    "#654555554465555554#",
    "#655555554465555554#",
    "#655555554465555554#",
    "#655555556655555554#",
    "#644444444444444444#",
    "#444444444444444444#",
    "#333333333333333333#",
    ".#3333333333333333#.",
    "..################..",
]
TILE_TOMB = [
    ".##############.",
    "#66666666666666#",
    "#65555555555556#",
    "#65555544555556#",
    "#65555544555556#",
    "#65554444445556#",
    "#65554444445556#",
    "#65555544555556#",
    "#65555544555556#",
    "#65555544555556#",
    "#65555544555556#",
    "#65555544555556#",
    "#65555555555556#",
    "#66666666666666#",
    "#44444444444444#",
    ".##############.",
]
BODY_GILDED = [
    "..################..",
    ".#7ggOOOOOOOOOOOgO#.",
    "#77OOOOOOOOOOOOg7go#",
    "#gOOOOOOOOOOOOOOgOo#",
    "#gOOOOOOOOOOOOOOOOo#",
    "#OOOOOOOOOOOOOOOOOo#",
    "#OOOOOOOOOOOOOOOOOo#",
    "#OOOOOOOOOOOOOOOOOo#",
    "#OOOOOOOOOOOOOOOOOo#",
    "#OOOOOOOOOOOOOOOOOo#",
    "#OOOOOOOOOOOOOOOOOo#",
    "#OOOOOOOOOOOOOOOOOo#",
    "#OOOOOOOOOOOOOOOOOo#",
    "#OOOOOOOOOOOOOOOOOo#",
    "#OOOOOOOOOOOOOOOOOo#",
    "#OOOOOOOOOOOOOOOOoo#",
    "#oooooooooooooooooo#",
    "#vvvvvvvvvvvvvvvvvv#",
    ".#vvvvvvvvvvvvvvvv#.",
    "..################..",
]
TILE_GILDED = [
    ".##############.",
    "#7ggOOOOOOOOgg7#",
    "#77OOOOOOOOOO77#",
    "#gOOOOOOOOOOOOg#",
    "#gOOOOOOOOOOOOg#",
    "#OOOOOOOOOOOOOO#",
    "#OOOOOOOOOOOOOO#",
    "#OOOOOOOOOOOOOO#",
    "#OOOOOOOOOOOOOO#",
    "#OOOOOOOOOOOOOO#",
    "#OOOOOOOOOOOOOO#",
    "#OOOOOOOOOOOOOO#",
    "#OOOOOOOOOOOOOO#",
    "#OOOOOOOOOOOOOO#",
    "#oooooooooooooo#",
    ".##############.",
]
BODY_LUCKY = [
    "..################..",
    ".#7mmmmmmmmmmmmmml#.",
    "#7mmmmmmmmmmmmmmlLl#",
    "#mmmmmmmmmmmmmmmmlL#",
    "#mmmmmmmmmmmmmmmlmL#",
    "#mmmmmmmmmmmmmmmmmL#",
    "#mmmmmmmmmmmmmmmmmL#",
    "#mmmmmmmmmmmmmmmmmL#",
    "#mmmmmmmmmmmmmmmmmL#",
    "#mmmmmmmmmmmmmmmmmL#",
    "#mmmmmmmmmmmmmmmmmL#",
    "#mmmmmmmmmmmmmmmmmL#",
    "#mmmmmmmmmmmmmmmmmL#",
    "#mmmmmmmmmmmmmmmmmL#",
    "#mmmmmmmmmmmmmmmmmL#",
    "#mmmmmmmmmmmmmmmmLL#",
    "#LLLLLLLLLLLLLLLLLL#",
    "#llllllllllllllllll#",
    ".#llllllllllllllll#.",
    "..################..",
]
TILE_LUCKY = [
    ".##############.",
    "#7mmmmmmmmmllmm#",
    "#mmmmmmmmmllLlm#",
    "#mmmmmmmmmlLllm#",
    "#mmmmmmmmmmllmm#",
    "#mmmmmmmmmmmmmm#",
    "#mmmmmmmmmmmmmm#",
    "#mmmmmmmmmmmmmm#",
    "#mmmmmmmmmmmmmm#",
    "#mmmmmmmmmmmmmm#",
    "#mmmmmmmmmmmmmm#",
    "#mmmmmmmmmmmmmm#",
    "#mmmmmmmmmmmmmm#",
    "#mmmmmmmmmmmmmm#",
    "#LLLLLLLLLLLLLL#",
    ".##############.",
]

BODIES = {r: globals()[f"BODY_{r.upper()}"] for r in RUNES}
TILES = {r: globals()[f"TILE_{r.upper()}"] for r in RUNES}

BADGE = [
    ".#####.",
    "#######",
    "#######",
    "#######",
    "#######",
    "#######",
    "#######",
    "#######",
    ".#####.",
]

DIGITS = {  # 3x5, drawn in N7 at (2, 2) of the badge
    1: [".7.", "77.", ".7.", ".7.", "777"],
    2: ["77.", "..7", ".7.", "7..", "777"],
    3: ["77.", "..7", ".7.", "..7", "77."],
    4: ["7.7", "7.7", "777", "..7", "..7"],
    5: ["777", "7..", "77.", "..7", "77."],
    6: [".77", "7..", "777", "7.7", "777"],
    7: ["777", "..7", ".7.", ".7.", ".7."],
    8: ["777", "7.7", "777", "7.7", "777"],
    9: ["777", "7.7", "777", "..7", "77."],
}


def num(n: int) -> Image.Image:
    img = grid(BADGE)
    paste(img, grid(DIGITS[n], width=3), 2, 2)
    return img


ASSETS: dict = {}
for _r in RUNES:
    ASSETS[f"die_body_{_r}"] = (lambda r=_r: grid(BODIES[r]))
    ASSETS[f"face_tile_{_r}"] = (lambda r=_r: grid(TILES[r]))
for _n in DIGITS:
    ASSETS[f"num_{_n}"] = (lambda n=_n: num(n))


if __name__ == "__main__":
    sys.exit(run(ASSETS, sys.argv[1:]))
