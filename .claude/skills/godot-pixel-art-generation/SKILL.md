---
name: godot-pixel-art-generation
description: Producing pixel art for a Godot 4 game in code — importing and re-colouring a free tileset into the project palette, autotile terrain (RPG Maker / WolfRPG quarter tiles) or mask blending when no tileset exists, chibi characters and their animation frames from hand-placed part grids, slash smears, icons at exact canvas sizes, targeted regeneration that never overwrites approved or hand-edited cells, muted ground vs loud actors, outlines and auras, and editable PNG sheets with a catalogue. Use when creating or changing placeholder, procedural or imported art (tiles, terrain, icons, tokens, props, map markers, characters), when terrain shows hard seams or looks crude, when characters look crude, flat-front or hold floating weapons, when planning or generating unit animation frames (walk, idle, attack) or slash smears / hit-area FX, when running an art generation tool or the designer hand-edits a generated sheet, when colours clash or actors do not stand out, or when adding an asset sheet.
---

# Pixel Art Generation

Owns *making pixel art with code*: placeholder or procedural tiles, icons and props that
follow the art spec until (or instead of) hand-drawn art. How pixels reach the screen
(scale, filtering, import) is `godot-pixel-art-rendering`. The project doc names the palette, canvas sizes and tile sizes.

> Status: **draft** — the rules are standard pixel-art practice; palettes and patterns are
> starting guesses to tune by eye on captures.

## Rules

