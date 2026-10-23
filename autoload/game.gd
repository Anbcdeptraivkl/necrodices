extends Node
## App service (GAME_SPEC §10): owns the content db, the current RunState, the save store and
## the profile, and switches screens. Screens call these commands; routing follows the run
## phase stored in the save (skill godot-architecture: persisted FSM phase).
## No preloads: scenes are loaded by path when entered (cold start, D-A05).

signal profile_changed

const SCENES := {
	"title": "res://scenes/title/title.tscn",
	"night_map": "res://scenes/night_map/night_map.tscn",
	"encounter": "res://scenes/encounter/encounter.tscn",
	"shop": "res://scenes/shop/shop.tscn",
	"end": "res://scenes/end/end_screen.tscn",
}
const TITLE_SCENE := "res://scenes/title/title.tscn"

## ContentDb, set by the boot scene once data is loaded and validated.
var db: ContentDb
var boot_errors: PackedStringArray = []
var run: RunState
var encounter: EncounterState
## Spoils lines of the last won encounter, shown by the shop on entry.
var last_spoils: Array[Dictionary] = []
var store := SaveStore.new()
var profile := {}


func _ready() -> void:
	profile = store.load_profile()
	var settings := get_node("/root/Settings")
	settings.load_from(profile.get("settings", {}))


func goto_scene(path: String) -> void:
	var packed: PackedScene = load(path)
	get_tree().change_scene_to_packed(packed)


func goto(screen: String) -> void:
	goto_scene(SCENES[screen])


func has_saved_run() -> bool:
	return store.has_run()


func new_run(seed: String = "") -> void:
	if seed == "":
		seed = RngStreams.new_seed()
	run = RunFlow.new_run(db, seed)
	profile["runs_played"] = int(profile.get("runs_played", 0)) + 1
	profile["last_seed"] = seed
	save_profile()
	store.save_run(run)
	goto("night_map")


func continue_run() -> void:
	run = store.load_run()
	if run == null:
		goto("title")
		return
	route()


## Shows the screen for the stored phase. An ENCOUNTER save restarts that encounter from its
## start with the saved RNG state (§12.1).
func route() -> void:
	match run.phase:
		RunState.Phase.NIGHT_MAP:
			goto("night_map")
		RunState.Phase.ENCOUNTER:
			start_encounter()
		RunState.Phase.SHOP:
			goto("shop")
		_:
			goto("end")


## NIGHT_MAP → ENCOUNTER: save first (before any roll), then begin.
func start_encounter() -> void:
	encounter = RunFlow.start_encounter(db, run)
	store.save_run(run)
	goto("encounter")


## Called by the encounter screen once combat is resolved (before playback ends is fine:
## the model already moved on). Returns the spoils lines.
func finish_encounter() -> Array[Dictionary]:
	last_spoils = RunFlow.finish_encounter(db, run, encounter)
	profile["best_night"] = maxi(int(profile.get("best_night", 0)), run.night)
	match run.phase:
		RunState.Phase.SHOP:
			store.save_run(run)
		RunState.Phase.VICTORY:
			profile["runs_won"] = int(profile.get("runs_won", 0)) + 1
			store.delete_run()
		RunState.Phase.GAME_OVER:
			store.delete_run()
	save_profile()
	return last_spoils


## After every shop command: the save always equals what the player sees.
func save_run() -> void:
	if run != null and run.phase in [RunState.Phase.SHOP, RunState.Phase.NIGHT_MAP]:
		store.save_run(run)


func leave_shop() -> void:
	RunFlow.leave_shop(run)
	store.save_run(run)
	goto("night_map")


func abandon_to_title() -> void:
	encounter = null
	goto("title")


func tutorial_seen(key: String) -> bool:
	return bool(profile.get("tutorial", {}).get(key, false))


func mark_tutorial(key: String) -> void:
	var t: Dictionary = profile.get("tutorial", {})
	t[key] = true
	profile["tutorial"] = t
	save_profile()


func save_profile() -> void:
	profile["settings"] = get_node("/root/Settings").values.duplicate()
	store.save_profile(profile)
	profile_changed.emit()
