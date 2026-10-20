# Terrain: autotiles first, mask blending as a fallback

## Autotiles (preferred when tile art exists)

Format (RPG Maker XP-style "A" tiles, WolfRPG, Pipoya): one column of 5 cells per material,
each cell made of four 16×16 quarters — row 0 isolated (outer corners on all sides), row 1
vertical band (edges left and right), row 2 horizontal band (edges top and bottom), row 3
inner corners, row 4 full.

For each cell of material M and each quarter towards diagonal d = (±1, ±1):
- h = neighbour (d.x, 0) is M; v = neighbour (0, d.y) is M; g = neighbour d is M.
- h and v and g → full; h and v → inner corner; h only → horizontal band; v only →
  vertical band; neither → isolated. Take that row's quarter on the d side.
- Off-map neighbours count as M (no shore at the border).

Bake: the base material (lawn) everywhere, then each non-base cell's four quarters with alpha
blending (autotile edges are often transparent or carry their own border, e.g. a shore).
Only same-material neighbours join; order does not matter because each cell draws inside
itself. One texture per map, native blits only.

Importing a set: slice the autotiles and objects, re-colour them into the palette (classes by
hue — grass, water, soil, stone, roof — brightness within a class → ramp level, ranges shared
across every image that must match), write the sheets plus a NOTICE with the licence.

## Mask blending (when no autotile art exists)

Goal: a grid of materials that reads as continuous ground, without drawing an autotile set
per pair of terrains.

## Inputs

- A material per cell (from the map), a cell size (e.g. 32 px overworld, 16 px battle).
- Per material: 3–4 seamless 16×16 tile variants, and a **priority**.
- Masks: for a cell size S and bleed B (≈ 20–25% of S), 256 masks indexed by the 8-neighbour
  bitmask (E, W, S, N, SE, SW, NE, NW). A pixel is on when it is within B (+ noise) of an
  edge whose neighbour bit is set, or within ~1.2 B of a corner whose diagonal bit is set and
  whose two adjacent edge bits are not. Noise is chunky (2 px) and dithered so the edge looks
  hand-drawn. Build masks lazily and cache them.

## Bake

1. **Macro tiles**: per material, lay its variants into a 128×128 image by a seeded shuffle.
   Sampling at `(x mod 128, y mod 128)` gives continuous texture across cells.
2. For every cell: blit the macro region of its own material.
3. For every cell: for each *distinct* neighbouring material with higher priority, build the
   8-bit mask of where that material is around the cell and `blit_rect_mask` its macro
   region through the mask. Lower priority never bleeds into higher.
4. Special passes before step 3 where a transition needs a third material (e.g. shallows
   between land and deep water: water cells next to land get the shallow material with a
   wider mask).
5. Upload once as an `ImageTexture` on a `Sprite2D` (nearest filtering). Lines on top (rivers,
   roads) and markers are separate layers.

## Priorities (a common order, low → high)

deep water < shallow water < marsh < sand < mud < dirt < grass < snow < forest floor < hills <
canopy < rock. Land bleeds over water (organic coasts); forest and rock bleed over open ground.

## Cost

Native `Image.blit_rect` / `blit_rect_mask` per cell: a 100×100 map is ~10 000 base blits plus
a few thousand masked ones — well under a second. The pixel loop in script is only for
generating tiles and masks, which are small and cached.
