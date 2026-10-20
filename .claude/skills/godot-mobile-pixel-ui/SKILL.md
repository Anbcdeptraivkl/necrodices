---
name: godot-mobile-pixel-ui
description: Pixel-art UI for web (itch.io) and mobile builds in Godot 4, portrait or landscape — low virtual resolution with integer scaling and canvas expansion for other aspect ratios, safe areas, minimum touch / click targets, tap / long-press as well as hover, tooltips and docked info panels that work without a mouse, drag-to-reorder slots, 9-slice panels and buttons, modal overlays, pixel fonts, containers instead of hand offsets, measuring layout from the running game, plus HTML5 / itch.io export and cold-start concerns. Use when building or editing any screen, HUD, overlay, button, slot, tooltip, drag interaction or .tscn layout, setting stretch / window / orientation settings, preparing a Web, itch.io or mobile export, or when a layout is misaligned, cramped, overflows on other aspect ratios, clicks or taps miss, tooltips need hover, text is blurry, or the build starts slowly.
---

# Mobile Pixel UI

Owns *screens a thumb can use on a pixel grid*. How sprites and fonts reach the screen at
integer scale is `godot-pixel-art-rendering`; what a screen may do in each game phase is
`godot-architecture` (FSM + legality); animations are `godot-presentation-playback`. The
project art spec names the virtual resolution, rects, palette and 9-slice margins.

## Rules

1. **Design in virtual pixels, scale by integers.** All rects in the art spec are virtual px;
   the root renders at that size and scales by a whole number (stretch `viewport`, aspect
   `keep`, scale `integer`, canvas size picked in code — see the first trap). Other aspect
   ratios get *extra virtual width or height*, given to one designated flexible region (e.g.
   the battlefield); bars and side columns anchored to the edges keep their rects.
2. **Touch targets ≥ the spec minimum** (typically 20×20 virtual at ×4 ≈ 80 physical px). A
   small icon gets an invisible larger hit area, not a bigger sprite. Keep the bottom strip
   (home indicator) free of buttons.
3. **No hover-only information.** Every tooltip opens on tap (or long-press when tap already
   acts) and closes on tap elsewhere; on desktop/web, hover may *also* open it. One tooltip
   panel inside the scaled UI root, positioned to stay on screen, never under the finger.
4. **Tap vs long-press vs drag are decided by one gesture helper**: movement threshold (a few
   virtual px) → drag; held time (~0.4 s) without movement → long-press; release before → tap.
   Each control asks the helper, so thresholds are consistent across screens.
5. **Containers own placement.** Two or more elements that line up are a container
   (`HBoxContainer`, `GridContainer`, `MarginContainer`) with `custom_minimum_size` and size
   flags; anchors/offsets are only for screen-level regions. Budget a container (sum of
   children's minimum sizes ≤ box) before adding to it — overflowing containers sort
   unpredictably.
6. **UI is authored in scenes and themed once.** Layout in `.tscn`, colours from the palette,
   9-slice `StyleBoxTexture` / `NinePatchRect` from the art kit in one `Theme`. Code fills data
   and toggles state; it does not create styled Controls with `X.new()`.
7. **Buttons reflect legality, they do not decide it.** `disabled` comes from the model's
   `can(verb)`; the command re-checks. Disabled look per art spec (no bevel, muted text).
8. **Modals are a stack.** Overlays (inspector, tooltip-with-actions, settings, confirm)
   push onto one overlay stack; Back / tap on the dim closes the top only. The dim layer
   blocks input to everything below.
9. **Measure, don't eyeball.** Verify layouts from the running scene (print rects, centres and
   overflow of named nodes), with real text in every label and at the smallest and tallest
   supported aspect.
10. **Boot light.** The main scene is a tiny preload-free boot scene that shows a frame, then
    loads the real scene; autoloads stay free of `preload` chains. Heavy compile at cold start
    blocks the first frame on mobile (team-kb f835d663).

## Procedure — a new screen

1. Copy its rects from the art spec into a scene built of regions (anchored) and containers.
2. Wire buttons to model commands and `can_*` queries; no game rules in the screen script.
3. Run it in a sandbox preset at the base and a tall aspect; measure rects; screenshot at ×1
   with nearest zoom.
4. Try every control by touch emulation (no hover): tap, long-press, drag where relevant.

## Routing

- Web/HTML5 and mobile export settings, input emulation, audio unlock, saves on web →
  [references/web-and-mobile-export.md](references/web-and-mobile-export.md)

## Traps

| Trap | Symptom | Fix |
| --- | --- | --- |
| `aspect = expand` + `scale_mode = integer` | View jumps / expands one way only / inconsistent bars on resize (godotengine/godot#92055, open as of 2026-10) | Aspect `keep` + `integer`, and set `get_window().content_scale_size` yourself on start and every `size_changed`: `scale = max(1, min(w / base_w, h / base_h))`, size `(clamp(w / scale, base_w, max_w), clamp(h / scale, base_h, max_h))`; anchor layouts to the canvas edges / centre. Pure fit function + table test; check with a probe scene at several `--resolution`s (verified on Godot 4.6.3) |
| Movie Maker (`--write-movie`) to check a resize | Every capture is the base size, whatever `--resolution` says | It records at the startup viewport size; print `get_viewport().get_visible_rect()` from a probe scene instead |
| Godot `tooltip_text` | Tiny smooth popup at window resolution; never shows on touch | One pixel tooltip panel in the scaled root, opened by the gesture helper |
| `mouse_entered` / `mouse_exited` for tooltips | Blinking across slot gaps; nothing on touch | Poll the hovered control (desktop) + tap/long-press (touch) |
| `visible = false` on a container child | Siblings reflow, grid indices shift | Hide the contents, keep the slot |
| `rotation` / `scale` on a Control | Rect and hit test lie | Pre-drawn rotated art (stamps), or transform an inner child |
| Screen rebuilt from its own button's `pressed` | Freed-while-handling errors, lost taps | `refresh.call_deferred()` |
| Drag reorder that mutates the model on every hover | Item order flickers; scorer previews jump | Reorder a view-side list during the drag; commit one `reorder(from, to)` command on drop |
| Empty labels while measuring | Elements look misaligned (1 px tall labels) | Fill real text before measuring |
| Font imported with antialiasing | Blurry text at ×3 | Pixel font import: no AA, no hinting, no subpixel, no fallback |
| One deferred `refresh()` per model `changed` signal | A burst of commands (a bot, an auto-play, a preview loop) queues thousands of rebuilds; frame stalls, even a crash | Coalesce: a `_refresh_queued` flag, one deferred refresh per frame |
