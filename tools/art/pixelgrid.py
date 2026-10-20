"""Shared helpers for the final pixel-art generators (ART_SPEC §4–§5, skill godot-pixel-art-generation).

Art is authored as hand-placed row-string grids with a legend of palette keys, never as
primitives. A generator module (tools/art/<group>.py) defines ASSETS = {id: draw_fn} where
draw_fn() returns a PIL RGBA image at the exact manifest size, and calls `run(ASSETS, argv)`.

    python tools/art/<group>.py                 # write every id of the group that changed
    python tools/art/<group>.py --only frost_*  # only matching ids
    python tools/art/<group>.py --preview out.png  # x8 contact sheet, writes no asset

Rules enforced here:
  - the image size must equal the manifest entry (path, w, h);
  - every opaque pixel must be a Hallow32 colour (or a mask key for `mask` files);
  - a file is written only when its pixels changed (no byte churn in git).
Run `python tools/validate_art.py` afterwards; it is the gate.
"""

from __future__ import annotations

import fnmatch
import json
import sys
from pathlib import Path
from typing import Callable, Iterable

from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from palette import HALLOW32_RGB, MASK_RGB, TINT_WHITE, hex_to_rgb, rgba  # noqa: E402

MANIFEST = ROOT / "assets" / "manifest.json"
Legend = dict[str, "str | None"]

# Default legend letters usable in every grid (a module may extend or override per sprite).
# Palette keys are two characters, so grids use one-letter aliases:
BASE_LEGEND: Legend = {
    ".": None, " ": None,
    "#": "N0",                       # outline / void
    "1": "N1", "2": "N2", "3": "N3", "4": "N4", "5": "N5", "6": "N6", "7": "N7",
    "b": "B0", "B": "B1", "c": "B2",  # bone dark / mid / light
    "f": "F0", "F": "F1", "g": "F2",  # fire
    "i": "I0", "I": "I1", "j": "I2",  # ice
    "l": "L0", "L": "L1", "m": "L2",  # leaf
    "v": "V0", "V": "V1", "w": "V2",  # volt
    "t": "M0", "T": "M1", "u": "M2",  # metal (t = tin)
    "r": "R0", "R": "R1",             # red
    "o": "G0", "O": "G1",             # gold
    "s": "S0", "S": "S1",             # skin
    # mask keys (wisp masks only)
    "x": "A0", "X": "A1", "y": "A2",  # primary ramp
    "z": "C0", "Z": "C1", "q": "C2",  # secondary ramp
}


def manifest_entries() -> dict[str, dict]:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {e["id"]: e for e in data["files"]}


def grid(rows: Iterable[str], legend: Legend | None = None, width: int | None = None) -> Image.Image:
    """Row strings -> RGBA image. Rows shorter than `width` are padded with transparency."""
    rows = list(rows)
    leg = dict(BASE_LEGEND)
    if legend:
        leg.update(legend)
    w = width or max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        if len(row) > w:
            raise ValueError(f"row {y} is {len(row)} wide, canvas {w}: {row!r}")
        for x, ch in enumerate(row):
            if ch not in leg:
                raise KeyError(f"legend has no {ch!r} (row {y}: {row!r})")
            key = leg[ch]
            if key is not None:
                px[x, y] = rgba(key) if not key.startswith("#") else (*hex_to_rgb(key), 255)
    return img


