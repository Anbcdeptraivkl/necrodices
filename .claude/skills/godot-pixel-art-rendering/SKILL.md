---
name: godot-pixel-art-rendering
description: Pixel-perfect 2D rendering in Godot 4 — low base resolution with integer upscaling, nearest filtering, texture and pixel-font import settings, sprite-sheet layout, atlas packing and batched drawing of animated sprites, sprite canvas vs visual body size, anchors, camera jitter, and mixing low-res world with high-res UI. Use when configuring project display/stretch settings, importing or adding sprites, tilesets, fonts or FX, setting up Camera2D, building HUD/UI over a pixel world, laying out sprite sheets or packing an atlas, drawing many animated sprites in one batch, choosing texture compression, or seeing blurry, shimmering, jittering, uneven-pixel or wrongly sized art.
---

# Godot Pixel-Art Rendering

Owns *how pixels reach the screen*. The concrete numbers (base resolution, sprite canvas
sizes, palette) belong to the project's art spec in `docs/`; this skill is how to make the
engine honour them.

## Rules

1. **Integer scale only.** The world renders at the base resolution (e.g. 960×540) and is
   scaled by a whole number (2× → 1080p, 4× → 2160p). Any fractional scale makes pixels
   uneven and shimmer when things move.
2. **Nearest filtering, no mipmaps** for pixel art. Set the project default texture filter to
   Nearest; do not generate mipmaps. (HD/vector art is the opposite case — linear + mipmaps —
   never mix the two rules on one texture.)
3. **Never scale a sprite by a non-integer factor** to show a bigger or smaller unit tier.
   Redraw at the target size, or use a separate sprite. Scaling pixel art invents mixed-size
   pixels.
4. **Canvas size ≠ visual size.** A sprite has a fixed canvas from the art spec (e.g.
   32×32) and a visual body inside it (head, torso, limbs). Weapons and decor overflow into
   the rest of the canvas and do not count as body. Code and collision use the *core*
   footprint from the spec (a small box at the feet), never the texture size.
5. **Anchor by pivot, per frame.** Every frame carries a pivot: the canvas pixel placed on
   the unit's position (usually the feet). Default to bottom-centre, but let sprite sheets
   override it per unit and per animation frame (a lunge, a wide monster, a death frame);
   flips mirror about the pivot. Code never assumes the canvas centre or a fixed offset, so
   y-sorting, selection circles and shadows stay aligned across sizes and animations.
6. **Positions of pixel art land on whole pixels** at the base resolution when at rest.
   Simulation may use floats; the view rounds when drawing.
7. **Every new asset goes through the import rule**, because a new file arrives with engine
   defaults. Keep an import preset / checker and run it.

## Project settings (Godot 4.x) — pure pixel-art setup

