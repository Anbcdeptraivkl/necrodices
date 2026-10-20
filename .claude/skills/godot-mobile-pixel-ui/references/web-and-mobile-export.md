# Web (HTML5), itch.io and mobile export notes

Sources checked 2026-10-20: Godot docs *Exporting for the Web* (stable = 4.7 at the time),
itch.io *Uploading HTML5 games* (itch.io/docs/creators/html5), Godot 4.3 web-export
progress report. Items marked *(unverified)* still need a check on the project's version.

## Godot web export

- Export templates must match the exact engine version; a mismatch fails the export.
- **Thread Support off** (single-threaded export, Godot 4.3+, the recommended default):
  needs no `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers and no
  SharedArrayBuffer, so it runs on itch.io, Poki, CrazyGames and on macOS / iOS Safari.
  Threaded exports need those headers (or the PWA option, which fakes them with a service
  worker) and a secure context. The default of the checkbox has varied between setups —
  check it in the preset, never rely on it.
- Single-threaded audio: the default *Sample* playback keeps latency low but has no
  AudioEffects / reverb / procedural audio; *Stream* playback supports everything with more
  latency. Keep SFX simple.
- Renderer: **Compatibility (WebGL 2) only.** Forward+ / Mobile do not export to the web.
- GDScript only: Godot 4 C# projects cannot export to the web.
- Safari has WebGL 2 quirks; test it, but Chromium and Firefox are the reference browsers.
- Canvas resize policy: *Adaptive* follows the page / iframe (the integer stretch then
  letterboxes inside it); *Project* follows project window settings; *None* leaves sizing to
  custom JS. Set the HTML background to the letterbox colour.
- VRAM texture compression: *For Desktop* for a desktop-first build; enabling *For Mobile*
  too makes a larger, more compatible export. Pixel art with lossless PNG mostly avoids VRAM
  compression anyway.
- `user://` lives in IndexedDB: needs cookies allowed (third-party cookies for iframe
  embeds such as itch.io); private windows do not persist; `OS.is_userfs_persistent()` can
  return false positives. Treat saves as best-effort and keep them small.
- Browsers block audio until a user gesture: start music after the first click (title
  button), or let the host's "click to play" provide the gesture.
- `.wasm` gzips to about a quarter; serve it as `application/wasm`.

## itch.io

- Upload a **ZIP with `index.html` at its root** (name the export `index.html`). Relative
  paths only, case-sensitive file names, HTTPS for external requests.
- Limits: **≤ 1,000 files**, ≤ 240 characters per path, ≤ 500 MB extracted, ≤ 200 MB per file
  (support can raise them). A Godot export is a handful of files.
- Compression: itch.io's own docs say uncompressed `html/js/css/wasm/pck/wav` uploads are
  gzipped automatically and pre-compressed `.gz` / `.br` files are served with the right
  encoding; Godot's docs say to pre-compress for itch.io. Measure the download size in the
  browser's network tab after the first upload *(resolve the conflict on the real page)*.
- Embed options: **Embed in page** with a fixed viewport (use an integer multiple of the
  design canvas, e.g. 960×540 for 480×270) plus the itch.io **fullscreen button**; or *Click
  to launch in fullscreen* (the game must adapt to any size). Keep **Click to play** on —
  starting on page load can leave audio muted. *Mobile friendly* forces click-to-launch
  fullscreen on phones; set the orientation there to match the game.
- The itch.io *SharedArrayBuffer support* toggle is experimental and only needed for threaded
  exports; prefer the single-threaded export.
- HTML5 games on itch.io can only take donations; selling needs a downloadable build.
- Try the build on a **draft (restricted) page** early: embed size, fullscreen, audio, saves.

## Touch input

- `input_devices/pointing/emulate_mouse_from_touch` (default on) lets Controls receive touch
  as mouse events; multi-touch gestures need `InputEventScreenTouch` / `ScreenDrag`.
- Long-press is not built in for Controls — implement it in the gesture helper.
- Every action needs a click / tap path; never rely on hover, right-click or the keyboard alone.

## Mobile

- Orientation: `display/window/handheld/orientation` set to the game's orientation
  (`portrait` = 1, `landscape` = 0 in `project.godot`).
- Safe area: `DisplayServer.get_display_safe_area()` gives the physical safe rect; convert to
  virtual px and pad the edges it cuts (notch sides in landscape, top / bottom in portrait).
- Cold start: preload-free boot scene, light autoloads (team-kb f835d663 — measured on iOS
  standalone builds of another project).
