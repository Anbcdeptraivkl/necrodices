# Sprite sheets, atlas packing, textures and batched rendering

How animated pixel sprites are laid out, packed, imported and drawn when hundreds share the
screen. Making the frames is `godot-pixel-art-generation` (references/animation.md); pooling
and render tiers for a playback horde are `godot-presentation-playback`.

## Sheet layout

- **Fixed cells, one row per unit (or per direction), frames in a fixed order** (e.g. idle 0–1,
  walk 0–3, windup, swing in-betweens, contact, recover). A frame is addressed by (row,
  index), so code and data never hold per-frame rectangles by hand. Manifests next to the
  sheet — ids in row order, frame names in column order — let every cell follow its id and
  frame when rows or frames are added, removed or reordered; without them, inserting one
  frame shifts (or regenerates) every reviewed cell after it.
- **Every frame keeps the tier's canvas** (32×32 for a normal unit, 64×64 for a smear cell). Do
  not trim transparent space at this size: trimming saves little memory and forces per-frame
  offsets; fixed cells keep one pivot per row.
- **Pivot per row, override per frame** only where a frame anchors elsewhere (a lying corpse,
  a wide lunge). Store it in the frame table, never as an offset in code.
- **FX sheets are centred on the attacker,** sized to the largest frame, one row per direction;
  the pivot per direction may sit off the cell centre (e.g. a smear's spawn gap beyond the
  weapon), which keeps placement out of the art and out of code.
- **Separate approved from prototype art:** sheets under review live in their own folder that
  the game does not load; approval moves the file. Nobody mistakes a prototype for final art.

## Packing an atlas

- **Production: pack offline** (a tool writes one PNG plus a frame table) and load it as an
  imported texture. Runtime packing from loose images (`Image.blit_rect` into a new image) is
  fine for tests and mock-ups but costs load time and skips the import pipeline.
- **One atlas per batch.** Everything that must y-sort together (units, heroes, standing props,
  smears drawn among them) goes into the same atlas so one `MultiMeshInstance2D` draws it in
  one call. A second atlas means a second batch that cannot interleave with the first.
- **Padding:** leave 1 px of transparent space between sprite cells, because a quad at a
  sub-pixel position can sample its neighbour. Tiles that sit edge to edge need the opposite —
  extrude (repeat) their edge pixels — since a transparent gap shows as a seam.
- **Size:** keep an atlas ≤ 4096×4096 for broad GPU support; non-power-of-two sizes are fine in
  Godot 4. Budget in plain numbers: RGBA8 costs `w × h × 4` bytes, so 30 unit types × 16 frames
  of 32×32 is under 2 MB. At this resolution texture memory is never the bottleneck; draw
  calls, per-sprite CPU work and sorting are.

## Import and texture settings

| Setting | Value | Why |
| --- | --- | --- |
| Compress mode | **Lossless** | VRAM compression (S3TC / BPTC / ETC2 / ASTC) is block-based and lossy: it shifts colours, so palette-swap keys (team colour, flash) stop matching and outlines get fringes |
| Mipmaps | off | Integer scales never minify; mipmaps blur when the view zooms out |
| Filter | Nearest (project default or the batch's CanvasItem) | Pixel art |
| Repeat | off for sprite atlases | Repeat makes edge texels wrap into the opposite side |
| `process/fix_alpha_border` | on | Gives transparent texels a neighbour's colour, so any filtering never pulls in black |

A test that reads every `.import` in the art folders and checks these keeps new files honest;
folders the engine must not import (source files, captures) get a `.gdignore`.

## Drawing many animated sprites

- **Animation is a frame index, not a node.** The view picks each unit's frame from sim state
  and writes it into the batch's per-instance data (UV rect or frame id in custom data);
  `AnimatedSprite2D` / `SpriteFrames` are for a handful of sprites (UI, menus), never for
  crowds.
- **Look atlas data up once per frame id** (canvas, pivot, UV), not once per sprite.
- **Fill the MultiMesh buffer as one packed float array** and assign it once per tick (2D layout: 8 transform floats
  `[x.x, y.x, 0, origin.x, x.y, y.y, 0, origin.y]`, then 4 colour, then 4 custom); per-instance
  setters cost microseconds each in GDScript.
- **Flip and team colour per instance:** a flip flag mirrors the quad about the pivot; the team
  colour replaces a key colour in the shader, so one sheet serves every side.
- **FX that are hit areas (slash smears) use the same batch path** as units when they must
  y-sort among them, or a layer above units when they must always be seen; either way they
  come from sim events, pooled, capped per frame.
- **Animation LOD:** at a zoomed-out command view, drop walk to 2 frames or update far units
  every other tick if the frame budget is missed — measure first.

## Traps

| Trap | Symptom | Fix |
| --- | --- | --- |
| VRAM-compressed sprite sheet | Team colours fail to swap, colour fringes on outlines | Lossless import for every sprite sheet |
| Sprites from two atlases that must overlap | Heroes or FX always draw above or below the crowd | One atlas per y-sorted batch |
| No padding between packed cells | A neighbour's pixels flicker on a sprite's edge when the camera moves | 1 px transparent gap (extrude for tiles) |
| Trimmed frames without per-frame offsets | The sprite jitters as it animates | Fixed cells, or store an offset with each trimmed frame |
| One node per animated soldier | Frame time collapses past a few hundred units | Frame index in a batched MultiMesh |
| Fading an opaque batched sprite (afterimage, ghost) by lowering its brightness | It turns into a black silhouette instead of disappearing | Batched sprites have no alpha: keep the brightness and blink it out (skip it on alternate frames), or draw fading things in a layer that blends |
| Prototype and approved art in one folder | A test asset ships, or approved art is regenerated by mistake | Separate folders; approval moves the file |