1. **Exact canvas sizes.** Sprites, icons and props on a 32×32 canvas (or the spec's tier),
   tiles 16×16. Never scale generated art to fit; generate at the size it is shown.
2. **One palette, as ramps.** Every colour comes from a named ramp (dark → mid → light →
   accent) in one palette file; generators pick ramp indices, never raw colours. This keeps
   the whole map coherent and lets the palette be re-tuned in one place.
3. **Value hierarchy: the ground is quiet, actors are loud.** Ground and terrain use muted
   ramps (low saturation, narrow value range, no pure black/white); tokens, units, UI marks
   and outlines use the saturated colours and the darkest outline. If a terrain colour is
   near a team/marker colour, the terrain is wrong.
4. **Seamless by construction.** Tileable textures place every mark with coordinates wrapped
   modulo the tile size, and noise is periodic (lattice noise whose grid wraps). A seam test
   compares opposite edges.
5. **Reference quality before generating it.** For common art (world-map terrain, trees,
   houses, castles), start from a free, licence-checked tileset and **re-colour it into the
   palette** (class pixels by hue, map brightness within the class to the target ramp): the
   hand-drawn shading survives, the colours become yours. Generate only what no set covers.
   Draw terrain as **autotiles** (4 quarters per cell, each picked from its two edge
   neighbours and the diagonal) baked into one texture per map; fall back to mask blending
   only when no autotile art exists. Record the licence next to the imported files.
6. **Seeded and reproducible.** Each asset has its own seed derived from its id, so
   regenerating the sheet reproduces it exactly and one asset can change alone.
7. **Readable silhouettes first.** 1 px dark outline around actors and icons (not around
   ground) that encloses **every part**, including where parts overlap; 3–5 colours per icon;
   flat fills with at most one light column on the side the actor faces (props and terrain
   may keep a top-left light); a shape that reads at ×1 before any detail. **No drop shadow
   under an outlined sprite**: the outline already separates it from the ground. Auras in a
   key colour are 8-connected (round corners). Characters: squat chibi, featureless head
   with dash eyes, stubby limbs, the class prop gripped in a hand —
   [references/chibi-characters.md](references/chibi-characters.md).
8. **Generated art is an asset.** Write PNG sheets into the project's assets folder with a
   catalogue (id → cell in the sheet, pivot), through the normal import checks, so hand art
   can replace any entry without code changes.
9. **Hand-drawn cells can live outside the sheet too.** Per-id source files (a folder the
   engine does not import, e.g. with `.gdignore`) that the builder prefers over the recipe
   when that id is rebuilt. Painting straight into the sheet is equally safe under rule 11.
10. **Characters are hand-placed pixel grids, not primitives.** Author each body part as a
    row-string grid with a legend of (material slot, ramp index), compose parts back to
    front, and recolour by giving each unit its own ramp per slot. Discs, ellipses and lines
    give shapeless "programmer art"; grids give the pixel control an artist would have.
11. **Every generation run has a target; the sheet on disk is the truth.** The tool builds a
    candidate sheet in memory, then writes only the cells it was asked for (by id) and cells
    of ids new to the catalogue; every other cell is copied from the file on disk. A
    manifest next to each sheet (its ids in cell order) lets cells follow their id when the
    catalogue is reordered. Rebuilding everything needs an explicit flag (`--all`). Never
    write a sheet whose cells did not change (no byte churn in version control), and never
    "regenerate" to verify: test the recipe in memory instead. Generating art is done on
    request only; before running, confirm with the requester which ids and which sheet files
    will be written.
12. **Prototype art lives apart from approved art.** Sheets under review go to their own folder
    that the game does not load; approval moves the file to the approved folder. Generators may
    create prototype sheets freely (still on request), and must never touch approved cells
    while doing so: namespace the targets of sheets whose ids repeat other sheets' ids.

## Procedure — a new generated asset

1. Pick its canvas from the spec (sprite 32×32, tile 16×16) and its ramps from the palette.
2. Write the generator as a function of (seed, canvas) that draws with the palette helpers;
   wrap coordinates if it tiles.
3. Add it to the sheet catalogue (append; the manifest keeps old cells in place); run the
   tool naming only the new id; run the import test.
4. Look at it in context at ×1 and ×2 on a capture (never judge generated art alone).

For characters and other hand-placed grids, iterate before porting: a throwaway script
(Python + PIL is fine) that composes the grids and writes a ×8 / ×2 / ×1 preview **next to
the designer's reference art**; port the grids to the engine generator only once the preview
is right, then diff the engine output against the preview pixel for pixel.

## Routing

- Palette ramps, shading, dithering, outlines, icon/prop recipes → [references/recipes.md](references/recipes.md)
- Chibi characters: proportions, three-quarter view, gripping tools, part grids, style
  checklist → [references/chibi-characters.md](references/chibi-characters.md)
- Animation frames for small units: frame budgets, walk / idle / attack scripts, the slash
  smear as the hit area, pivots, animating part grids and the approved art →
  [references/animation.md](references/animation.md)
- Sheet layout, atlas packing and texture settings for those frames → skill
  `godot-pixel-art-rendering`, references/sprite-sheets.md
- Terrain: autotiles (quarter selection), importing a tileset, mask blending fallback,
  coastlines → [references/terrain-blending.md](references/terrain-blending.md)

## Traps

| Trap | Symptom | Fix |
| --- | --- | --- |
| Marks drawn near a tile edge without wrapping | Visible grid of seams when the tile repeats | Wrap every write modulo the tile size |
| Non-periodic noise in a tile | Seams, even with wrapped marks | Lattice noise with a grid that wraps at the tile size |
| One variant per material | The same 16 px pattern repeats in a visible grid | 3–4 variants, arranged into a larger macro tile (e.g. 128 px) by a seeded shuffle |
| Saturated ground colours | Units, outlines and markers disappear into the terrain | Muted ground ramps; saturation reserved for actors and UI |
| Blending by alpha gradients | Soft, blurry edges that are not pixel art | Binary masks with dithered, noisy edges |
| Generating at runtime every launch | Slow start, art cannot be hand-edited | Generate PNG sheets once with a tool; the game loads them |
| Procedural primitives (rects, discs) for characters and buildings | Crude, shapeless, "programmer art" tokens | Import a reference set for world objects; draw characters as part grids (rule 10) and review at ×8 beside the reference |
| Characters drawn straight from the front | Flat, "paper doll" tokens that ignore the facing the game uses | Three-quarter view by placement: eyes shifted to the facing side, hair at the back, far hand and tool forward |
| Detailed faces and anatomy on a 32 px chibi (mouth, nose, pupils, feet, gradients) | Tall, busy, "uncute" tokens; designer redraws them | Squat head block, two 3 px eye dashes, stubby legs without feet, flat fills |
| 4-connected aura | Notched halo at every corner, unlike hand-drawn cells | Aura pass with 8 neighbours; the outline stays 4-connected |
| Designing a style from written notes when the designer drew a sample | Near misses, several review rounds | Rebuild the sample exactly with the part grids first (pixel diff), then derive the others |
| A weapon placed next to the hand instead of in it | Tools float at random angles | Draw the fist *over* the shaft with its own outline ring; shafts point up-forward and stay clear of the face |
| Drop shadow ellipse under an outlined token | Meaningless grey smudge, soft pixels break key-colour swaps | No shadow; the outline carries the silhouette |
| Animation frames built from the recipe while the designer hand-edited the tokens | Walking units lose the designer's edits (armour, shield shape) the moment they move | Carry the edits per part from the approved token (references/animation.md); test idle = approved |
| Hand edits found on a base part (standing legs) but not carried into its pose grids | An edited unit changes colour or shape when it moves | Map pose grids to the base part's geometry and carry the edits through the map; diff every frame against the reviewed sheet |
| Every attack in-between played at an even pace | Smooth but weightless swings, no force or inertia | Strike = windup → last in-between (1 beat) → farthest pose held 3–4 beats; in-betweens only on the recovery |
| Inserting a frame into a reviewed strip sheet | Every later cell shifts, or the merge rebuilds whole rows and the designer's touch-ups vanish | A frames manifest; merge cell by cell by (id, frame name); new frames are the only cells drawn |
| One walk stride (px per cycle) for every unit size | A small unit walks in jerks while bigger ones look smooth; its frames and its motion measure fine | Scale the stride to the body (frames should change ~10 times a second at walking speed); a 1 px bob is large on a small body — keep it, but check it at ×1 |
| Tall props (poles, plumes) bobbing with the body | The aura row at the canvas top is cut on the up frames | Keep them still on the walk (grounded shaft, lagging plume) |
| Hit-area FX centred on the attacker's feet | The zone hides under the attacker's own body; hits look unfair | The smear sits in front, clear of the body, and the sim tests that same shape |
| A generator that rewrites the whole sheet on every run | Approved or hand-painted cells silently overwritten; designer loses work | Targeted runs that merge with the sheet on disk (rule 11) |
| Comparing cells by raw bytes | Transparent pixels with different RGB report false differences | Compare only pixels where either side is visible |
| Re-colouring each imported image with its own brightness range | The same grass is a different green on every autotile; edges show seams | Compute class brightness ranges over all images that must match, then remap |
| Separate deep and shallow water materials whose autotiles only join their own kind | A grass bank appears between deep and shallow water | One water material (its autotile draws the shore), or make the two join as one family |
| `Image.blit_rect_mask(src, mask, rect, dst)` with a cell-sized mask on a bigger source | `Source image width is different from mask width`, nothing drawn | Mask and source must be the same size: cut (and cache) a cell-sized piece of the source first |
| Transition edges roughened only by per-pixel noise | Borders still read as straight cell lines, just fuzzy | Bulge each edge along a smooth curve (sum of sines with per-mask phases) and add a small ordered dither on top |
| Edge wobble that does not fade at the cell corners | Blend bands step in width where two cells meet | Multiply the wobble by `sin(π·t)` along the edge so it is zero at both ends |
| Mottle / patches in a tile too contrasted | The 16 px repeat reads as a grid over large areas (water) | Keep patch colours within ~30% of the mid tone; spread variety with variants, not contrast |
| A decor-rich battle map pushed into the unit batch every frame | Thousands of static sprites sorted and uploaded each frame | Bake flat decor into the ground; y-sort only standing props, and cull them to the camera view |
| Asset ids reused across folders in the manifest (a `coin` stat icon and a `coin` VFX sheet) | A generator keyed by id writes the wrong file or fails the size check | Make ids unique when building the manifest (prefix by category) and key every generator by id |
