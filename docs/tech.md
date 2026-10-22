# Tech — engine, commands, layout

| Item | Value |
| --- | --- |
| Engine | Godot **4.6.3 stable**, standard build, console binary for tools: `C:\Users\admin\Tools\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe` (lookup: `tools/_find_godot.cmd`, override `set GODOT=...`) |
| Language | GDScript only (D-A01) |
| Renderer | GL Compatibility (D-A03) |
| Display | 480×270 landscape design canvas, `viewport` stretch, aspect `keep`, integer scale, nearest, pixel snap; `Display` autoload grows the canvas up to 640×300 for non-16:9 windows (D-A08, D-A09) |
| Target | Web desktop on itch.io first (single-threaded export), mobile landscape second (D-A10) |
| Font | Fusion Pixel 8 px / 12 px, OFL (`assets/fonts/`), pixel import defaults in `project.godot` (D-R05) |
| Saves | `user://` = `%APPDATA%\NecroDices\` (`run.json`, `profile.json`); tests redirect to `sav_test` |
| Python | 3.12 + Pillow (art pipeline, data checker, skill index) |

## Commands

```bat
tools\run.cmd                         :: play windowed 960x540
tools\test.cmd                        :: re-import + every suite
tools\test.cmd --changed              :: suites covering changed files
tools\test.cmd data:pair              :: one suite / cases by name part
python tools\check_data.py            :: data vs spec tables
python tools\build_manifest.py        :: assets/manifest.json from ART_SPEC §11
python tools\gen_placeholders.py      :: create MISSING placeholder PNGs (--only <glob> / --force to overwrite)
python tools\validate_art.py          :: ART_SPEC §9.3 checks
python tools\layout_mockup.py         :: ART_SPEC §6 wireframes -> docs/mockups/
python tools\skills_index.py --write  :: regenerate the skill index in AGENTS.md
tools\ui_test.cmd                     :: UI smoke tests in the real game (autoloads): flows driven by buttons
tools\screenshot.cmd encounter captures\x.png   :: capture a preset (scenes/dev/capture.gd PRESETS)
tools\balance_sim.cmd --mode=baseline --trials=20000   :: Appendix A regression (§5.6)
tools\balance_sim.cmd --mode=runs --trials=1000        :: Appendix B bot: reach / win / deaths by rule
tools\export_web.cmd                  :: Web release → build\web + build\roll_the_bones_web.zip (needs 4.6.3 templates)
tools\serve_web.cmd [port]            :: play the Web build at http://127.0.0.1:8060/ (opening index.html from disk fails: file:// blocks fetch)
python tools\art\<units|enemies_dice|icons|scenery|backgrounds|ui_buttons|howto>.py [--only id | --all] [--preview out.png]   :: art generators: no flag = create missing files only (hand edits are never overwritten); --only rewrites the named ids; --all rewrites every changed id
"%GODOT_EXE%" --path . --resolution 1600x900 res://scenes/dev/display_probe.tscn  :: print scale / canvas for a window size
```

First run on a fresh clone: `"%GODOT_EXE%" --headless --path . --import` (tools\test.cmd does it).

## Folders

```
autoload/   Display, Settings, Audio, Game (preload-free; no global event bus, D-A11)
core/       pure rules (RefCounted), headless-tested
scenes/     boot, title, night_map, encounter, shop, end, overlays, dev
ui/         components + theme
fx/         presentation queue, combat player, horde renderer, shaders
data/       content JSON (GAME_SPEC §9)
assets/     art per ART_SPEC §11 (manifest.json is generated)
tools/      python + cmd tooling, balance_sim.gd
tests/      _run.gd, _suite.gd, test_*.gd (headless core), ui/ui_runner.tscn (in-game UI flows)
docs/       plan, tech notes, wireframes
art_source/ designer source files (.aseprite, layered PNGs); .gdignore, never exported
```
