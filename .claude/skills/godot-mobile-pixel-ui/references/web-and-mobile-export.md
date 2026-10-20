# Web (HTML5) and mobile export notes

> Status: **draft** — items marked *(unverified)* are starting points to confirm on the
> project's engine version and target browsers before relying on them.

## Web

- Export templates must match the exact engine version (`Editor → Manage Export Templates`);
  a mismatch fails the export.
- **Threads off** for broad hosting (itch.io, plain static hosts): single-threaded web export
  does not need cross-origin isolation (COOP/COEP headers / SharedArrayBuffer). Godot 4.3+
  offers this as the "Thread Support" export option *(confirm the option name per version)*.
- GDScript only: C# projects cannot export to Web on Godot 4.x up to at least 4.5
  *(re-check for newer versions)*.
- `user://` is backed by IndexedDB in the browser. Saves survive reloads but can be cleared by
  the browser (private mode, storage pressure); treat them as best-effort and keep them small.
- Browsers block audio until a user gesture. Start music after the first tap (title screen
  button), not in `_ready` of the boot scene.
- Canvas resize policy *Adaptive* lets the canvas follow the page; the integer-scale stretch
  then letterboxes inside it. Set the HTML background to the letterbox colour.
- Keep the first download small: compress textures losslessly, avoid large unused assets,
  subset fonts. Measure the `.pck` + `.wasm` size per build.
- Test on a real phone browser early (touch, orientation, address-bar resize); desktop
  devtools device emulation misses resize and audio quirks.
- Profile frame time in the browser with the target sprite counts; web is usually the
  slowest target.

## Touch input

- `input_devices/pointing/emulate_mouse_from_touch` (default on) lets Controls receive touch
  as mouse events; multi-touch gestures need `InputEventScreenTouch` / `ScreenDrag`.
- Long-press is not built in for Controls — implement it in the gesture helper.
- Avoid relying on right-click or keyboard; every action needs a touch path.

## Mobile

- Orientation: `display/window/handheld/orientation = portrait` (portrait-only game).
- Safe area: `DisplayServer.get_display_safe_area()` gives the physical safe rect; convert to
  virtual px and pad the top/bottom bars.
- Cold start: preload-free boot scene, light autoloads (team-kb f835d663 — measured on iOS
  standalone builds of another project).
