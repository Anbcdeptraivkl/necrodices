class_name OverlayHost
extends Control
## Modal overlay stack (ART_SPEC §6.6, skill godot-mobile-pixel-ui rule 8): each overlay sits
## centred on its own N0 70% dim that blocks input below; only the top one is interactive.
## Escape or a click on the dim closes the top overlay when it is dismissable.
## Overlays are scenes with a `closed(result: Variant)` signal and an optional
## `dismissable: bool` property; the opener connects to `closed`.

var _stack: Array[Control] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_open() -> bool:
	return not _stack.is_empty()


func push(overlay: Control) -> Control:
	assert(overlay.has_signal(&"closed"), "overlay %s needs a closed signal" % overlay.name)
	var dim := Panel.new()
	dim.theme_type_variation = &"DimPanel"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.add_child(center)
	center.add_child(overlay)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and _top() == overlay and _dismissable(overlay):
			overlay.emit_signal(&"closed", null))
	overlay.connect(&"closed", func(_r: Variant) -> void: _remove(overlay, dim), CONNECT_DEFERRED)
	_stack.append(overlay)
	return overlay


func close_all() -> void:
	for o in _stack.duplicate():
		o.emit_signal(&"closed", null)


func _top() -> Control:
	return _stack.back() if not _stack.is_empty() else null


func _unhandled_input(event: InputEvent) -> void:
	var top := _top()
	if top != null and event.is_action_pressed(&"ui_cancel") and _dismissable(top):
		top.emit_signal(&"closed", null)
		get_viewport().set_input_as_handled()


func _dismissable(overlay: Control) -> bool:
	return bool(overlay.get(&"dismissable")) if &"dismissable" in overlay else true


func _remove(overlay: Control, dim: Control) -> void:
	_stack.erase(overlay)
	if is_instance_valid(dim):
		dim.queue_free()
