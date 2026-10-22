"""Draw wireframe mockups of the landscape screen layouts (ART_SPEC §6) for review.

    python tools/layout_mockup.py            # writes docs/mockups/*.png (x3 nearest zoom)

Every rect here mirrors a row of the ART_SPEC §6 tables; the layouts are functions of the
canvas size so the flex rule (extra width -> centre column, extra height -> battlefield /
info panel) is visible on the 640x300 variant. This is a review aid: the .tscn scenes are the
source of truth once built.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from palette import rgb  # noqa: E402

OUT = ROOT / "docs" / "mockups"
FONT = ImageFont.truetype(str(ROOT / "assets/fonts/fusion_pixel/fusion_pixel_8px.otf"), 8)
ZOOM = 3
BASE = (480, 270)
WIDE = (640, 300)

# role -> (fill, outline, text)
STYLE = {
    "bar": ("N2", "N4", "N6"),
    "panel": ("N2", "N3", "N6"),
    "field": ("N1", "N3", "N5"),
    "enemy": ("N3", "S0", "S1"),
    "slot": ("N3", "N5", "N6"),
    "die": ("B2", "N0", "N0"),
    "primary": ("F1", "F0", "N0"),
    "secondary": ("N4", "N5", "N7"),
    "power": ("I1", "I0", "N7"),
    "count": ("R1", "R0", "N7"),
    "card": ("N2", "N4", "N6"),
    "chip": ("N3", "N5", "N6"),
    "money": ("N1", "G0", "G1"),
    "dim": ("N0", "N0", "N0"),
}


def col(key: str) -> tuple[int, int, int]:
    return rgb(key)


def common_top(w: int) -> list:
    relic_w = 5 * 20 + 4 * 4
    rx = (w - relic_w) // 2
    rows = [("bar", (0, 0, w, 24), "NIGHT 3 · BOSS")]
    rows += [("slot", (rx + i * 24, 2, 20, 20), f"R{i + 1}") for i in range(5)]
    rows += [("money", (w - 78, 4, 36, 16), "$12"), ("secondary", (w - 40, 4, 16, 16), "CX"),
             ("secondary", (w - 20, 4, 16, 16), "S")]
    return rows


def encounter(w: int, h: int) -> list:
    cw = w - 256               # centre column width (224 at base)
    cx = 128
    rx = w - 124               # right column x
    bf_h = h - 98 - 32         # battlefield height (140 at base)
    rows = common_top(w)
    rows += [
        ("panel", (4, 28, 120, 40), "BOSS RULE\nHoly Water: BONE ½P"),
        ("panel", (4, 72, 120, 40), ""),
        ("power", (8, 76, 48, 14), "P 70"), ("count", (68, 76, 48, 14), "C 36"),
        ("money", (8, 94, 112, 14), "= 2,520 / 1,200"),
        ("panel", (4, 116, 120, 12), "B5 F1 I1 L0 V0 M0"),
        ("slot", (8, 132, 20, 20), "C1"), ("slot", (32, 132, 20, 20), "C2"),
        ("panel", (4, 156, 120, h - 160), "INFO PANEL\n(docked tooltip:\nrelic / die / unit /\nconsumable text)"),
        ("enemy", (cx + (cw - 32) // 2, 28, 32, 32), "EN"),
        ("chip", (cx + (cw - 48) // 2, 58, 48, 4), ""),
        ("bar", (cx + (cw - 120) // 2, 64, 120, 10), "THE EXORCIST"),
        ("count", (cx + (cw - 160) // 2, 76, 160, 7), ""),
        ("bar", (cx + (cw - 80) // 2, 85, 80, 10), "1,200 HP"),
        ("field", (cx, 98, cw, bf_h), "BATTLEFIELD\n(army; extra width + height)"),
    ]
    tray_w = 8 * 20 + 7 * 6
    tx = cx + (cw - tray_w) // 2
    rows += [("die", (tx + i * 26, h - 26, 20, 20), "d") for i in range(8)]
    rows += [
        ("slot", (rx, 28, 58, 20), "SUMMONS 2"), ("slot", (rx + 62, 28, 58, 20), "REROLLS 1"),
        ("panel", (rx, 52, 120, 100), ""),
        ("chip", (rx + 2, 62, 116, 20), "1 SKELETON WAR."), ("chip", (rx + 2, 84, 116, 20), "2 WISP"),
        ("panel", (rx, 156, 120, h - 216), "HINT"),
        ("secondary", (rx, h - 60, 58, 24), "REROLL 1"), ("secondary", (rx + 62, h - 60, 58, 24), "BIND"),
        ("primary", (rx, h - 32, 58, 24), "SUMMON"), ("primary", (rx + 62, h - 32, 58, 24), "ATTACK!"),
    ]
    return rows


def shop(w: int, h: int) -> list:
    """Grid: columns A 4..124, B 128..w-128, C w-124..w-4; rows 1 y 28..148, 2 y 152..h-4."""
    cw = w - 256
    cx = 128
    rx = w - 124
    card_w = (cw - 8) // 3
    rows = common_top(w)
    rows += [("card", (4, 28, 120, 120), "EQUIPMENT\nicon x2\nname $10\neffect\n\n\nBUY"),
             ("panel", (4, 152, 120, h - 156), "INFO PANEL\n(+ USE / SELL)")]
    for i in range(3):
        x = cx + i * (card_w + 4)
        rows += [("card", (x, 28, card_w, 120), ""), ("power", (x, 28, card_w, 4), ""),
                 ("slot", (x + (card_w - 32) // 2, 34, 32, 32), "ICONx2"),
                 ("bar", (x + 4, 68, card_w - 8, 18), "Name\n2 lines"),
                 ("money", (x + 4, 88, card_w - 8, 10), "$6"),
                 ("primary", (x + 4, 100, card_w - 8, 18), "BUY"),
                 ("secondary", (x + 4, 122, card_w - 8, 18), "USE")]
    rows += [("panel", (cx, 152, cw, h - 156), "YOUR LOADOUT\nITEMS [C1][C2]\nDICE [d][d][d][d]\nGEAR [e][e]"),
             ("field", (rx, 28, 120, h - 88), "DECOR\n(alcove, shelf)\n\n\n\nSHOPKEEPER"),
             ("secondary", (rx, h - 56, 120, 24), "REROLL $4"),
             ("primary", (rx, h - 28, 120, 24), "NEXT FIGHT")]
    return rows


def night_map(w: int, h: int) -> list:
    rows = common_top(w)
    card_w = (w - 16 - 8) // 3
    for i, name in enumerate(["MOB", "CHAMPION", "BOSS"]):
        x = 8 + i * (card_w + 4)
        rows += [("card", (x, 32, card_w, h - 78), ""),
                 ("enemy", (x + (card_w - 32) // 2, 44, 32, 32), "EN"),
                 ("bar", (x + 8, 86, card_w - 16, 30), f"{name}\nHP 1,200 · $5"),
                 ("chip", (x + 8, 122, card_w - 16, 20), "rule chip (boss)")]
    rows += [("count", (8 + 4, 150, 64, 20), "DEFEATED")]
    rows += [("primary", ((w - 160) // 2, h - 34, 160, 24), "FIGHT")]
    return rows


def title(w: int, h: int) -> list:
    bx = (w - 140) // 2
    rows = [("field", (0, 0, w, h), ""), ("primary", ((w - 160) // 2, 40 + (h - 270) // 2, 160, 48), "LOGO 160×48")]
    y0 = 104 + (h - 270) // 2
    for i, label in enumerate(["CONTINUE", "NEW RUN", "HOW TO PLAY", "SETTINGS"]):
        rows.append(("secondary" if i == 0 else "primary", (bx, y0 + i * 28, 140, 24), label))
    rows.append(("bar", ((w - 120) // 2, h - 12, 120, 9), "v0.0.1 · seed"))
    return rows


def overlays(w: int, h: int) -> list:
    rows = [("dim", (0, 0, w, h), "")]
    rows += [("panel", ((w - 300) // 2, (h - 232) // 2, 300, 232), "DICE INSPECTOR 300×232\n8 rows × 6 face tiles 16×16\n\n\n\n\n\n\n\n\n\nCONFIRM / CANCEL")]
    return rows


SCREENS = {"encounter": encounter, "shop": shop, "night_map": night_map, "title": title,
           "overlay_inspector": overlays}


def render(rows: list, size: tuple[int, int]) -> Image.Image:
    img = Image.new("RGB", size, col("N1"))
    d = ImageDraw.Draw(img)
    for role, (x, y, w, h), label in rows:
        fill, line, ink = STYLE[role]
        d.rectangle((x, y, x + w - 1, y + h - 1), fill=col(fill), outline=col(line))
        if label:
            d.multiline_text((x + 2, y + 1), label, font=FONT, fill=col(ink), spacing=1)
    return img.resize((size[0] * ZOOM, size[1] * ZOOM), Image.NEAREST)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in SCREENS.items():
        for tag, size in (("base", BASE), ("wide", WIDE)):
            if name.startswith("overlay") and tag == "wide":
                continue
            path = OUT / f"{name}_{tag}_{size[0]}x{size[1]}.png"
            render(fn(*size), size).save(path)
            print(path.relative_to(ROOT).as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main())
