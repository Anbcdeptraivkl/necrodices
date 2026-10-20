# Godot 4 engine traps already hit

Check here before debugging your own code. Add a row whenever a trap costs real time.

## Tooling and CLI

| Trap | Symptom | Fix |
| --- | --- | --- |
| **Stale global class cache** | `Parse Error: Identifier "X" not declared` for a script that has existed for weeks, on a fresh clone or after a killed Godot process | `.godot/` is not committed. Run `godot --headless --path . --import` at the start of every session and after adding a `class_name` |
| **Plain Windows build is silent** | `--headless` run prints nothing; failures look like passes | Use the `_console.exe` build |
| **Lingering Godot process** | The test runner reports an error you already fixed, with the old message text; running the file directly passes | A previous process holds the temp log file open, so the redirect and delete fail silently and the old log is printed. Tell: *"being used by another process"*. Kill it: `taskkill /F /IM <godot_console_exe>` |
| **Autoload names are not globals under `--script`** | `Identifier not found: SaveManager` in a `SceneTree` test that compiles fine as a scene | Look it up: `root.get_node("SaveManager")` |
| **Nodes added to `root` are not "in tree" during `_initialize()`** | `is_inside_tree()` is false; `get_tree()`-guarded lookups return null; unrelated assertions fail | The tree is not running yet. Resolve autoloads via `Engine.get_main_loop()` |
| **`godot -s script.gd` replaces the main loop** | Autoloads never initialise; scripts referencing them fail to compile | Run a scene instead when autoloads are needed |
| **`change_scene_to_file` from the node that awaits** | Run hangs forever, no error | Instance + `add_child` the target; keep the caller alive |

## Data

| Trap | Symptom | Fix |
| --- | --- | --- |
| **JSON numbers are floats** | `1` renders as `"1.0"`; `int` typed assignments warn | Narrow whole-number floats to int on load in one JSON helper; a content test guards it |
| **Packed arrays are passed and assigned by reference** | Editing `var a := obj.packed_array` changes the object's array; a "local copy" optimisation changes nothing | Godot 4 packed arrays share storage; call `duplicate()` for a real copy. Local references are still worth it in hot loops: they skip a member lookup per access |
| **`Array(<const PackedStringArray>)` is not a copy** (seen in a `static func`, Godot 4.5.1) | A "fresh" defaults list grows after one caller appends to it; later defaults compare unequal | Build the list per call with a loop, or `duplicate()` a non-constant expression. Read-only uses are fine (team-kb 0f929b5b) |
| **`JSON.parse_string` pushes an engine ERROR on bad input** | Corrupt-file handling still floods the log with red | `JSON.new().parse()` returns a status; use `get_error_message()` / `get_error_line()` |

## UI / Control

| Trap | Symptom | Fix |
| --- | --- | --- |
| **Containers reset child transforms** | A rotated/scaled child of an `HBoxContainer` snaps back every layout pass | Wrap it in a plain `Control` and transform the inner node |
| **Autowrap Labels report stale minimum height** | Tooltip panel taller than its text by whole lines, seemingly at random | Size from font metrics, or wrap manually; re-check after `await get_tree().process_frame` |
| **`scale` breaks `Control` hit tests** | Hover/drop fires in the wrong place after visually shrinking a node | Resize the node (or its sprite box) instead of scaling it |
| **Overlapping hover regions strobe** | Tooltip flickers as the cursor crosses between a unit and its own badges | Disjoint hit areas with a small dead gap; a fade only hides it |
| **Rotated thin frames alias** | Thin borders look chewed | Keep thin-bordered frames axis-aligned |

## Rendering and window

| Trap | Symptom | Fix |
| --- | --- | --- |
| **`default_texture_filter` enum order differs from `CanvasItem.TextureFilter`** | "Linear mipmap" set but sprites look wrong | Project setting order: `0 Nearest, 1 Linear, 2 Linear Mipmap, 3 Nearest Mipmap`. `CanvasItem` constants differ. Read the setting's `hint_string` to confirm |
| **Newly imported textures get engine defaults** | One new asset looks different from the rest | Every new asset must go through the project's import pass/preset — see `godot-pixel-art-rendering` |
| **Non-integer window scale** | Whole frame soft, text included | Integer scale factor of the design resolution, or fullscreen at a multiple |
| **Borderless window exactly screen-sized is treated as exclusive fullscreen** | `window_get_mode()` reports fullscreen; toggling to windowed does nothing | Use real `WINDOW_MODE_FULLSCREEN`; track intended mode yourself |
| **`screen_get_usable_rect` vs OS numbers under DPI scaling** | OS says 1536×864, Godot says 1920×1020 | Trust Godot's numbers for window sizing |
| **Non-DPI-aware screen grabs** | Screenshot blurrier than the game | Capture from a `SubViewport`, or make the grabber DPI-aware |
| **Output folder inside `res://`** (captures, reports) | The editor / `--import` imports every generated image, slowing imports and adding `.import` files | Put a `.gdignore` file in the folder |
| **Capture runner steps the game many ticks in one frame** | Short effects (hit flash, FX) never appear in captures: the next frame's real `delta` ages them out | In a manual-clock capture mode, advance view time only with the sim, not with frame `delta` |
| **`core.autocrlf=true` on Windows vs Godot's LF files** | After any Godot run, untouched `.import` / `.tscn` files show as modified in `git status` while `git diff` is empty | Add `* text=auto eol=lf` at the top of `.gitattributes` (Godot's own template; keep later rules such as `*.cmd text eol=crlf`), then `git checkout --` the no-op files |
| **A runtime error in a `--script` / headless run does not quit** | The process never exits (no `quit()` reached); a batch run or test wrapper hangs until killed | Run headless tools under a timeout; guard the failure path with an explicit `quit(1)` |
| **`Array.slice()` (and other untyped returns) break `:=` inference** | `Parse Error: Cannot infer the type of "n"` on `for d in typed_array.slice(0, 4): var n := cell + d` | Keep a typed `const` for the subset (e.g. the 4 orthogonal directions), or type the loop variable (`for d: Vector2i in ...`) |
| **Script names that shadow engine classes** (an enum or class called `Material`, `Image`, `Mesh`…) | `Could not resolve external class member "Material"`, or the engine class is used instead of yours | Pick names no engine class uses (e.g. `Ground` for terrain materials) |
| **`const X := SomeClassName`** | `Assigned value for constant "X" isn't a constant expression` | Alias a script with `const X := preload("res://path.gd")` |
| **`RefCounted` reference cycle** (an owned helper keeps a reference back to its owner) | Tests that passed start failing on `ERROR: N resources still in use at exit` and `ObjectDB instances leaked`; nothing else is wrong | RefCounted objects in a cycle are never freed. Pass the owner into the helper's methods instead of storing it (or hold a `weakref()`) |
| **Exported typed array of a custom Resource class** (`@export var rows: Array[MySkill]`, filled in code) | Every case passes, then the process ends in `CrashHandlerException: Program crashed with signal 11` — only some runs (seen ~half, Godot 4.6.2), so it looks flaky | Measure the rate before and after (run the same suites 5×; compare with a `git archive HEAD` copy). Use an untyped `Array` with a typed accessor (`func row(i) -> MySkill`), and comment why. Cause inside the engine not verified |
| **A runaway log from a per-tick script error** | A headless report "takes forever"; its output file grows to hundreds of MB | The same `SCRIPT ERROR` repeats every tick. Cap long runs with a timeout and check the log's first error, not its end |
| **`Callable.bind` puts the bound arguments after the call's** (`f.bind(a)` called with `x` runs `f(x, a)`) | A callback gets its arguments swapped; a typed parameter errors or a value is silently wrong | Bind only trailing arguments; otherwise wrap in a lambda (`func(x): return f(a, x)`) |
| **A reused node kept outside the tree between rebuilds** (a grid or tab detached and re-added on each refresh) | `ObjectDB instances leaked`, `RID ... leaked` and `resources still in use` at exit, only in suites that free the screen | Nodes not in the tree are not freed with their old parent: free them in the owner's `NOTIFICATION_PREDELETE` when they have no parent |
| **Headless uses a dummy renderer** | A test reads back `MultiMesh` instance transforms/colours (or other GPU-side buffers) and gets zeros | Keep the computation in pure static functions and test those; verify the drawn result with a screenshot run (needs a real window, not `--headless`) |
| **A test suite with a parse error under a `--script` runner** | The run hangs: `script.new()` on a broken script is a runtime error and the runner never reaches `quit()` | Check `script.can_instantiate()` before `new()`; report the suite as FAIL and continue. Wrap the whole run in a timeout as well |
| **`--write-movie` to capture a layout at another window size** | Every frame is the startup viewport size whatever `--resolution` says | Capture from a scene: build the state, wait, `await RenderingServer.frame_post_draw`, `get_viewport().get_texture().get_image().save_png()` |