def canvas(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def paste(dst: Image.Image, src: Image.Image, x: int, y: int) -> Image.Image:
    """Alpha-over paste with binary alpha (src opaque pixels replace dst)."""
    dst.alpha_composite(src, (x, y))
    return dst


def outline(img: Image.Image, key: str = "N0", diagonal: bool = False) -> Image.Image:
    """Add a 1 px exterior outline around every opaque pixel (4-connected by default)."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    col = rgba(key)
    n4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
    n8 = n4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in (n8 if diagonal else n4):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] != 0:
                    dst[x, y] = col
                    break
    return out


def recolor(img: Image.Image, mapping: dict[str, str]) -> Image.Image:
    """Swap palette keys (e.g. {'I1': 'R1'}) — used for variants and frames."""
    table = {rgba(a)[:3]: rgba(b) for a, b in mapping.items()}
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p[:3] in table:
                px[x, y] = table[p[:3]]
    return out


def shift(img: Image.Image, dx: int, dy: int) -> Image.Image:
    """Move the whole image by (dx, dy) on a same-size canvas (pixels pushed out are lost)."""
    out = canvas(*img.size)
    out.paste(img, (dx, dy), img)
    return out


def sheet(frames: list[Image.Image]) -> Image.Image:
    """Frames left to right, no padding (ART_SPEC §4.1)."""
    fw, fh = frames[0].size
    out = canvas(fw * len(frames), fh)
    for i, f in enumerate(frames):
        if f.size != (fw, fh):
            raise ValueError(f"frame {i} is {f.size}, expected {(fw, fh)}")
        out.paste(f, (i * fw, 0), f)
    return out


def squash(frame: Image.Image) -> Image.Image:
    """Idle frame 2 for grounded sprites: drop the top half by 1 px, feet stay on the last row."""
    w, h = frame.size
    bbox = frame.getbbox()
    if not bbox:
        return frame.copy()
    top, bottom = bbox[1], bbox[3]
    mid = (top + bottom) // 2
    out = canvas(w, h)
    upper = frame.crop((0, 0, w, mid))
    lower = frame.crop((0, mid, w, h))
    out.paste(lower, (0, mid), lower)
    out.paste(upper, (0, 1), upper)
    return out


def bob(frame: Image.Image, shadow_rows: int = 1) -> Image.Image:
    """Idle frame 2 for floating sprites: body moves down 1 px, the bottom shadow rows stay."""
    w, h = frame.size
    body = frame.crop((0, 0, w, h - shadow_rows))
    shadow = frame.crop((0, h - shadow_rows, w, h))
    out = canvas(w, h)
    out.paste(body, (0, 1), body)
    out.paste(shadow, (0, h - shadow_rows), shadow)
    # keep the row above the shadow empty so the body never touches it
    return out


def _check_colours(img: Image.Image, mask: bool, tint: bool) -> list[str]:
    allowed = set(MASK_RGB if mask else HALLOW32_RGB)
    if tint:
        allowed.add(hex_to_rgb(TINT_WHITE))
    bad = set()
    for p in img.getdata():
        if p[3] not in (0, 255):
            return [f"partial alpha {p[3]}"]
        if p[3] and p[:3] not in allowed:
            bad.add(p[:3])
    return [f"off-palette colour #{r:02x}{g:02x}{b:02x}" for r, g, b in sorted(bad)][:5]


def _same(a: Image.Image, b: Image.Image) -> bool:
    if a.size != b.size:
        return False
    a, b = a.convert("RGBA"), b.convert("RGBA")
    # compare only where either side is visible (transparent RGB may differ)
    for pa, pb in zip(a.getdata(), b.getdata()):
        if pa[3] == 0 and pb[3] == 0:
            continue
        if pa != pb:
            return False
    return True


def run(assets: dict[str, Callable[[], Image.Image]], argv: list[str]) -> int:
    entries = manifest_entries()
    only = [argv[i + 1] for i, a in enumerate(argv) if a == "--only" and i + 1 < len(argv)]
    preview = next((argv[i + 1] for i, a in enumerate(argv) if a == "--preview" and i + 1 < len(argv)), None)
    ids = [i for i in assets if not only or any(fnmatch.fnmatch(i, g) for g in only)]
    problems, written, same, images = [], 0, 0, {}
    for asset_id in ids:
        if asset_id not in entries:
            problems.append(f"{asset_id}: not in manifest")
            continue
        e = entries[asset_id]
        img = assets[asset_id]().convert("RGBA")
        if img.size != (e["w"], e["h"]):
            problems.append(f"{asset_id}: size {img.size}, manifest {(e['w'], e['h'])}")
            continue
        errs = _check_colours(img, "mask" in e["flags"], "tint" in e["flags"])
        if errs:
            problems.append(f"{asset_id}: {', '.join(errs)}")
            continue
        images[asset_id] = img
        if preview:
            continue
        path = ROOT / e["path"]
        if path.exists() and _same(Image.open(path), img):
            same += 1
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
        written += 1
    if preview and images:
        _contact_sheet(images).save(preview)
        print(f"preview: {preview} ({len(images)} assets)")
    for p in problems:
        print("PROBLEM", p)
    if not preview:
        print(f"art: wrote {written}, unchanged {same}, problems {len(problems)}")
    return 1 if problems else 0


def _contact_sheet(images: dict[str, Image.Image], zoom: int = 6) -> Image.Image:
    bg = rgba("N1")
    cell_w = max(i.width for i in images.values()) * zoom + 8
    cell_h = max(i.height for i in images.values()) * zoom + 8
    cols = max(1, min(len(images), 1600 // cell_w))
    rows = (len(images) + cols - 1) // cols
    out = Image.new("RGBA", (cols * cell_w, rows * cell_h), bg)
    for n, img in enumerate(images.values()):
        big = img.resize((img.width * zoom, img.height * zoom), Image.NEAREST)
        out.alpha_composite(big, ((n % cols) * cell_w + 4, (n // cols) * cell_h + 4))
    return out


def diff_mask(a: Image.Image, b: Image.Image) -> Image.Image:
    return ImageChops.difference(a.convert("RGBA"), b.convert("RGBA"))
