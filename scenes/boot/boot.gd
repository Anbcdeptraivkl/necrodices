extends Control
## Preload-free boot: draws one frame, then loads + validates content and opens the Title.
## No preload / class_name references here, so the first frame is not blocked by compiling
## the game graph (mobile cold start, see skill godot-mobile-pixel-ui rule 10).

var _frames := 0
@onready var _status: Label = $Status


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 2:
		_boot()


func _boot() -> void:
	set_process(false)
	var game := get_node("/root/Game")
	var db: RefCounted = load("res://core/db.gd").new()
	if not db.call("load_all"):
		game.set("boot_errors", db.get("errors"))
		for message: String in db.get("errors"):
			push_error(message)
		_status.text = "DATA ERROR\n" + "\n".join(db.get("errors"))
		return
	game.set("db", db)
	game.call("goto_scene", game.get("TITLE_SCENE"))
