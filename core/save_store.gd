class_name SaveStore
extends RefCounted
## Run and profile persistence (GAME_SPEC §12.1). `run.json` is written at encounter start and
## shop entry and deleted when the run ends; `profile.json` keeps records, settings and
## tutorial flags. Writes go to a temp file first, then replace (a crash cannot corrupt the
## only save). Tests point `dir` at their own folder.

const RUN_FILE := "run.json"
const PROFILE_FILE := "profile.json"
const PROFILE_VERSION := 1

var dir := "user://"


func _init(p_dir: String = "user://") -> void:
	dir = p_dir
	DirAccess.make_dir_recursive_absolute(dir)


func has_run() -> bool:
	return FileAccess.file_exists(dir.path_join(RUN_FILE))


func save_run(run: RunState) -> bool:
	return _write(RUN_FILE, run.to_dict())


## Returns null when there is no save or it cannot be read (a broken save is deleted).
func load_run() -> RunState:
	if not has_run():
		return null
	var errors: PackedStringArray = []
	var data: Variant = JsonUtil.load_file(dir.path_join(RUN_FILE), errors)
	if data == null or typeof(data) != TYPE_DICTIONARY or data.get("version", 0) != RunState.SAVE_VERSION:
		push_warning("run save unreadable, discarded: %s" % [errors])
		delete_run()
		return null
	return RunState.from_dict(data)


func delete_run() -> void:
	var path := dir.path_join(RUN_FILE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func load_profile() -> Dictionary:
	var defaults := {"version": PROFILE_VERSION, "best_night": 0, "runs_won": 0, "runs_played": 0,
		"settings": {}, "tutorial": {}, "last_seed": ""}
	var path := dir.path_join(PROFILE_FILE)
	if not FileAccess.file_exists(path):
		return defaults
	var errors: PackedStringArray = []
	var data: Variant = JsonUtil.load_file(path, errors)
	if typeof(data) != TYPE_DICTIONARY:
		return defaults
	defaults.merge(data, true)
	return defaults


func save_profile(profile: Dictionary) -> bool:
	return _write(PROFILE_FILE, profile)


func _write(file: String, data: Dictionary) -> bool:
	var path := dir.path_join(file)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s: %s" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "", true))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK
