"""Ownership of art files (ART_SPEC §9.4): a generator may overwrite only what a generator wrote.

`assets/generated.json` maps asset id -> hash of the pixels a tool last wrote for it. A file whose
pixels no longer match its entry (or that has no entry) was drawn or edited by the designer: it is
locked, and no flag (`--only`, `--all`, `--force`) overwrites it. Nothing has to be declared when
the designer edits a file; the hash stops matching by itself.

    owned(id, path)   -> True when the file is missing or still equals what a tool wrote
    record(id, img)   -> remember the pixels just written
    python tools/art/classify.py           # who owns what
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "assets" / "generated.json"

_cache: dict[str, str] | None = None


def pixel_hash(img: Image.Image) -> str:
    """Hash of the visible pixels (the RGB of transparent pixels is ignored)."""
    img = img.convert("RGBA")
    data = bytearray(img.tobytes())
    for i in range(3, len(data), 4):
        if data[i] == 0:
            data[i - 3:i] = b"\0\0\0"
    return hashlib.sha1(b"%dx%d:" % img.size + bytes(data)).hexdigest()[:16]


def load() -> dict[str, str]:
    global _cache
    if _cache is None:
        _cache = json.loads(REGISTRY.read_text(encoding="utf-8"))["files"] if REGISTRY.exists() else {}
    return _cache


def save() -> None:
    doc = {"note": "tools/art_lock.py: pixels last written by a generator; anything else is the designer's",
           "files": dict(sorted(load().items()))}
    REGISTRY.write_text(json.dumps(doc, indent=1) + "\n", encoding="utf-8", newline="\n")


def owned(asset_id: str, path: Path) -> bool:
    """True when a tool may write this file: it is missing, or still what a tool wrote."""
    if not path.exists():
        return True
    want = load().get(asset_id)
    if want is None:
        return False
    with Image.open(path) as im:
        return pixel_hash(im) == want


def record(asset_id: str, img: Image.Image) -> None:
    load()[asset_id] = pixel_hash(img)
