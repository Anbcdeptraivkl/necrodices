# RNG streams, saves and the balance bot

## Streams

```gdscript
class_name RngStreams extends RefCounted
var _streams := {}          # name -> RandomNumberGenerator

func _init(run_seed: String, names: PackedStringArray) -> void:
    for n in names:
        var r := RandomNumberGenerator.new()
        r.seed = hash(run_seed + ":" + n)
        _streams[n] = r

func get_stream(n: String) -> RandomNumberGenerator: return _streams[n]  # unknown name → error
func to_dict() -> Dictionary: # name -> state (int)
func from_dict(d: Dictionary) -> void: # restore .state, not .seed
```

- Restore `state`, not `seed` (re-seeding restarts the sequence).
- `hash()` of a String is stable across runs of the same engine version; record the engine
  version with saves if replays must survive upgrades *(check on version bumps)*.
- Seeded shuffles: Fisher–Yates with the stream, never `Array.shuffle()` (global RNG).
- `pick_weighted(stream, ids, weights)` in one helper; ids sorted before the pick.

## Save layout

```
user://run.json      { "version": n, "phase": "SHOP", "run": {...}, "rng": {...} }
user://profile.json  { "version": n, "best_night": k, "wins": w, "settings": {...}, "tutorial": {...} }
```

- Write to `run.json.tmp`, then rename — a crash mid-write must not corrupt the only save.
- Version field + migration function per bump; unknown version → refuse loudly, offer new run.
- Tests redirect the save directory before anything can save.

## Determinism test

Scripted inputs (a list of commands) applied to a new run with seed S; hash
`JSON.stringify(run.to_dict(), "", true)` (sorted keys) after k encounters; run twice in one
process and once after a save/load round trip in the middle. All three hashes equal.

## Balance bot harness

- Entry: `godot --headless --path . --script res://tools/balance_sim.gd -- --runs=1000 --seed=X`
  (note: autoloads are not globals under `--script`; the sim uses only core classes).
- Policy is a small class with `choose_turn(enc) -> commands`, `choose_shop(run, shop) -> commands`;
  the harness applies commands through the same API the UI uses.
- Report: reach-night histogram, win %, damage p10/p50/p90 per night vs HP, money at each shop,
  most-bought items. Print a one-line summary first so it can be diffed between commits.
- Long sims: cap runtime, print progress every N runs, exit non-zero on script errors.
