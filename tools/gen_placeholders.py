"""Generate placeholder PNGs for every entry in assets/manifest.json (ART_SPEC §9.1).

    python tools/gen_placeholders.py                 # write only missing files (never overwrites art)
    python tools/gen_placeholders.py --only "relics/*" --only skeleton_warrior
                                                     # (re)write entries whose id or path matches a glob
    python tools/gen_placeholders.py --force         # rewrite everything

Placeholders already satisfy tools/validate_art.py, so final art replaces files 1:1.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import mini_font
from palette import ELEMENT_RAMP, ROOT, TINT_WHITE, ramp, rgba, write_palette_files

MANIFEST = ROOT / "assets" / "manifest.json"
CLEAR = (0, 0, 0, 0)
RARITY_KEY = {"COMMON": "I1", "UNCOMMON": "L1", "RARE": "R1"}
T3 = {"lich", "headless_horseman", "stitched_golem", "witch_queen"}


# ---------------------------------------------------------------------------- drawing helpers
def new(w: int, h: int, key: str | None = None) -> Image.Image:
    return Image.new("RGBA", (w, h), rgba(key) if key else CLEAR)


def put(img: Image.Image, x: int, y: int, key: str) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), rgba(key))


def fill_rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, key: str) -> None:
    """Inclusive rectangle."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, key)


def notched_rect(img: Image.Image, x0: int, y0: int, x1: int, y1: int, key: str, notch: int = 1) -> None:
    """Rectangle with stepped corners `notch` px deep."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            dx = min(x - x0, x1 - x)
            dy = min(y - y0, y1 - y)
            if dx + dy < notch:
                continue
            put(img, x, y, key)


def outline(img: Image.Image, key: str = "N0", region: tuple[int, int, int, int] | None = None) -> None:
    """Turn opaque pixels that touch transparency / the canvas edge (4-neighbour) into `key`.
    Keeps the silhouette's bounds; region limits the pass to (x0, y0, x1, y1) inclusive (frame)."""
    x0, y0, x1, y1 = region or (0, 0, img.width - 1, img.height - 1)
    px = img.load()
    edge = []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if px[x, y][3] == 0:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if nx < x0 or nx > x1 or ny < y0 or ny > y1 or px[nx, ny][3] == 0:
                    edge.append((x, y))
                    break
    c = rgba(key)
    for x, y in edge:
        px[x, y] = c


def grow_outline(img: Image.Image, key: str = "N0") -> None:
    """Add an outline *outside* the opaque pixels (8-neighbour)."""
    px = img.load()
    add = []
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3]:
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < img.width and 0 <= ny < img.height and px[nx, ny][3]:
                        add.append((x, y))
                        break
                else:
                    continue
                break
    for x, y in add:
        px[x, y] = rgba(key)


def text(img: Image.Image, x: int, y: int, s: str, key: str, scale: int = 1) -> None:
    for dx, dy in mini_font.text_pixels(s, scale):
        put(img, x + dx, y + dy, key)


