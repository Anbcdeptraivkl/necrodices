class_name PresentationQueue
extends Node
## Plays PresentationStates one at a time (skill godot-presentation-playback). The model has
## already resolved; skipping jumps every queued state to its end. `drained` fires each time
## the queue runs empty.

signal drained

var speed := 1.0
var _queue: Array[PresentationState] = []
var _current: PresentationState
var _skipping := false


func is_busy() -> bool:
	return _current != null or not _queue.is_empty()


func push(state: PresentationState) -> void:
	_queue.append(state)
	if _current == null:
		_next()


## Jump the current and all queued states to their final look, in order.
func skip_all() -> void:
	if not is_busy():
		return
	_skipping = true
	while is_busy():
		if _current == null:
			_current = _queue.pop_front()
			_current.finished.connect(_on_finished.bind(_current), CONNECT_ONE_SHOT)
		_current.skip()
	_skipping = false
	drained.emit()


func _next() -> void:
	if _queue.is_empty():
		_current = null
		drained.emit()
		return
	_current = _queue.pop_front()
	_current.finished.connect(_on_finished.bind(_current), CONNECT_ONE_SHOT)
	_current.start(self, speed)


func _on_finished(state: PresentationState) -> void:
	if state != _current:
		return
	_current = null
	if not _skipping:
		# Deferred: a state may finish inside a tween callback or inside its own start().
		_advance.call_deferred()


func _advance() -> void:
	if _current == null:  # a push() in between may already have started the next state
		_next()