| Setting | Value | Why |
| --- | --- | --- |
| `display/window/size/viewport_width` × `viewport_height` | base res (e.g. 960 × 540) | design canvas |
| `display/window/size/window_width_override` × `…height_override` | a multiple (e.g. 1920 × 1080) | sensible default window |
| `display/window/stretch/mode` | `viewport` | renders at base res, then scales — truly pixel-perfect |
| `display/window/stretch/aspect` | `keep` | for `expand` + integer scaling use the SubViewport setup below — the built-in combination is buggy (godotengine/godot#92055) |
| `display/window/stretch/scale_mode` | `integer` (Godot 4.2+) | no fractional scale; letterboxes the remainder |
| `rendering/textures/canvas_textures/default_texture_filter` | `Nearest` | see the enum-order trap below |
| `rendering/2d/snap/snap_2d_transforms_to_pixel` | `true` for a static-camera / strict look | removes sub-pixel sprite placement; can cause camera jitter — test |

Texture import (per file or via a preset): mipmaps **off**, compress mode **Lossless**,
`process/fix_alpha_border` on. Filter comes from the project default or the CanvasItem.

## Low-res world, high-res UI (hybrid)

`stretch/mode = viewport` makes *everything* low-res, including text. When the HUD needs
crisp text or smooth UI motion:

- Use `stretch/mode = canvas_items` with the high-res design size (e.g. 1920×1080) for the
  window, and render the **world** in a `SubViewport` at the base res (960×540), shown through
  a `SubViewportContainer` with `stretch = true` and `stretch_shrink = 2` (or a `TextureRect`
  scaled by an integer). UI lives outside the SubViewport at full res.
- Mouse → world coordinates must then go through the SubViewport transform; put that in one
  helper.
- Decide per project and write it in the art spec; do not mix approaches screen by screen.

**Fixed integer scale, expanding view** (for displays that are not a multiple of the base,
e.g. 960×540 on 1440p): pick `scale = max(1, floor(screen_height / base_height))`, size the
world SubViewport to `screen / scale`, and display it at `scale`. Players get more field of
view instead of black bars or blur; the design must stay fair across the view range. **In a window, take the scale from the monitor, not the window:** a maximised window is a
little shorter than the screen (title bar, taskbar), so `floor(window_h / base_h)` drops a
whole step (×2 → ×1 at 1080p) and the view quadruples. Keep the monitor's scale and let the
window crop the view; drop a step only when the crop passes a limit (e.g. 10% of the base
height). The
same mechanism gives **integer zoom levels** for free (e.g. a strategic/command view at ×1
where the normal view is ×2).

## Pixel fonts

Import a pixel font with antialiasing **off**, hinting **none**, subpixel positioning
**disabled**, system fallback **off** (a missing glyph must show, not silently come from a
smooth system font), and use it only at its design size or integer multiples. Put these in
`[importer_defaults] font_data_dynamic` so every new font imports right. Non-pixel UI fonts
belong in the high-res UI layer only. Pixel fonts often ship huge (CJK); subset to the
scripts the game ships (fontTools) and keep the licence next to the file.

**Pixel UI over a native-resolution window:** lay the HUD out in art pixels and scale the
HUD root Control by the same integer scale as the world (top-left anchored, `size = window /
scale`, `scale = (s, s)`), set its `texture_filter` to Nearest, and refit on window resize.
Text, borders and panels then land on the world's pixel grid; mouse input still works
through the Control transform.

### Pixel UI traps

| Trap | Symptom | Fix |
| --- | --- | --- |
| Replacing dialog buttons with only `queue_free()` | Keyboard choices use disabled or stale buttons from the previous dialog until the next frame | Detach old buttons from the container before queuing their deletion; build choice indexing from the current children |
| Scaled HUD inherits a Linear filter (e.g. inside a capture SubViewport) | Pixel font looks blurry at ×2 | Set `texture_filter = Nearest` on the HUD root itself |
| Resize signal connected in `_ready` of a node that re-enters the tree | `Signal ... is already connected` error on the second entry | Check `is_connected` first, or connect once in `_init` |
| Halving a native layout without checking long labels | Right-aligned help text overflows the window edge | Give long labels the full width to grow into; review a capture |
| Round widgets (cooldown discs, radial sweeps) drawn with `draw_circle` / `draw_arc` in the scaled HUD | Edges and the sweep are smooth at window resolution while the rest of the HUD is chunky art pixels | Compose the widget per pixel into an `Image` at art size and draw it as a texture; rebuild only when the shown step (sweep step, ready flash) changes |
| Game input polled with `Input.is_mouse_button_pressed` beside clickable HUD buttons | Clicking a HUD button also attacks / moves in the world | Skip pointer actions only while the hovered control is a button (`get_viewport().gui_get_hovered_control() is BaseButton`). Never test it against null: the scene's root Control and a `SubViewportContainer` world view stop the mouse by default, so something is always hovered and every click is swallowed |
| A pixel theme that sets only the font | Buttons read as plain text: the default button style is dark and borderless on a dark pixel UI, with no visible hover or press | Give Button its own styles in the shared theme (StyleBoxFlat, anti-aliasing off, whole-pixel borders: a thicker bottom lip, brighter on hover, pressed in by 1 px via top/bottom border and content margins, dimmed when disabled, empty focus); never per-button overrides |
| Debug status, seed and key help spread as text over the HUD | The playable HUD reads as a debug screen | One collapsible Debug drawer (button + hotkey, closed by default) holds them; the HUD shows icons and numbers |
| Godot's own `tooltip_text` in a scaled pixel HUD | Tooltips open as separate popups at window resolution: tiny smooth text, off the pixel grid | One tooltip panel inside the scaled HUD root that follows the mouse; controls carry their rows as a meta, and the panel finds its target by walking up from `get_viewport().gui_get_hovered_control()`, so several HUDs can coexist |
| Pixel tooltip driven by `mouse_entered` / `mouse_exited` | The tooltip blinks while moving across a grid (exit fires in every gap between slots), vanishes after a click that rebuilt the slot under a resting mouse (no enter fires), and jumps one frame at a stale size | Poll the hovered control each frame: open after a short rest (~0.2 s), switch content at once while open, close after a short grace (~0.15 s); size it from `get_combined_minimum_size()` and keep the first frame transparent (fade in); at the HUD's edges flip left / above so it never sits under the pointer |
| A screen rebuilt (children freed) from the click handler of one of its own buttons or slots | Errors or lost clicks: the control is freed while its input event is still being handled | Rebuild deferred (`refresh.call_deferred()`) from every handler that changes what the screen shows |
| HUD buttons or overlays added in code after the scene's full screens | The buttons draw over a modal screen's dim and panel | Insert them below the screens (`move_child`), or add the screens last |

## Camera

- Smooth camera movement over a pixel-snapped world shows jitter. Options, in order of
  simplicity: move the camera in whole base-res pixels; or render the world one pixel larger
  in a SubViewport and apply the sub-pixel remainder as an offset when displaying it (smooth
  pixel camera).
- Zoom only by integer factors on the world, or accept softness when zoomed out and say so
  in the art spec.

## Routing

- Sprite-sheet layout (rows, frame order, pivots, manifests), atlas packing and padding,
  texture import and memory, drawing animated crowds through one batch →
  [references/sprite-sheets.md](references/sprite-sheets.md)

## Checklist — adding art

1. Canvas size, body size and anchor match the art spec for its class (tiny / normal / large /
   elite / hero / monster / boss).
2. Colour count and outline follow the spec (e.g. 1 px outer outline, ~4–7 colours per
   normal soldier); faction/team colour via palette swap shader or indexed colours, not
   hand-duplicated sheets.
3. Import settings pass the checker (mipmaps off, lossless).
4. Look at it in-game at 1× and 2× with a nearest-neighbour zoomed screenshot.

## Traps

| Trap | Symptom | Fix |
| --- | --- | --- |
| `default_texture_filter` enum order ≠ `CanvasItem.TextureFilter` | Filter "set" but wrong | Project setting order is `0 Nearest, 1 Linear, 2 Linear Mipmap, 3 Nearest Mipmap`; confirm via the setting's `hint_string` |
| Fractional window / scale | Uneven pixel widths, shimmer on motion | `scale_mode = integer`, or fullscreen at an integer multiple |
| `aspect = expand` + `scale_mode = integer` | View jumps, expands in one direction only, black borders appear inconsistently on resize (godotengine/godot#92055, open as of 2026-10) | Whole screen pixel art: aspect `keep` + `integer` and set `Window.content_scale_size` per resize (`godot-mobile-pixel-ui`). Pixel world + native UI: world SubViewport sized `screen / scale` (see *Fixed integer scale, expanding view*) |
| New texture with default import | One asset blurry or different | Run the import checker; set a default preset for the folder |
| Tier scaling of sprites (0.6×, 0.8×) | Mixed pixel sizes on one unit | Redraw per tier |
| Rotating pixel sprites freely | Chewed edges | Pre-drawn directional frames (4/8 dirs); rotate only FX/projectiles |
| `MultiMeshInstance2D` fed through `multimesh.buffer` | A batch with few sprites (FX, smears) is invisible on most frames and appears only when other sprites happen to sit inside its stale bounds | The canvas culls by bounds that buffer writes do not refresh: give every world-spanning batch a custom rect (`RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, world_rect)`) |
| Screenshot looks blurry | Blur in the capture, not the game | Capture from a SubViewport; inspect with nearest zoom (`godot-debugging-testing`) |
| A palette-swap shader for a handful of key-coloured sprites (two-element hybrids) | A material per sprite, batching lost, and UI icons need the same swap | Swap on the CPU once per colour combination (`Image` → `ImageTexture`), cache it, use it everywhere |
