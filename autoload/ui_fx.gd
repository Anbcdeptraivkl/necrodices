extends Node
## UI feel shared by every screen, wired once per node from `node_added` (no per-screen code):
## - press: a 120 ms squash punch (1 → 0.92 → 1) for every BaseButton and every Control
##   flagged `press_fx` (slots, dice, chips); transient, ends at exactly ×1, off with Reduce motion;
## - hover: Buttons get it from the theme (lighter 9-slice, label lifted 1 px); custom-drawn
##   controls flagged `hover_fx` get their `hovered` property set from the same per-frame poll
##   of the hovered control (never mouse_entered/exited: those stick or blink when a control is
##   rebuilt under a resting pointer);
## - tooltip: one pixel tooltip panel on top of everything (skill godot-mobile-pixel-ui): a
##   control with meta `tip` (String) shows it; a control with meta `info` (InfoPanel callable)
##   shows its title/body when no docked InfoPanel is on screen. State machine against flicker:
##   WAITING opens after REST_TIME at rest; SHOWN switches content at once to another target;
##   GRACE keeps it GRACE_TIME after the pointer leaves (gaps between slots), then closes.
##   Sits beside the pointer, flips at the canvas edges, never under the pointer; hidden while
##   dragging or holding a button, and after a click until the pointer reaches another target.

const PUNCH := Vector2(0.92, 0.92)
const DOWN_TIME := 0.04
const UP_TIME := 0.08
const TWEEN_META := &"ui_fx_tween"
const REST_TIME := 0.25
const GRACE_TIME := 0.15
const TIP_MAX_W := 140.0
const TIP_LAYER := 100
const TIP_OFFSET := Vector2(8, 10)

var _tip_panel: PanelContainer
var _tip_title: Label
var _tip_body: Label
enum Tip { IDLE, WAITING, SHOWN, GRACE }

var _tip_state: Tip = Tip.IDLE
var _tip_target: Control
var _tip_timer := 0.0
var _tip_muted: Control       # clicked target: no tooltip again until the pointer leaves it
var _hover_owner: Control     # custom control currently drawn hovered


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_build_tooltip()


func _on_node_added(node: Node) -> void:
	var control := node as Control
	if control == null or control.has_meta(&"ui_fx"):
		return
	if control is BaseButton:
		control.set_meta(&"ui_fx", true)
		(control as BaseButton).button_down.connect(_punch.bind(control))
		return
	# custom controls declare themselves in _init / the scene (metadata) — wait until ready
	if not control.is_node_ready():
		control.ready.connect(_wire_custom.bind(control), CONNECT_ONE_SHOT)
	else:
		_wire_custom(control)


func _wire_custom(control: Control) -> void:
	if control.has_meta(&"ui_fx"):
		return
	if control.has_meta(&"press_fx"):
		control.set_meta(&"ui_fx", true)
		control.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_punch(control))


