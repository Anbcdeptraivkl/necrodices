# Tech — engine, commands, layout

| Item | Value |
| --- | --- |
| Engine | Godot **4.6.3 stable**, standard build, console binary for tools: `C:\Users\admin\Tools\Godot_v4.6.3-stable_win64\Godot_v4.6.3-stable_win64_console.exe` (lookup: `tools/_find_godot.cmd`, override `set GODOT=...`) |
| Language | GDScript only (D-A01) |
| Renderer | GL Compatibility (D-A03) |
| Display | 270×480 design canvas, `viewport` stretch, aspect `keep`, integer scale, nearest, pixel snap; `Display` autoload grows the canvas height to ≤ 640 on tall screens (D-A08) |
| Font | Fusion Pixel 8 px / 12 px, OFL (`assets/fonts/`), pixel import defaults in `project.godot` (D-R05) |
| Saves | `user://` = `%APPDATA%\NecroDices\` (`run.json`, `profile.json`); tests redirect to `sav_test` |
| Python | 3.12 + Pillow (art pipeline, data checker, skill index) |

## Commands

```bat
tools\run.cmd                         :: play windowed 540x960
tools\test.cmd                        :: re-import + every suite
tools\test.cmd --changed              :: suites covering changed files
tools\test.cmd data:pair              :: one suite / cases by name part
python tools\check_data.py            :: data vs spec tables
python tools\build_manifest.py        :: assets/manifest.json from ART_SPEC §11
python tools\gen_placeholders.py      :: create MISSING placeholder PNGs (--only <glob> / --force to overwrite)
python tools\validate_art.py          :: ART_SPEC §9.3 checks
python tools\skills_index.py --write  :: regenerate the skill index in AGENTS.md
"%GODOT_EXE%" --path . --resolution 540x1200 res://scenes/dev/display_probe.tscn  :: print scale / canvas for a window size
```

First run on a fresh clone: `"%GODOT_EXE%" --headless --path . --import` (tools\test.cmd does it).

## Folders

```
autoload/   Display, Events, Settings, Audio, Game (preload-free)
core/       pure rules (RefCounted), headless-tested
scenes/     boot, title, night_map, encounter, shop, end, overlays, dev
ui/         components + theme
fx/         presentation queue, combat player, horde renderer, shaders
data/       content JSON (GAME_SPEC §9)
assets/     art per ART_SPEC §11 (manifest.json is generated)
tools/      python + cmd tooling, balance_sim.gd
tests/      _run.gd, _suite.gd, test_*.gd
docs/       plan, tech notes
```
