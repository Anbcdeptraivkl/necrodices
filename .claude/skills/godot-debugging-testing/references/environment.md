# Environment: binary, window, saves

## Finding the Godot binary

Wrapper scripts call one finder (`tools/_find_godot.cmd`) that honours an override and then
searches common locations:

```
%GODOT%                      explicit override (set GODOT=D:\...\Godot_v4.x_win64_console.exe)
%USERPROFILE%\Tools\Godot
%LOCALAPPDATA%\Programs\Godot
%ProgramFiles%\Godot
C:\Godot
PATH
```

Match `Godot_v4*_win64_console.exe` (or `*mono*` for a .NET project) and prefer the console
build. Record the engine version the project targets in its docs; if the machine's version
differs, note it — it matters when chasing engine behaviour.

**The pinned version is missing on this machine** (fresh machine, only another 4.x
installed): do not run the project with a different minor version — an import rewrites the
`.godot/` cache and can bump `project.godot` and resource formats that then land in a commit.
Download the exact official build (`godotengine/godot-builds` GitHub releases,
`Godot_v<ver>-stable_win64.exe.zip`) into the first lookup folder, after the user agrees to
the download.

## Running without taking over the machine

The dev machine is usually in use for other work while the agent runs the game.
- Prefer headless for anything that needs no pixels: tests, reports, map/data dumps
  (`Image` → PNG works headless). Headless opens no window at all.
- Windowed runs (captures, perf) use the small borderless no-focus window from
  [sandbox-and-screenshots.md](sandbox-and-screenshots.md), and are launched as a background
  job so the agent keeps working while they run.
- Interactive runs meant for the user to play are started only when the user asks.

## Window and fullscreen

- Keep window-fit logic in one utility called by the main scene **and** every debug sandbox
  (sandboxes do not boot through the main scene).
- Opening fullscreen avoids a non-integer window scale on most monitors. For a windowed mode,
  pick the largest **integer multiple** of the design resolution that fits the usable area.
- Toggle with `F11` / `Alt+Enter`; use `WINDOW_MODE_FULLSCREEN`, not a screen-sized
  borderless window (see engine traps).

## Save files

- Set `application/config/use_custom_user_dir` + a custom dir name in `project.godot`, so
  `user://` is `%APPDATA%\<game>\` instead of the shared Godot app-data folder. Print the
  absolute save path somewhere visible in dev builds (e.g. the main menu footer).
- Split persistent profile (`player.json`: unlocks, records, settings) from the run in
  progress (`run.json`, deleted when a run ends). Document in the project which file to delete
  for which reset.
- Tests write to `sav_test`, the sandbox to `sav_sandbox`, siblings of the real `sav`.
- Decide and document what is saved mid-battle. A common choice for roguelites: only map
  state is saved; quitting mid-battle costs the battle, not the run.
