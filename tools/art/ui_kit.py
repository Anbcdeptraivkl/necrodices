"""UI kit 9-slices built on the designer's die body (ART_SPEC §7).

    python tools/art/ui_kit.py --preview captures/ui_kit_preview.png
    python tools/art/ui_kit.py --only "btn_*" --propose art_source/proposals/ui

The pattern, measured on `die_body.png`: a 1 px N0 outline with 2 px chamfered corners, one flat
face tone, a 2 px glint in the top-left corner and a darker lip at the bottom (the slab stands on
it). Three constructions cover the kit:

  slab    raised: face + lip (+ glint). A pressed button is the slab sunk by the height of its lip.
  frame   a 1 px ring inside the outline around a floor (panels, chips, tooltips), after the
          inset ring of `die_body_iron.png`.
  socket  sunken: a shaded row under the top edge, a lit rim row at the bottom (empty slots).

Hover and danger states are derived from the buttons by `ui_buttons.py`.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelgrid as pg  # noqa: E402

CHAMFER = 2
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
N8 = N4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))


def shape(w: int, h: int, top: int = 0, chamfer: int = CHAMFER) -> set[tuple[int, int]]:
    """Pixels of a w×h box whose corners are cut by `chamfer` px, starting at row `top`."""
    out = set()
    for y in range(top, h):
        i = max(0, chamfer - (y - top), chamfer - (h - 1 - y))
        out.update((x, y) for x in range(i, w - i))
    return out


def edge(pixels: set[tuple[int, int]], near: set[tuple[int, int]] | None = None,
         around=N4) -> set[tuple[int, int]]:
    """Pixels of `pixels` that touch something outside it (or, with `near`, that touch `near`)."""
    if near is None:
        return {(x, y) for x, y in pixels if any((x + dx, y + dy) not in pixels for dx, dy in around)}
    return {(x, y) for x, y in pixels if any((x + dx, y + dy) in near for dx, dy in around)}


def _paint(w: int, h: int, layers: list[tuple[set[tuple[int, int]], str]]):
    img = pg.canvas(w, h)
    px = img.load()
    for pixels, key in layers:
        col = pg.rgba(key)
        for x, y in pixels:
            px[x, y] = col
    return img


def slab(w: int, h: int, face: str, lip: str, glint: str | None = None, lip_rows: int = 2, sink: int = 0,
         chamfer: int = CHAMFER):
    """Raised slab: flat `face`, `lip_rows` rows of `lip` at the bottom, optional corner glint.
    `sink` leaves that many transparent rows on top (a pressed slab: pass lip_rows=0)."""
    body = shape(w, h, sink, chamfer)
    outline = edge(body)
    inner = body - outline
    layers = [(outline, "N0"), (inner, face), ({p for p in inner if p[1] >= h - 1 - lip_rows}, lip)]
    if glint:
        layers.append(({(chamfer, sink + 1), (chamfer - 1, sink + 2)}, glint))
    return _paint(w, h, layers)


def frame(w: int, h: int, ring: str, floor: str | None, lip: str | None = None, chamfer: int = CHAMFER):
    """A 1 px `ring` inside the N0 outline around a `floor` (None = see-through centre).
    `lip` adds one darker row under the bottom ring row."""
    body = shape(w, h, 0, chamfer)
    outline = edge(body)
    inner = body - outline
    band = edge(inner, outline, N8)
    layers = [(outline, "N0"), (band, ring)]
    if floor:
        layers.insert(1, (inner, floor))
    if lip:
        rest = inner - band
        layers.append(({p for p in rest if (p[0], p[1] + 1) in band}, lip))
    return _paint(w, h, layers)


def ring(w: int, h: int, key: str, chamfer: int = CHAMFER):
    """Only the outline path, in `key`: laid over a slab or socket to mark it (selection)."""
    return _paint(w, h, [(edge(shape(w, h, 0, chamfer)), key)])


def socket(w: int, h: int, floor: str, shade: str, rim: str):
    """Sunken tray: the slab inverted — a shaded row under the top edge, a lit rim row at the bottom."""
    body = shape(w, h)
    outline = edge(body)
    inner = body - outline
    return _paint(w, h, [(outline, "N0"), (inner, floor),
                         ({p for p in inner if p[1] == 1}, shade), ({p for p in inner if p[1] == h - 2}, rim)])


ASSETS = {
    # buttons: orange CTA, purple secondary; disabled is the same dark slab for every family
    "btn_primary_normal": lambda: slab(24, 24, "F1", "F0", "F2"),
    "btn_primary_pressed": lambda: slab(24, 24, "F1", "F0", lip_rows=0, sink=2),
    "btn_primary_disabled": lambda: slab(24, 24, "N2", "N1"),
    "btn_secondary_normal": lambda: slab(24, 24, "N4", "N2", "N5"),
    "btn_secondary_pressed": lambda: slab(24, 24, "N4", "N2", lip_rows=0, sink=2),
    "btn_secondary_disabled": lambda: slab(24, 24, "N2", "N1"),
    # panels
    "panel_dark": lambda: frame(24, 24, "N3", "N1"),
    "panel_card": lambda: slab(24, 24, "N2", "N1", "N3"),
    "panel_tray": lambda: frame(24, 24, "N2", "N0"),
    "panel_tooltip": lambda: frame(16, 16, "N5", "N0"),
    "chip": lambda: frame(16, 12, "N5", "N3"),
    # slots and marks
    "slot": lambda: socket(20, 20, "N2", "N1", "N3"),
    "slot_selected": lambda: frame(20, 20, "G1", "N2"),
    "frame_select": lambda: ring(16, 16, "G1"),
    # battle HUD
    "hp_frame": lambda: slab(16, 7, "N2", "N2", lip_rows=0),
    "power_box": lambda: slab(16, 14, "I1", "I0", "I2", lip_rows=1),
    "count_box": lambda: slab(16, 14, "R1", "R0", "S1", lip_rows=1),
}


if __name__ == "__main__":
    sys.exit(pg.run(ASSETS, sys.argv[1:]))
