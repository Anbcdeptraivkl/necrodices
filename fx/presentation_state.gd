class_name PresentationState
extends RefCounted
## One skippable animation (skill godot-presentation-playback). Subclasses override
## `_start(host)` (create tweens on `host`, connect the last one's `finished` to `done`) and
## `_jump_to_end()` (kill tweens, apply the final look). No `await` inside a state: a skipped
## state is dropped while a coroutine would still wait on a killed tween.

signal finished

var duration := 0.0      # nominal seconds at ×1, used by the timeline budget
var _finished := false
var _tweens: Array[Tween] = []


func start(host: Node, speed: float) -> void:
	_start(host, speed)


func skip() -> void:
	for t in _tweens:
		if t != null and t.is_valid():
			t.kill()
	_tweens.clear()
	_jump_to_end()
	done()


func done() -> void:
	if _finished:
		return
	_finished = true
	finished.emit()


## A tween owned by this state: killed on skip; its end calls done() when `last` is true.
func tween(host: Node, last: bool = false) -> Tween:
	var t := host.create_tween()
	_tweens.append(t)
	if last:
		t.finished.connect(done)
	return t


func _start(_host: Node, _speed: float) -> void:
	done()


func _jump_to_end() -> void:
	pass
