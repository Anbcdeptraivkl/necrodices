extends Node
## Owns the content database and (from M2/M3) the RunState and scene transitions.
## Kept preload-free so the first frame is not blocked compiling the game graph (boot scene loads it).

const TITLE_SCENE := "res://scenes/title/title.tscn"

## ContentDb, set by the boot scene once data is loaded and validated.
var db: RefCounted
var boot_errors: PackedStringArray = []


func goto_scene(path: String) -> void:
	var packed: PackedScene = load(path)
	get_tree().change_scene_to_packed(packed)
