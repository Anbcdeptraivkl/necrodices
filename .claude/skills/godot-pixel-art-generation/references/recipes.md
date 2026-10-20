# Recipes

## Palette as ramps

A ramp is 4 colours: `dark`, `mid`, `light`, `accent` (a highlight or a contrasting detail).
- Ground ramps: saturation ~0.2–0.45, value ~0.3–0.75; the step between dark and light is
  modest so ground patterns stay texture, not noise.
- Actor ramps: higher saturation for the parts that must read (cloth, team marks); keep
  skin/bone/metal neutral.
- Outline: one near-black with a hue tint (e.g. dark purple-brown), shared by all actors.
- Hue shifting: shadows lean cool (towards blue/purple), highlights warm (towards yellow).
  It keeps muted colours from looking grey.

## Painting helpers (on an `Image`)

- `put(x, y, c, wrap)` — the only way to write a pixel; wraps when the target tiles.
- Discs and ellipses by the `x² + y² <= r²` test; shade the top-left part with `light`,
  the bottom-right with `dark`.
- Outline pass: for every transparent pixel next to (4-neighbourhood) an opaque one, write
  the outline colour. Run it last, on actors and icons only.
- Ordered dithering (2×2 or 4×4 Bayer) for gradients and blend edges; threshold on
  noise + position so edges look hand-placed, not straight.

## Tiles (16×16, seamless)

- Base fill with `mid`, then sparse marks: 1–2 px specks (`dark`, `light`), 2–3 px strokes
  (grass blades), small blobs (pebbles, leaves), all wrapped.
- Density sets the look: grass ~10–14 marks, sand ~6–8 dots and a ripple dash, snow few
  and faint, water 2–3 short light glints.
- Canopy (forest seen from above): 2–3 overlapping crowns (r 3–5), light top-left,
  dark bottom-right, gaps show `dark` floor.

## Icons and props (32×32)

- Feet / base on the bottom rows (pivot bottom-centre), body within ~20×24.
- Characters: see [chibi-characters.md](chibi-characters.md).
- Buildings: a roof shape carries the tier (hut → house → walled town → towers → keep).
- Props: trees 32×32 (trunk 2–3 px, crown r 8–11), rocks 16×16, bushes and reeds 16×16.
- Always test the silhouette: fill it with one colour; if the thing is not recognisable,
  change the shape, not the detail.
