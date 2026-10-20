class_name InfoPanel
extends PanelContainer
## Docked tooltip (ART_SPEC §6.1): shows the hovered control's info, or the last clicked one.
## Controls opt in with `InfoPanel.attach(control, callable)`; the callable returns an
## InfoText dictionary and is evaluated when shown, so content is never stale.
## Polls the hovered control each frame (no mouse_entered/exited flicker; skill
## godot-mobile-pixel-ui) — click / tap pins the info, so touch works without hover.

signal action_pressed(which: int)

const META := &"info"

var _pinned := {}
var _shown_for: Control
@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title
@onready var _kind: Label = %Kind
@onready var _body: Label = %Body
@onready var _action: Button = %Action
@onready var _action2: Button = %Action2


static func attach(control: Control, info: Callable) -> void:
	control.set_meta(META, info)
	if not control.has_meta(&"info_hooked"):
		control.set_meta(&"info_hooked", true)
		control.gui_input.connect(func(event: InputEvent) -> void: _pin_from(event, control))


## A click / tap pins the info on every visible panel (one per screen).
static func _pin_from(event: InputEvent, control: Control) -> void:
	if event is InputEventMouseButton and event.pressed:
		for panel: InfoPanel in control.get_tree().get_nodes_in_group(&"info_panel"):
			if panel.is_visible_in_tree():
				panel.pin(control.get_meta(META).call())


func _ready() -> void:
	add_to_group(&"info_panel")
	_action.pressed.connect(func() -> void: action_pressed.emit(0))
	_action2.pressed.connect(func() -> void: action_pressed.emit(1))
	clear()


func pin(info: Dictionary) -> void:
	_pinned = info
	_show(info)


func clear() -> void:
	_pinned = {}
	_shown_for = null
	_show({})


## Optional actions under the text (e.g. "USE", "SELL $1"); empty text hides a button.
func set_action(text: String, text2: String = "") -> void:
	_action.text = text
	_action.visible = text != ""
	_action2.text = text2
	_action2.visible = text2 != ""


func _process(_delta: float) -> void:
	var hovered := get_viewport().gui_get_hovered_control()
	var target := _find_target(hovered)
	if target == _shown_for:
		return
	_shown_for = target
	if target != null:
		_show(target.get_meta(META).call())
	else:
		_show(_pinned)


func _find_target(c: Control) -> Control:
	while c != null:
		if c.has_meta(META):
			return c
		c = c.get_parent() as Control
	return null


func _show(info: Dictionary) -> void:
	if info.is_empty():
		_icon.texture = null
		_title.text = ""
		_kind.text = ""
		var game := get_node_or_null("/root/Game")
		_body.text = game.db.text("info_empty") if game != null and game.db != null else ""
		return
	_icon.texture = info.get("icon")
	_title.text = info.get("title", "")
	_kind.text = info.get("kind", "")
	_body.text = info.get("body", "")
