"""How-to-Play images (ART_SPEC §11: howto_1..4, 200×120, "captured from game in M6").

    tools\\screenshot.cmd encounter captures/s_encounter.png
    tools\\screenshot.cmd combat captures/s_combat.png
    tools\\screenshot.cmd shop captures/s_shop.png
    python tools/art/howto.py            # crops, snaps every pixel to Hallow32, writes howto_*.png

The captures are 480×270 viewport images; each page crops one region and maps colours to the
nearest Hallow32 entry (the dim layer and faded pips are the only off-palette pixels).
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelgrid  # noqa: E402
from pixelgrid import ROOT, run  # noqa: E402
from palette import HALLOW32, hex_to_rgb  # noqa: E402

CAPTURES = ROOT / "captures"
PALETTE = [hex_to_rgb(v) for v in HALLOW32.values()]
# page -> (capture file, crop box x, y in the 480×270 capture)
PAGES = {
    "howto_1": ("s_encounter.png", (140, 150)),   # dice tray + army: roll, select, bind
    "howto_2": ("s_encounter.png", (280, 150)),   # right column: groups, hint, actions
    "howto_3": ("s_combat.png", (140, 140)),      # battlefield tally during playback: P × C
    "howto_4": ("s_shop.png", (128, 26)),         # Crypt Market cards
}


def _nearest(c: tuple[int, int, int]) -> tuple[int, int, int]:
    return min(PALETTE, key=lambda p: (p[0] - c[0]) ** 2 + (p[1] - c[1]) ** 2 + (p[2] - c[2]) ** 2)


def page(name: str):
    def draw() -> Image.Image:
        file, (x, y) = PAGES[name]
        src = Image.open(CAPTURES / file).convert("RGB").crop((x, y, x + 200, y + 120))
        cache: dict = {}
        out = Image.new("RGBA", src.size)
        px = out.load()
        for j in range(src.height):
            for i in range(src.width):
                c = src.getpixel((i, j))
                if c not in cache:
                    cache[c] = _nearest(c)
                px[i, j] = (*cache[c], 255)
        return out
    return draw


ASSETS = {name: page(name) for name in PAGES}

if __name__ == "__main__":
    sys.exit(run(ASSETS, sys.argv[1:]))
