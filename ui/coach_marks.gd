class_name CoachMarks
extends RefCounted
## First-run coach marks (GAME_SPEC §12.3): each key shows once, ever, as a dismissable
## overlay; the profile remembers it.

const SCENE := "res://scenes/overlays/coach.tscn"

var _host: OverlayHost
var _owner: Node


func setup(owner: Node, host: OverlayHost) -> void:
	_owner = owner
	_host = host


func seen(key: String) -> bool:
	return Game.tutorial_seen(key)


func show_once(key: String) -> void:
	if seen(key) or _host == null:
		return
	Game.mark_tutorial(key)
	var packed: PackedScene = load(SCENE)
	var coach: Control = packed.instantiate()
	_host.push(coach)
	coach.call(&"setup", Game.db.text(key), Game.db.text("btn_ok"))