def text_c(img: Image.Image, cx: int, y: int, s: str, key: str, scale: int = 1) -> None:
    """Text horizontally centred on column cx (cx = left edge + width/2)."""
    text(img, cx - mini_font.text_width(s, scale) // 2, y, s, key, scale)


def fit_tag(tag: str, inner_w: int, inner_h: int) -> str:
    if inner_h < mini_font.GLYPH_H:
        return ""
    while tag and mini_font.text_width(tag) > inner_w:
        tag = tag[:-1]
    return tag


def mid(el: str) -> str:
    return ramp(el)[1]


def light(el: str) -> str:
    return ramp(el)[2]


def dark(el: str) -> str:
    return ramp(el)[0]


def colour_of(hint: str | None, step: int = 1) -> str | None:
    """Element name -> ramp step; palette/mask key -> itself."""
    if hint is None:
        return None
    if hint in ELEMENT_RAMP:
        return ramp(hint)[step]
    return hint


# ---------------------------------------------------------------------------- characters
def draw_unit(e: dict) -> Image.Image:
    img = new(32, 16)
    mask = "mask" in e["flags"]
    floating = "floating" in e["flags"]
    if mask:
        fill, hi, acc = "A1", "A2", "C1"
        acc_is_element = True
    else:
        fill, hi = mid(e["ramp"]), light(e["ramp"])
        acc_is_element = e["accent"] in ELEMENT_RAMP
        acc = colour_of(e["accent"]) if e["accent"] else None
    t3 = e["id"] in T3
    for f in range(2):
        ox = f * 16
        if floating:
            top, bot = 2 + f, 12 + f      # bob 1 px; y=14 stays empty
            fill_rect(img, ox + 5, 15, ox + 10, 15, "N0")   # shadow row, 6 px
        else:
            top, bot = (2 if t3 else 3) + f, 15  # squash 1 px, feet on y=15
        notched_rect(img, ox + 2, top, ox + 13, bot, fill, notch=2)
        fill_rect(img, ox + 4, top + 1, ox + 11, top + 1, hi)   # top-left light
        fill_rect(img, ox + 3, top + 2, ox + 3, top + 3, hi)
        if acc and acc_is_element:
            # hybrid: secondary ramp ~30% (right third)
            for y in range(top, bot + 1):
                for x in range(ox + 10, ox + 14):
                    if img.getpixel((x, y))[3]:
                        img.putpixel((x, y), rgba(acc))
        outline(img, "N0", (ox, 0, ox + 15, 14 if floating else 15))
        if acc and not acc_is_element:
            put(img, ox + 5, top + 3, acc)          # small accent (eyes/glow) <= 10%
            put(img, ox + 10, top + 3, acc)
        tag = fit_tag(e["tag"], 10, 5)
        text_c(img, ox + 8, top + 5 if bot - top >= 10 else top + 4, tag, "N0")
        if t3:  # tier mark: crown pixels in G1 above the head
            for x in (5, 8, 10):
                put(img, ox + x, top - 1, "G1")
            fill_rect(img, ox + 5, top, ox + 10, top, "G1")
    return img


def draw_legion(e: dict) -> Image.Image:
    img = new(16, 16)
    fill_rect(img, 3, 1, 5, 15, "B1")          # pole
    notched_rect(img, 5, 2, 14, 11, "N3")      # tattered flag
    for x in (7, 10, 13):
        put(img, x, 11, "N3")
        img.putpixel((x - 1, 11), CLEAR)
    outline(img)
    fill_rect(img, 6, 3, 13, 3, "N5")
    text_c(img, 10, 5, fit_tag(e["tag"], 8, 5), "N5")
    return img


def draw_mini(e: dict) -> Image.Image:
    img = new(16, 8)
    mask = "mask" in e["flags"]
    fill, hi = ("A1", "A2") if mask else (mid(e["ramp"]), light(e["ramp"]))
    for f in range(2):
        ox = f * 8
        top = 1 + f
        notched_rect(img, ox + 1, top, ox + 6, 7, fill)
        fill_rect(img, ox + 2, top + 1, ox + 4, top + 1, hi)
        outline(img, "N0", (ox, 0, ox + 7, 7))
        text(img, ox + 3, 2, e["tag"][:1], "N0")  # 1 letter; overlaps the top outline when squashed
    return img


def _enemy_frame(img: Image.Image, ox: int, e: dict, breathe: int, hurt: bool, boss: bool) -> None:
    body = colour_of(e["ramp"]) or "N4"
    body_hi = colour_of(e["ramp"], 2) if e["ramp"] in ELEMENT_RAMP else body
    acc = colour_of(e["accent"]) if e["accent"] else None
    sh = 2 if hurt else 0      # recoil to the right, feet stay on y=31
    x0, x1 = (2, 29) if boss else (7, 24)
    head_top = (2 if boss else 4) + breathe
    torso_top = head_top + 10
    # torso (accent / clothing)
    notched_rect(img, ox + x0 + sh, torso_top, ox + x1, 31, body, notch=2)
    fill_rect(img, ox + x0 + sh + 2, torso_top + 1, ox + x1 - 2, torso_top + 1, body_hi)
    if acc:
        fill_rect(img, ox + x0 + sh + 1, torso_top + 6, ox + x1 - 1, torso_top + 7, acc)
    # head (skin)
    hx0, hx1 = ox + 11 + sh, ox + 20 + sh
    notched_rect(img, hx0, head_top, hx1, torso_top, "S1", notch=2)
    fill_rect(img, hx1 - 1, head_top + 2, hx1 - 1, torso_top - 1, "S0")
    outline(img, "N0", (ox, 0, ox + 31, 31))
    if hurt:   # eyes shut
        fill_rect(img, hx0 + 2, head_top + 4, hx0 + 3, head_top + 4, "N0")
        fill_rect(img, hx1 - 4, head_top + 4, hx1 - 3, head_top + 4, "N0")
    else:
        fill_rect(img, hx0 + 3, head_top + 3, hx0 + 3, head_top + 4, "N0")
        fill_rect(img, hx1 - 3, head_top + 3, hx1 - 3, head_top + 4, "N0")
    tx = ox + (x0 + x1 + 1) // 2 + sh // 2
    text_c(img, tx, torso_top + 9 if acc else torso_top + 4, fit_tag(e["tag"], x1 - x0 - 3, 5), "N0")


def draw_enemy(e: dict) -> Image.Image:
    img = new(e["w"], 32)
    boss = e["id"].startswith("boss_")
    if e["category"] == "shopkeeper":
        for f in range(2):
            ox = f * 32
            # skull head in top hat behind a coffin counter
            notched_rect(img, ox + 11, 3 + f, ox + 20, 6 + f, "N4")            # hat
            notched_rect(img, ox + 12, 7 + f, ox + 19, 15 + f, "B2", notch=2)   # skull
            notched_rect(img, ox + 2, 16, ox + 29, 31, "N4", notch=2)           # coffin counter
            fill_rect(img, ox + 4, 17, ox + 27, 17, "N5")
            outline(img, "N0", (ox, 0, ox + 31, 31))
            put(img, ox + 14, 10 + f, "N0")
            put(img, ox + 17, 10 + f, "N0")
            fill_rect(img, ox + 12, 6 + f, ox + 19, 6 + f, "G1")   # hat band (accent)
            text_c(img, ox + 16, 22, fit_tag(e["tag"], 24, 5), "G1")
        return img
    for f, (breathe, hurt) in enumerate(((0, False), (1, False), (0, True))):
        _enemy_frame(img, f * 32, e, breathe, hurt, boss)
    return img


# ---------------------------------------------------------------------------- dice
def _die(img: Image.Image, ox: int, oy: int, size: int = 20, side: int = 3) -> None:
    notched_rect(img, ox, oy, ox + size - 1, oy + size - 1, "B2", notch=2)
    for y in range(oy + size - side, oy + size):
        for x in range(ox, ox + size):
            if img.getpixel((x, y))[3]:
                img.putpixel((x, y), rgba("B0"))
    fill_rect(img, ox + size - 3, oy + 2, ox + size - 3, oy + size - side - 1, "B1")  # face shading
    fill_rect(img, ox + 2, oy + size - side - 1, ox + size - 3, oy + size - side - 1, "B1")
    outline(img, "N0", (ox, oy, ox + size - 1, oy + size - 1))


def draw_dice(e: dict) -> Image.Image:
    img = new(e["w"], e["h"])
    if e["id"] == "die_body":
        _die(img, 0, 0)
    else:  # die_roll: 4 tumble frames, smaller die bouncing inside 20x20
        for f, (dx, dy) in enumerate(((0, 2), (2, 0), (2, 2), (0, 0))):
            _die(img, f * 20 + dx, dy, size=18, side=2 + (f % 2))
    return img


def draw_glyph(e: dict, size: int) -> Image.Image:
    img = new(size, size)
    if e["ramp"] == "WILD":
        fill, hi = "G1", "N7"
    else:
        fill, hi = mid(e["ramp"]), light(e["ramp"])
    notched_rect(img, 0, 0, size - 1, size - 1, fill, notch=2 if size >= 12 else 1)
    fill_rect(img, 2, 1, size - 3, 1, hi)
    outline(img)
    tag = e["tag"] if size >= 12 else e["tag"][:1]
    tag = fit_tag(tag, size - 2, size - 2)
    text_c(img, size // 2, (size - 5) // 2 + (1 if size >= 12 else 0), tag, "N0")
    return img


def draw_pip(e: dict) -> Image.Image:
    img = new(6, 6)
    notched_rect(img, 0, 0, 5, 5, mid(e["ramp"]), notch=2)
    put(img, 2, 1, light(e["ramp"]))
    put(img, 2, 2, light(e["ramp"]))
    outline(img)
    return img


def draw_mod(e: dict) -> Image.Image:
    img = new(5, 5)
    notched_rect(img, 0, 0, 4, 4, e["ramp"])
    outline(img)
    put(img, 2, 2, "N7" if e["id"] == "mod_hex" else e["ramp"])
    return img


def draw_overlay(e: dict) -> Image.Image:
    img = new(e["w"], e["h"])
    i = e["id"]
    if i in ("die_select", "die_bound"):
        ring = TINT_WHITE if i == "die_bound" else "G1"
        inner = new(22, 22)
        notched_rect(inner, 1, 1, 20, 20, "N0", notch=2)
        notched_rect(img, 0, 0, 21, 21, ring, notch=2)
        for y in range(22):
            for x in range(22):
                if inner.getpixel((x, y))[3]:
                    img.putpixel((x, y), CLEAR)     # 1 px ring only
    elif i == "die_shackle":
        for y in range(20):
            for x in range(20):
                dx, dy = min(x, 19 - x), min(y, 19 - y)
                if dx + dy >= 2 and (x + y) % 2 == 0:
                    put(img, x, y, "N0")          # 50% checker dim (no alpha)
        for x in range(0, 20):                    # chain across the die
            put(img, x, 9, "M1" if (x // 3) % 2 == 0 else "M0")
            put(img, x, 10, "M0" if (x // 3) % 2 == 0 else "M1")
    else:  # face_tile
        notched_rect(img, 0, 0, 15, 15, "B2")
        fill_rect(img, 14, 2, 14, 14, "B1")
        fill_rect(img, 2, 14, 14, 14, "B1")
        outline(img)
    return img


# ---------------------------------------------------------------------------- icons
def draw_icon_box(e: dict, fill: str, tag_key: str = "N7", stripe: str | None = None,
                  tag: bool = True) -> Image.Image:
    img = new(16, 16)
    notched_rect(img, 1, 1, 14, 14, fill, notch=2)
    outline(img)
    if stripe:
        fill_rect(img, 3, 12, 12, 12, stripe)
    if tag:
        text_c(img, 8, 5, fit_tag(e["tag"], 12, 5), tag_key)
    return img


def draw_relic(e: dict) -> Image.Image:
    return draw_icon_box(e, "N4", stripe=RARITY_KEY.get(e["accent"] or "", None))


def draw_consumable(e: dict, glyph_cache: dict[str, Image.Image], base_cache: dict[str, Image.Image]) -> Image.Image:
    kind = e["id"].split("_", 1)[0]
    if kind in ("tome", "sigil") and e["accent"]:
        base = base_cache[f"{kind}_base"].copy()
        glyph = glyph_cache[f"glyph8_{e['accent'].lower()}"]
        base.alpha_composite(glyph, (4, 4))  # ART_SPEC §5.2: glyph8 at (4, 4)
        return base
    accent = {"ink_wild": "G1", "ink_sharp": "R1", "ink_swarm": "L2", "ink_hex": "N5",
              "ink_gold": "G1", "spare_die": "B2"}.get(e["id"])
    return draw_icon_box(e, "N4", stripe=accent)


def draw_base(e: dict) -> Image.Image:
    # Tag sits under the glyph8 area (4..11) so composed icons hide it.
    img = draw_icon_box(e, e["ramp"], tag=False)
    if e["id"] == "tome_base":
        fill_rect(img, 3, 2, 3, 13, "N5")   # spine
    text_c(img, 8, 5, fit_tag(e["tag"], 7, 5), "N7")
    return img


def draw_stat(e: dict) -> Image.Image:
    img = new(8, 8)
    notched_rect(img, 0, 0, 7, 7, e["ramp"])
    outline(img)
    text(img, 3, 1, e["tag"][:1], "N0")
    put(img, 2, 1, "N7")
    return img


# ---------------------------------------------------------------------------- UI 9-slices
def panel(w: int, h: int, fill: str, *, border: str | None = None, top: str | None = None,
          bottom: str | None = None, outline_key: str = "N0", dashed: bool = False) -> Image.Image:
    img = new(w, h)
    for y in range(h):
        for x in range(w):
            if (x in (0, w - 1)) and (y in (0, h - 1)):
                continue                                   # 1 px notched corner
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d == 0:
                key = outline_key
            elif d == 1 and border and (not dashed or (x + y) % 2 == 0):
                key = border
            else:
                key = fill
                inner = 2 if border else 1
                if top and y == inner and inner <= x <= w - 1 - inner:
                    key = top
                if bottom and y == h - 1 - inner and inner <= x <= w - 1 - inner:
                    key = bottom
            put(img, x, y, key)
    return img


def draw_ui(e: dict) -> Image.Image:
    i, w, h = e["id"], e["w"], e["h"]
    btn = {"primary": ("F1", "F2", "F0"), "secondary": ("N4", "N5", "N2")}
    if i.startswith("btn_"):
        _, kind, state = i.split("_")
        f, hi, sh = btn[kind]
        if state == "normal":
            return panel(w, h, f, top=hi, bottom=sh)
        if state == "pressed":
            return panel(w, h, f, top=sh, bottom=hi)
        return panel(w, h, "N2")                       # disabled: N2, no bevel
    if i == "panel_dark":
        return panel(w, h, "N1", border="N3")
    if i == "panel_card":
        return panel(w, h, "N2", top="N4", bottom="N1")
    if i == "panel_tooltip":
        return panel(w, h, "N0", border="N5")
    if i == "chip":
        return panel(w, h, "N3", border="N5")
    if i == "slot":
        return panel(w, h, "N2", border="N3", dashed=True)
    if i == "slot_selected":
        return panel(w, h, "N2", border="G1")
    if i == "hp_frame":
        return panel(w, h, "N2")
    if i in ("hp_fill", "hp_preview"):
        img = new(w, h, "R1" if i == "hp_fill" else "G1")
        if i == "hp_fill":
            put(img, 0, 4, "R0")
        return img
    if i == "power_box":
        return panel(w, h, "I1", top="I2", bottom="I0")
    if i == "count_box":
        return panel(w, h, "R1", bottom="R0")
    if i.startswith("rarity_stripe_"):
        return new(w, h, RARITY_KEY[i.rsplit("_", 1)[1].upper()])
    if i == "divider":
        return new(w, h, "N3")
    if i == "stamp_defeated":
        flat = new(w, h)
        for x in range(2, 62):
            put(flat, x, 3, "R1")
            put(flat, x, 16, "R1")
        for y in range(3, 17):
            put(flat, 2, y, "R1")
            put(flat, 61, y, "R1")
        text_c(flat, 32, 7, "DEFEATED", "R1")
        img = new(w, h)                       # pre-rotated: stepped shear, ~-4 degrees
        for x in range(w):
            dy = (32 - x) // 16
            for y in range(h):
                p = flat.getpixel((x, y))
                if p[3] and 0 <= y + dy < h:
                    img.putpixel((x, y + dy), p)
        return img
    raise ValueError(f"no UI recipe for {i}")


# ---------------------------------------------------------------------------- big images
def draw_logo(e: dict) -> Image.Image:
    img = new(160, 48)
    for line, y in (("RATTLE", 3), ("& ROLL", 25)):
        text_c(img, 80, y, line, "F1", scale=4)
    for y in range(48):          # top-left light: top 2 px of each letter row in F2
        for x in range(160):
            if img.getpixel((x, y)) == rgba("F1") and y in (3, 4, 25, 26):
                img.putpixel((x, y), rgba("F2"))
    grow_outline(img)
    return img


def draw_app_icon(e: dict) -> Image.Image:
    img = new(32, 32, "N1")
    _die(img, 4, 4, size=24, side=4)
    text_c(img, 16, 9, e["tag"], "N0", scale=2)
    return img


def draw_howto(e: dict) -> Image.Image:
    img = panel(200, 120, "N1", border="N3")
    text_c(img, 100, 45, f"HOW TO {e['id'][-1]}", "N5", scale=3)
    return img


def draw_bg(e: dict) -> Image.Image:
    w, h, i = e["w"], e["h"], e["id"]
    img = new(w, h, "N1")
    d = ImageDraw.Draw(img)
    n2 = rgba("N2")
    if i == "bg_battle":
        d.ellipse((214, 22, 250, 58), fill=n2)                      # moon top-right
        d.polygon([(0, 110), (60, 96), (130, 108), (200, 94), (270, 104), (270, 126), (0, 126)], fill=n2)
        for x in range(6, 270, 14):                                 # crooked fence
            d.rectangle((x, 112 + (x // 14) % 3, x + 2, 126), fill=n2)
        for x, y in ((30, 330), (210, 334), (120, 420)):            # gravestones below the band
            d.rectangle((x, y, x + 12, y + 14), fill=n2)
    elif i == "bg_battle_ext":
        for x, y in ((20, 20), (150, 50), (230, 14), (90, 70)):
            d.rectangle((x, y, x + 6, y + 4), fill=n2)
    elif i == "bg_title":
        d.ellipse((75, 20, 195, 140), fill=n2)                      # big moon
        d.rectangle((60, 320, 210, 480), fill=n2)                   # castle
        for x in (60, 100, 150, 190):
            d.rectangle((x, 280, x + 20, 320), fill=n2)
        for x, y in ((40, 60), (220, 90), (30, 150)):               # bats
            d.polygon([(x, y), (x + 6, y + 4), (x + 12, y)], fill=n2)
    elif i == "bg_map":
        pts = [(135, 480), (80, 400), (190, 300), (70, 190), (170, 90), (135, 0)]
        d.line(pts, fill=n2, width=14)                               # winding road
        for x, y in ((40, 380), (220, 250), (40, 120)):              # lantern posts
            d.rectangle((x, y, x + 3, y + 30), fill=n2)
            d.rectangle((x - 2, y - 6, x + 5, y), fill=n2)
    elif i == "bg_shop":
        for y in (150, 230, 310):                                   # shelves
            d.rectangle((10, y, 260, y + 4), fill=n2)
        for x in (30, 120, 220):                                    # candles
            d.rectangle((x, 130, x + 3, 150), fill=n2)
    text(img, 4, h - 14, e["tag"], "N2", scale=2)
    return img


def draw_vfx(e: dict) -> Image.Image:
    i, fw, n = e["id"], e["frame_w"], e["frames"]
    img = new(e["w"], e["h"])
    d = ImageDraw.Draw(img)
    for f in range(n):
        ox = f * fw
        if i == "spark":
            for x, y in ((1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (2, 2)):
                put(img, ox + x, y, TINT_WHITE)
        elif i == "puff":
            r = (1, 2, 3, 3)[f]
            d.ellipse((ox + 4 - r, 4 - r, ox + 3 + r, 3 + r), fill=rgba("N6" if f == 3 else "N7"))
            if f == 3:
                img.putpixel((ox + 4, 4), CLEAR)
        elif i == "slash":
            length = (6, 11, 14)[f]
            for k in range(length):
                put(img, ox + 1 + k, 14 - k, "N7")
                put(img, ox + 1 + k, 15 - k if k < length - 1 else 14 - k, "N6")
        elif i == "coin":
            half = (3, 2, 1, 2)[f]
            fill_rect(img, ox + 3 - half, 0, ox + 2 + half, 5, "G1")
            fill_rect(img, ox + 2 + half, 1, ox + 2 + half, 5, "G0")
        elif i == "soul":
            notched_rect(img, ox + 1, f, ox + 4, 4 + f, "I2")
            put(img, ox + 2, 1 + f, "N7")
        elif i == "impact_ring":
            r = (3, 5, 7)[f]
            d.ellipse((ox + 8 - r, 8 - r, ox + 7 + r, 7 + r), outline=rgba("N7"))
        elif i == "aura":
            d.ellipse((ox + 3, 3, ox + 36, 36), outline=rgba("R0"), width=2)
            for k in range(8):   # rotating flames
                a = k * 5 + f
                x = ox + 20 + int(17 * math.cos(a * 0.785))
                y = 20 + int(17 * math.sin(a * 0.785))
                fill_rect(img, x - 1, y - 1, x, y, "R1")
    return img


# ---------------------------------------------------------------------------- driver
def render(e: dict, glyphs: dict[str, Image.Image], bases: dict[str, Image.Image]) -> Image.Image:
    c = e["category"]
    if c == "unit":
        return draw_unit(e)
    if c == "legion":
        return draw_legion(e)
    if c == "mini":
        return draw_mini(e)
    if c in ("enemy", "shopkeeper"):
        return draw_enemy(e)
    if c == "dice":
        return draw_dice(e)
    if c == "glyph":
        return draw_glyph(e, 12)
    if c == "glyph8":
        return draw_glyph(e, 8)
    if c == "pip":
        return draw_pip(e)
    if c == "mod":
        return draw_mod(e)
    if c == "dice_overlay":
        return draw_overlay(e)
    if c == "relic_icon":
        return draw_relic(e)
    if c == "consumable_base":
        return draw_base(e)
    if c == "consumable_icon":
        return draw_consumable(e, glyphs, bases)
    if c == "equipment_icon":
        return draw_icon_box(e, "N4")
    if c == "stat_icon":
        return draw_stat(e)
    if c == "ui":
        return draw_ui(e)
    if c == "logo":
        return draw_logo(e)
    if c == "app_icon":
        return draw_app_icon(e)
    if c == "howto":
        return draw_howto(e)
    if c == "bg":
        return draw_bg(e)
    if c == "vfx":
        return draw_vfx(e)
    raise ValueError(f"unknown category {c}")


def _load_or(path: Path, fallback: Image.Image) -> Image.Image:
    """Composition sources: prefer the file on disk (may be approved art)."""
    if path.exists():
        return Image.open(path).convert("RGBA")
    return fallback


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--force", action="store_true", help="overwrite every file")
    ap.add_argument("--only", action="append", default=[], metavar="GLOB",
                    help="(re)generate entries whose id or path matches GLOB (repeatable); overwrites them")
    args = ap.parse_args(argv)

    if not MANIFEST.exists():
        print("assets/manifest.json missing - run tools/build_manifest.py first")
        return 1
    entries = json.loads(MANIFEST.read_text(encoding="utf-8"))["files"]

    pal = write_palette_files()
    print(f"palette: wrote {', '.join(p.name for p in pal)}")

    def selected(e: dict) -> bool:
        return any(fnmatch.fnmatch(e["id"], g) or fnmatch.fnmatch(e["path"], g)
                   or fnmatch.fnmatch(e["path"], f"*{g}*") for g in args.only)

    # Composition sources first (glyph8 + bases), so composed consumables use what is on disk.
    order = sorted(entries, key=lambda e: 0 if e["category"] in ("glyph8", "consumable_base") else 1)
    glyphs: dict[str, Image.Image] = {}
    bases: dict[str, Image.Image] = {}
    written: dict[str, int] = {}
    skipped = 0
    for e in order:
        path = ROOT / e["path"]
        if args.only:
            write = selected(e)
        else:
            write = args.force or not path.exists()
        img = None
        if write:
            # Generate glyph/base sources lazily via the cache below.
            img = render(e, glyphs, bases)
            assert img.size == (e["w"], e["h"]), (e["path"], img.size)
            path.parent.mkdir(parents=True, exist_ok=True)
            img.save(path)
            written[e["category"]] = written.get(e["category"], 0) + 1
        else:
            skipped += 1
        if e["category"] == "glyph8":
            glyphs[e["id"]] = _load_or(path, img or render(e, glyphs, bases))
        elif e["category"] == "consumable_base":
            bases[e["id"]] = _load_or(path, img or render(e, glyphs, bases))

    total = sum(written.values())
    print(f"placeholders: wrote {total}, kept {skipped} existing (of {len(entries)})")
    if written:
        print("  " + ", ".join(f"{k} {v}" for k, v in written.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
