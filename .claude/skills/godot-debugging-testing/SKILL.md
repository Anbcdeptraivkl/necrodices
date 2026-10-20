---
name: godot-debugging-testing
description: Running, testing and debugging a Godot 4 project from the command line on Windows — headless tests, debug sandbox scenes with presets, programmatic screenshots, finding the Godot binary, save-file isolation, and a table of engine traps already hit. Use when writing or running tests, reproducing a bug, verifying a change in the running game, taking screenshots, setting up a sandbox/preset, seeing silent or stale test output, parse errors about undeclared class_name, or any Godot behaviour that looks like an engine bug.
---

# Godot Debugging and Testing

Owns *proving a change works*: running the game in a known state, headless tests, captures,
and the engine traps that waste hours. The project's actual script names and presets are in
its own docs (`docs/debugging.md` or `AGENTS.md`); this skill is the method.

## Rules

1. **Re-import at the start of every session**, before the first test or run:
   `godot --headless --path . --import`. `.godot/` is not committed, so the global
   `class_name` cache is often incomplete or stale; the symptom is *"Identifier X not declared"*
   for a script that plainly exists. Re-run after adding a `class_name`.
2. **Use the console binary on Windows** (`Godot_v4.x-stable_win64_console.exe`, or
   `..._mono_win64_console.exe` for .NET). The plain build detaches from the console and prints
   nothing, so a failure looks like a pass.
3. **A task is not done until it ran.** Logic → a headless test. Visible change → run the
   sandbox preset or capture a screenshot and look at it. Report what was actually executed.
4. **Every test that can save must redirect the save dir first** (e.g. `user://sav_test`).
   Tests and sandbox never touch the real profile.
5. **Red log = failure.** A test that passes while the log shows engine ERRORs is hiding a bug;
   use APIs that return status instead of pushing errors (e.g. `JSON.new().parse()`).
6. **Known state beats walking there.** Reproduce UI/combat issues in a sandbox preset, not by
   playing to the situation. A missing situation is a new preset row.

## Procedure — verify a change

1. `godot --headless --path . --import` (once per session).
2. Run the cases the change can break (by suite / case, or "changed files" mode); the whole
   suite only before handing over or after a change to shared code — not after every edit.
3. For visuals: run the sandbox preset, or the screenshot runner, and inspect the image at a
   nearest-neighbour zoom.
4. If output is missing or looks stale: check the trap table before debugging your own code.

## Headless test shape (no framework)

Suites of cases, one runner, one process:

```gdscript
# tests/_suite.gd
class_name TestSuite
extends RefCounted
var tree: SceneTree          # set by the runner; cases may add scenes and await frames
var failures := 0
func _check(cond: bool, msg: String) -> void:
    if not cond:
        failures += 1
        push_error(msg)

# tests/test_combat.gd
extends TestSuite
const COVERS: Array[String] = ["scripts/combat/", "data/units/"]  # paths this suite checks
func test_strike_hits() -> void:
    _check(..., "a strike in reach hits")
```

`tests/_run.gd` (`extends SceneTree`) defers its work out of `_initialize` (the tree is not
running there), loads every `test_*.gd`, runs each `test_*` method (`await suite.call(name)`)
and prints `PASS suite.case (ms)` / `FAIL`, exit code 1 on any failure. Arguments pick suites
(`combat`), cases by name part (`combat:strike`) or **the suites whose `COVERS` match the files
changed against HEAD** (`git status --porcelain`, plus `git diff --name-only <ref>` for
`--since`); it reports changed files no suite covers, so the map stays honest. Run the cases a
change can break while working; the whole suite (with a re-import) before handing over or
after touching shared code. Under `--script`, autoload names are not globals — see the trap
table.

## UI tests in the real game

Screens use autoloads, which are not globals under `--script`, so UI flows run as a scene
(`godot --headless --path . res://tests/ui/ui_runner.tscn`). The runner must outlive
`change_scene_*`: on `_ready` it adds a placeholder node, makes it `current_scene`, and
`reparent`s itself to the root. Drive screens through their own controls
(`button.pressed.emit()`, a component's signal), never by calling model commands directly —
that is what catches a button wired to the wrong command. Point the save store at a test dir.

## Routing

- Sandbox scenes, presets as data rows, and the screenshot runner → [references/sandbox-and-screenshots.md](references/sandbox-and-screenshots.md)
- Engine traps (symptom → fix) → [references/engine-traps.md](references/engine-traps.md)
- Finding the binary, window/fullscreen, save locations → [references/environment.md](references/environment.md)
- Many-sprite playback performance (pools, render tiers) → `godot-presentation-playback`
- Balance simulation bots and statistical regressions → `roguelike-run-economy`
