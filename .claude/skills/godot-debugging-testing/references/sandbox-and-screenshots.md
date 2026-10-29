# Sandbox scenes and screenshots

## Debug sandbox

A dev-only scene (`scenes/debug/<x>_sandbox.tscn`) that boots straight into a stocked
situation — a battle with given armies, an overworld with given settlements, a UI screen with
given data — so it can be inspected without playing to it. Nothing in the shipped game
references it.

- **Presets are data rows**, not branches: a scenarios table (`scripts/debug/sandbox_scenarios.gd`
  or a `.tres`/JSON) where each row names the setup. The sandbox builds exactly what the row
  says — no extra decoration, so a "test board" is trustworthy.
- Pass a preset on the command line after `--` (Godot's own args end there):
  `godot --path . res://scenes/debug/battle_sandbox.tscn -- --preset crowded`
- A wrapper script (`tools/run_sandbox.cmd <preset>`) finds the binary and forwards the preset.
- Keep a documented preset table in the project doc: *preset · what it sets up · what to check
  with it*. Typical rows for this genre: `minimal` (smallest real fight), `default`,
  `crowded` / `stress` (the unit-count target, for performance and ordering), one per
  special mechanic that is otherwise hard to reach (a boss, a mid-fight spawn, a summon
  placement, an unlock ceremony), and non-battle screens (rewards, settlement, menu).
- A preset that opens a ceremony/tutorial at boot must say so; other presets pre-mark those
  as seen so they do not fire.
- The sandbox saves into its own dir (`user://sav_sandbox`).

## Screenshot runner

`scenes/debug/screenshot_runner.tscn` + `tools/screenshot.cmd [preset] [out.png]`.

How it must work:

1. Run it as a **scene**, not `godot -s script.gd` — `-s` replaces the main loop, so
   autoloads never initialise and dependent scripts fail to compile.
2. Instance the target scene into a **`SubViewport` fixed at the design resolution** and
   `add_child` it; capture `subviewport.get_texture().get_image()`. The image is the design
   canvas regardless of window size or DPI.
3. **Never `change_scene_to_file` from the capturing node** — that frees the node running the
   `await`, so the run hangs forever with no capture and no error.
4. Wait for layout and tweens (e.g. 60 frames, or until the presentation queue is idle), then
   save and `quit()`.
5. Suppress any "fit window / go fullscreen" logic for the capture process, and make the window
   borderless, small and no-focus so it cannot take over the screen or steal keyboard input.
6. Park the mouse (warp to a corner) first, or whatever it hovers has a tooltip open in the shot.
7. Use the console binary so a failed capture prints something.
8. To catch a transient (a 0.1 s punch or shake), slow the game rather than guessing the
   frame: an `Engine.time_scale` argument (e.g. 0.1) plus a wait in game seconds. At full
   speed the first frames of a fresh window hitch, so a timed shot lands between beats.

Why a viewport read, not a desktop grab: nothing needs focus or to be on top (no stray
windows in the frame), and no DPI trap — a non-DPI-aware desktop grab on a 125% display
captures a downscaled frame and upsamples it, adding blur that is not in the game.

**Judging a capture:** crop and upscale with **nearest-neighbour**. It magnifies without
inventing blur, so any softness you see is genuinely in the frame.

### Driving UI in a capture

- Hover and click through the capture's SubViewport: `viewport.push_input(event)` with an
  `InputEventMouseMotion`, then an `InputEventMouseButton` pressed and released, at the
  control's `get_global_rect().get_center()` (viewport pixels, the HUD's scale included). This
  exercises the real input path (hover styles, tooltips, `_gui_input`), unlike calling handlers.
- A click that rebuilds the screen frees the controls you held: look them up again before the
  next event.
