"""Hallow32 palette + K0 (ART_SPEC §3) — the single source of truth for palette colours.

    python tools/palette.py     # writes assets/palette/hallow32.gpl, hallow32.hex and hallow32.png (33x1)

Other tools import HALLOW32 / rgb() / MASK_KEYS from here.
"""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PALETTE_DIR = ROOT / "assets" / "palette"

# Order matters: it is the order of the .gpl / .hex entries and the 33x1 strip. K0 (pure black,
# the designer's deepest sky and void, D-R14) is appended so the original 32 keep their places.
HALLOW32: dict[str, str] = {
    "N0": "#0d0a14", "N1": "#1a1326", "N2": "#281d3b", "N3": "#3b2c55",
    "N4": "#574577", "N5": "#8577a3", "N6": "#c4bad8", "N7": "#f4efe4",
    "B0": "#7b6a52", "B1": "#bba783", "B2": "#e9ddbf",
    "F0": "#b33a10", "F1": "#f2781c", "F2": "#ffc85a",
    "I0": "#23589c", "I1": "#4fb6ea", "I2": "#c6f1ff",
    "L0": "#1f6136", "L1": "#49b23f", "L2": "#b4ec6a",
    "V0": "#7d7a12", "V1": "#e3df34", "V2": "#fbfaa6",
    "M0": "#4f5b66", "M1": "#93a3ae", "M2": "#dfe8ec",
    "R0": "#8c1c34", "R1": "#e0344a",
    "G0": "#c98a17", "G1": "#ffe066",
    "S0": "#a8643c", "S1": "#f0b896",
    "K0": "#000000",
}
assert len(HALLOW32) == 33

# §4.3 mask key colours (runtime palette swap). Outline stays N0.
MASK_KEYS: dict[str, str] = {
    "A0": "#ff0000", "A1": "#ff6060", "A2": "#ffc0c0",
    "C0": "#0000ff", "C1": "#6060ff", "C2": "#c0c0ff",
}

# Pure white, only for files flagged "tint" (tinted at runtime, §4.6 die_bound, §10 spark).
TINT_WHITE = "#ffffff"

# Element -> palette ramp prefix (dark, mid, light = <P>0, <P>1, <P>2).
ELEMENT_RAMP: dict[str, str] = {
    "BONE": "B", "FIRE": "F", "ICE": "I", "LEAF": "L", "VOLT": "V", "METAL": "M",
}


def hex_to_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def rgb(key: str) -> tuple[int, int, int]:
    """RGB for a Hallow32 or mask key, or a literal '#rrggbb'."""
    if key.startswith("#"):
        return hex_to_rgb(key)
    if key in HALLOW32:
        return hex_to_rgb(HALLOW32[key])
    return hex_to_rgb(MASK_KEYS[key])


def rgba(key: str) -> tuple[int, int, int, int]:
    return (*rgb(key), 255)


def ramp(element: str) -> tuple[str, str, str]:
    p = ELEMENT_RAMP[element]
    return f"{p}0", f"{p}1", f"{p}2"


HALLOW32_RGB: frozenset[tuple[int, int, int]] = frozenset(hex_to_rgb(v) for v in HALLOW32.values())
MASK_RGB: frozenset[tuple[int, int, int]] = frozenset(
    [hex_to_rgb(v) for v in MASK_KEYS.values()] + [hex_to_rgb(HALLOW32["N0"])]
)


def write_palette_files(out_dir: Path = PALETTE_DIR) -> list[Path]:
    from PIL import Image

    out_dir.mkdir(parents=True, exist_ok=True)
    lines = ["GIMP Palette", "Name: Hallow32+K0", "Columns: 8", "#"]
    for key, hx in HALLOW32.items():
        r, g, b = hex_to_rgb(hx)
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{key} {hx}")
    gpl = out_dir / "hallow32.gpl"
    gpl.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")

    hexf = out_dir / "hallow32.hex"
    hexf.write_text("\n".join(v.lstrip("#") for v in HALLOW32.values()) + "\n", encoding="utf-8", newline="\n")

    img = Image.new("RGBA", (len(HALLOW32), 1))
    for i, key in enumerate(HALLOW32):
        img.putpixel((i, 0), rgba(key))
    png = out_dir / "hallow32.png"
    img.save(png)
    return [gpl, hexf, png]


if __name__ == "__main__":
    for p in write_palette_files():
        print(f"wrote {p.relative_to(ROOT).as_posix()}")
