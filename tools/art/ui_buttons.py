"""Button hover states (ART_SPEC §7): derived from the normal 9-slices on disk, so a
hand-edited normal button carries its edits into hover.

    python tools/art/ui_buttons.py --only "btn_*_hover"   # rebuild after editing a normal button

Hover = the same button one ramp step lighter (fill and top highlight); outline and bottom
shadow stay, so the lip still reads.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelgrid import ROOT, recolor, run  # noqa: E402

UI = ROOT / "assets" / "ui"
# normal colour -> hover colour (palette keys)
HOVER = {
    "btn_primary_hover": ("btn_primary_normal", {"F1": "F2", "F2": "V2"}),
    "btn_secondary_hover": ("btn_secondary_normal", {"N4": "N5", "N5": "N6"}),
}


def hover(asset_id: str):
    def draw() -> Image.Image:
        src, mapping = HOVER[asset_id]
        return recolor(Image.open(UI / f"{src}.png").convert("RGBA"), mapping)
    return draw


ASSETS = {i: hover(i) for i in HOVER}

if __name__ == "__main__":
    sys.exit(run(ASSETS, sys.argv[1:]))
