"""Validate every art file against assets/manifest.json (ART_SPEC §9.3). Exit 1 on any problem.

    python tools/validate_art.py

Checks:
  - every manifest file exists; no unexpected PNG under assets/ (ignores assets/fonts, *.import)
  - exact pixel size; width / frame_w is an integer equal to `frames`
  - mode RGBA, alpha in {0, 255}
  - every opaque pixel in Hallow32 (files flagged `mask`: mask key colours + #0d0a14 only;
    files flagged `tint` may also use pure white)
  - colour-count limits: units/legion 7, legends 12, minis 4, enemies/shopkeeper 12, icons 6, digits 3,
    backgrounds 16
  - 16x16 icons: 1 px transparent border
  - units (+ legion banner): lowest opaque pixel on row 15 in every frame; `floating` units:
    row 15 is a single N0 shadow run 4-6 px wide
  - legends, enemies (+ shopkeeper): lowest opaque pixel on row 31 in every frame
  - no fully transparent frames
  - palette files: hallow32.png is the palette strip (33x1) in palette order, hallow32.gpl exists
"""

from __future__ import annotations

import json
import sys

from PIL import Image

from palette import HALLOW32, HALLOW32_RGB, MASK_RGB, ROOT, TINT_WHITE, hex_to_rgb

MANIFEST = ROOT / "assets" / "manifest.json"
ASSETS = ROOT / "assets"
PALETTE_PNG = "assets/palette/hallow32.png"
PALETTE_GPL = ASSETS / "palette" / "hallow32.gpl"

COLOUR_LIMITS = {
    "unit": 7, "legion": 7, "legend": 12, "mini": 4, "enemy": 12, "shopkeeper": 12,
    "relic_icon": 6, "consumable_icon": 6, "coffer_icon": 6, "equipment_icon": 6, "stat_icon": 6, "num": 3,
    "bg": 16,
}
BORDER_ICONS = {"relic_icon", "consumable_icon", "coffer_icon", "equipment_icon"}
FEET_ROW = {"unit": 15, "legion": 15, "legend": 31, "enemy": 31, "shopkeeper": 31}
N0 = hex_to_rgb(HALLOW32["N0"])
WHITE = hex_to_rgb(TINT_WHITE)


def check_entry(e: dict) -> list[str]:
    path = ROOT / e["path"]
    if not path.exists():
        return ["missing"]
    probs: list[str] = []
    with Image.open(path) as im:
        im.load()
        mode = im.mode
        img = im.convert("RGBA")
    if mode != "RGBA":
        probs.append(f"mode {mode}, expected RGBA")
    w, h = img.size
    if (w, h) != (e["w"], e["h"]):
        probs.append(f"size {w}x{h}, expected {e['w']}x{e['h']}")
        return probs
    fw = e["frame_w"]
    if w % fw or w // fw != e["frames"]:
        probs.append(f"width {w} not {e['frames']} frames of {fw}")
        return probs

    px = img.load()
    flags = set(e.get("flags", []))
    allowed = MASK_RGB if "mask" in flags else HALLOW32_RGB
    if "tint" in flags:
        allowed = allowed | {WHITE}
    bad_alpha = 0
    bad_colours: set[tuple[int, int, int]] = set()
    colours: set[tuple[int, int, int]] = set()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a not in (0, 255):
                bad_alpha += 1
            if a == 0:
                continue
            c = (r, g, b)
            colours.add(c)
            if c not in allowed:
                bad_colours.add(c)
    if bad_alpha:
        probs.append(f"{bad_alpha} px with partial alpha")
    if bad_colours:
        sample = ", ".join("#%02x%02x%02x" % c for c in sorted(bad_colours)[:5])
        what = "mask key colours" if "mask" in flags else "Hallow32"
        probs.append(f"{len(bad_colours)} colour(s) not in {what}: {sample}")
    cat = e["category"]
    limit = COLOUR_LIMITS.get(cat)
    if limit and len(colours) > limit:
        probs.append(f"{len(colours)} colours > {limit} allowed for {cat}")

    if cat in BORDER_ICONS:
        border = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + \
                 [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
        if any(px[x, y][3] for x, y in border):
            probs.append("icon needs a 1 px transparent border")

    for f in range(e["frames"]):
        ox = f * fw
        rows = [y for y in range(h) if any(px[x, y][3] for x in range(ox, ox + fw))]
        if not rows:
            probs.append(f"frame {f} is fully transparent")
            continue
        want = FEET_ROW.get(cat)
        if want is not None and rows[-1] != want:
            probs.append(f"frame {f}: lowest opaque row {rows[-1]}, expected {want}")
        if "floating" in flags and cat == "unit":
            run = [x for x in range(ox, ox + fw) if px[x, 15][3]]
            contiguous = bool(run) and run[-1] - run[0] + 1 == len(run)
            all_n0 = all(px[x, 15][:3] == N0 for x in run)
            if not (4 <= len(run) <= 6 and contiguous and all_n0):
                probs.append(f"frame {f}: floating shadow row y=15 must be one N0 run of 4-6 px "
                             f"(got {len(run)} px, contiguous={contiguous}, N0={all_n0})")
    return probs


def check_palette() -> list[str]:
    probs = []
    if not PALETTE_GPL.exists():
        probs.append("assets/palette/hallow32.gpl: missing")
    p = ROOT / PALETTE_PNG
    if not p.exists():
        probs.append(f"{PALETTE_PNG}: missing")
        return probs
    with Image.open(p) as im:
        img = im.convert("RGBA")
    if img.size != (len(HALLOW32), 1):
        return [f"{PALETTE_PNG}: size {img.size}, expected {len(HALLOW32)}x1"]
    got = [img.getpixel((i, 0)) for i in range(len(HALLOW32))]
    want = [(*hex_to_rgb(v), 255) for v in HALLOW32.values()]
    if got != want:
        probs.append(f"{PALETTE_PNG}: does not match tools/palette.py")
    return probs


def main() -> int:
    if not MANIFEST.exists():
        print("assets/manifest.json missing - run tools/build_manifest.py")
        return 1
    entries = json.loads(MANIFEST.read_text(encoding="utf-8"))["files"]
    problems: list[str] = []
    for e in entries:
        problems += [f"{e['path']}: {p}" for p in check_entry(e)]
    problems += check_palette()

    expected = {e["path"] for e in entries} | {PALETTE_PNG}
    for p in sorted(ASSETS.rglob("*.png")):
        rel = p.relative_to(ROOT).as_posix()
        if rel.startswith("assets/fonts/"):
            continue
        if rel not in expected:
            problems.append(f"{rel}: unexpected file (not in manifest)")

    if problems:
        for p in problems:
            print(p)
        print(f"ART FAILED: {len(problems)} problem(s) in {len(entries)} manifest files")
        return 1
    print(f"ART OK ({len(entries)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