func _punch(control: Control) -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings != null and settings.get_value("reduce_motion"):
		return
	var previous: Tween = control.get_meta(TWEEN_META) if control.has_meta(TWEEN_META) else null
	if previous != null and previous.is_valid():
		previous.kill()
	control.pivot_offset = (control.size / 2.0).floor()
	var t := control.create_tween()
	t.tween_property(control, "scale", PUNCH, DOWN_TIME).from(Vector2.ONE)
	t.tween_property(control, "scale", Vector2.ONE, UP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	control.set_meta(TWEEN_META, t)


# --- tooltip -----------------------------------------------------------------------------

func _build_tooltip() -> void:
	var layer := CanvasLayer.new()
	layer.layer = TIP_LAYER
	add_child(layer)
	_tip_panel = PanelContainer.new()
	_tip_panel.theme_type_variation = &"TooltipPanel"
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_title = Label.new()
	_tip_body = Label.new()
	_tip_body.theme_type_variation = &"BodyLabel"
	for label: Label in [_tip_title, _tip_body]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # no autowrap: lines are wrapped by _wrap
		box.add_child(label)
	_tip_panel.add_child(box)
	layer.add_child(_tip_panel)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_tip_muted = _tip_target
		_set_tip(Tip.IDLE, null)


func _process(delta: float) -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	_update_hover_owner(hovered)
	_update_tip(_tip_source(hovered), delta)


## The custom control flagged `hover_fx` under the pointer (or its nearest such ancestor).
func _update_hover_owner(hovered: Control) -> void:
	var owner := hovered
	while owner != null and not (owner.has_meta(&"hover_fx") and &"hovered" in owner):
		owner = owner.get_parent() as Control
	if owner == _hover_owner:
		return
	if is_instance_valid(_hover_owner):
		_hover_owner.set(&"hovered", false)
	_hover_owner = owner
	if owner != null:
		owner.set(&"hovered", true)


func _update_tip(target: Control, delta: float) -> void:
	if target != _tip_muted:
		_tip_muted = null
	if get_viewport().gui_is_dragging() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) 			or (target != null and target == _tip_muted):
		_set_tip(Tip.IDLE, null)
		return
	match _tip_state:
		Tip.IDLE:
			if target != null:
				_set_tip(Tip.WAITING, target)
		Tip.WAITING:
			if target != _tip_target:
				_set_tip(Tip.WAITING if target != null else Tip.IDLE, target)
			else:
				_tip_timer += delta
				if _tip_timer >= REST_TIME:
					_set_tip(Tip.SHOWN, target)
		Tip.SHOWN:
			if target == null:
				_set_tip(Tip.GRACE, _tip_target)
			elif target != _tip_target:
				_set_tip(Tip.SHOWN, target)   # switch content at once, no new wait
		Tip.GRACE:
			if target != null:
				_set_tip(Tip.SHOWN, target)
			else:
				_tip_timer += delta
				if _tip_timer >= GRACE_TIME:
					_set_tip(Tip.IDLE, null)


func _set_tip(state: Tip, target: Control) -> void:
	var was_target := _tip_target
	_tip_state = state
	_tip_target = target
	_tip_timer = 0.0
	match state:
		Tip.IDLE, Tip.WAITING:
			_tip_panel.visible = false
		Tip.SHOWN:
			if target != was_target or not _tip_panel.visible:
				_show_tip(target)


## The hovered control, or the nearest ancestor, that carries a tip — or an info callable when
## no docked InfoPanel is visible to show it instead.
func _tip_source(c: Control) -> Control:
	var docked := _docked_info_visible()
	while c != null:
		if c.has_meta(&"tip"):
			return c
		if c.has_meta(&"info") and not docked:
			return c
		c = c.get_parent() as Control
	return null


func _docked_info_visible() -> bool:
	for panel: Node in get_tree().get_nodes_in_group(&"info_panel"):
		if (panel as CanvasItem).is_visible_in_tree():
			return true
	return false


func _show_tip(target: Control) -> void:
	var title := ""
	var body := ""
	if target.has_meta(&"tip"):
		title = str(target.get_meta(&"tip"))
	else:
		var info: Dictionary = (target.get_meta(&"info") as Callable).call()
		if info.is_empty():
			_tip_panel.visible = false
			return
		title = info.get("title", "")
		body = info.get("body", "")
	# Wrap by hand: autowrap Labels report a stale minimum height on their first layout
	# (skill godot-debugging-testing engine traps), which made the panel grow far too tall.
	var font := _tip_title.get_theme_font(&"font")
	var inner := TIP_MAX_W - 8.0
	_tip_title.text = _wrap(font, title, inner)
	_tip_body.text = _wrap(font, body, inner)
	_tip_body.visible = body != ""
	_tip_panel.reset_size()
	var size := _tip_panel.get_combined_minimum_size()
	var view := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var pos := mouse + TIP_OFFSET
	if pos.x + size.x > view.x - 2.0:
		pos.x = mouse.x - TIP_OFFSET.x - size.x
	if pos.y + size.y > view.y - 2.0:
		pos.y = mouse.y - TIP_OFFSET.y - size.y
	pos = pos.clamp(Vector2(2, 2), (view - size - Vector2(2, 2)).max(Vector2(2, 2)))
	_tip_panel.position = pos.round()
	_tip_panel.visible = true


## Greedy word wrap to `width` px at the 8 px pixel-font size.
static func _wrap(font: Font, text: String, width: float) -> String:
	var out: PackedStringArray = []
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" ", false):
			var trial := word if line == "" else line + " " + word
			if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > width:
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return "\n".join(out)
