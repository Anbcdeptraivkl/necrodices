"""Who owns each art file: the designer (locked) or a generator (ART_SPEC §9.4).

    python tools/art/classify.py                  # summary per category + the pending list
    python tools/art/classify.py --list           # every file with its state
    python tools/art/classify.py --dump frost_wraith   # a file as a palette-key grid (style study)
    python tools/art/classify.py --seed           # first run only: register generator-written files

States:
  designer   pixels are not what a generator last wrote (tools/art_lock.py): never overwritten
  generator  generator-owned and equal to today's recipe
  pending    generator-owned, but the recipe has changed: `--only <id>` would rewrite it
  no-recipe  generator-owned placeholder that no tools/art module draws yet

`--seed` registers the files that equal their recipe, plus the scaffold UI placeholders named in
SCAFFOLD (written once by tools/gen_placeholders.py, never edited since). Everything else stays
unregistered, which means designer-owned. Run it only on a tree where no recipe is ahead of its file.
"""

from __future__ import annotations

import importlib
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelgrid as pg  # noqa: E402
import art_lock  # noqa: E402
from palette import HALLOW32, MASK_KEYS, hex_to_rgb  # noqa: E402

MODULES = ["backgrounds", "dice_runes", "enemies_dice", "howto", "icons", "items", "legends", "scenery",
           "ui_buttons", "ui_kit", "units"]
SCAFFOLD = ["btn_primary_normal", "btn_primary_pressed", "btn_primary_disabled", "btn_secondary_normal",
            "btn_secondary_pressed", "btn_secondary_disabled", "panel_dark", "panel_card", "panel_tooltip",
            "chip", "slot", "slot_selected", "hp_frame", "hp_fill", "hp_preview", "power_box", "count_box",
            "rarity_stripe_common", "rarity_stripe_uncommon", "rarity_stripe_rare", "divider"]


def recipes() -> dict:
    out: dict = {}
    for name in MODULES:
        try:
            out.update(getattr(importlib.import_module(name), "ASSETS", {}))
        except ModuleNotFoundError:
            pass
    return out


def classify() -> dict[str, str]:
    entries, rec, states = pg.manifest_entries(), recipes(), {}
    for aid, e in entries.items():
        path = pg.ROOT / e["path"]
        if not art_lock.owned(aid, path):
            states[aid] = "designer"
        elif aid not in rec:
            states[aid] = "no-recipe"
        elif path.exists() and pg._same(Image.open(path), rec[aid]()):
            states[aid] = "generator"
        else:
            states[aid] = "pending"
    return states


def seed() -> int:
    entries, rec, n = pg.manifest_entries(), recipes(), 0
    for aid, e in entries.items():
        path = pg.ROOT / e["path"]
        if not path.exists():
            continue
        img = Image.open(path)
        if aid in SCAFFOLD or (aid in rec and pg._same(img, rec[aid]())):
            art_lock.record(aid, img)
            n += 1
    art_lock.save()
    print(f"registered {n} generator-written files in {art_lock.REGISTRY.relative_to(pg.ROOT).as_posix()}")
    return 0


def dump(aid: str) -> int:
    e = pg.manifest_entries()[aid]
    keys = {hex_to_rgb(h): k for k, h in {**HALLOW32, **MASK_KEYS}.items()}
    img = Image.open(pg.ROOT / e["path"]).convert("RGBA")
    for f in range(e["frames"]):
        print(f"{aid} frame {f} ({e['frame_w']}x{e['h']})")
        for y in range(e["h"]):
            row = (img.getpixel((f * e["frame_w"] + x, y)) for x in range(e["frame_w"]))
            print(" ".join(keys.get(p[:3], "??") if p[3] else ".." for p in row))
    return 0


def main(argv: list[str]) -> int:
    if "--seed" in argv:
        return seed()
    if "--dump" in argv:
        return dump(argv[argv.index("--dump") + 1])
    entries, states = pg.manifest_entries(), classify()
    if "--list" in argv:
        for aid, s in states.items():
            print(f"{s:10s} {entries[aid]['category']:16s} {aid}")
    counts = Counter((entries[a]["category"], s) for a, s in states.items())
    for cat in dict.fromkeys(e["category"] for e in entries.values()):
        print(f"{cat:16s} " + ", ".join(f"{s} {counts[(cat, s)]}" for s in ("designer", "generator", "pending", "no-recipe")
                                         if counts[(cat, s)]))
    total = Counter(states.values())
    print("total: " + ", ".join(f"{s} {n}" for s, n in total.items()))
    pending = [a for a, s in states.items() if s == "pending"]
    if pending:
        print("pending (recipe ahead of the file): " + " ".join(pending))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
