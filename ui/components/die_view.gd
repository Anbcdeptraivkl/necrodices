class_name DieView
extends Control
## One tray die (ART_SPEC §4.6): body + face glyph at (4, 3) + modifier badge at (14, 1),
## select ring (raised 3 px), bound ring tinted with the group colour, shackle overlay.
## Shows state; clicking emits `pressed(index)` — the screen decides what it means.

signal pressed(index: int)

const RAISE := 3
const ROLL_FRAME_TIME := 0.05

var index := -1
var _rolling := 0.0
@onready var _face: Control = %Face
@onready var _body: TextureRect = %Body
@onready var _glyph: TextureRect = %Glyph
@onready var _mod: TextureRect = %Mod
@onready var _select: TextureRect = %Select
@onready var _bound: TextureRect = %Bound
@onready var _shackle: TextureRect = %Shackle


func _ready() -> void:
	_body.texture = Art.dice("die_body")
	_select.texture = Art.dice("die_select")
	_bound.texture = Art.dice("die_bound")
	_shackle.texture = Art.dice("die_shackle")
	set_process(false)


func show_state(face: Face, selected: bool, bound_group: int, shackled: bool) -> void:
	_glyph.texture = Art.face_glyph(face)
	_mod.texture = Art.modifier(face.modifier)
	_select.visible = selected
	_bound.visible = bound_group >= 0
	if bound_group >= 0:
		_bound.self_modulate = Art.group_colour(bound_group)
	_shackle.visible = shackled
	_face.position.y = 0 if selected else RAISE
	mouse_default_cursor_shape = Control.CURSOR_ARROW if shackled or bound_group >= 0 else Control.CURSOR_POINTING_HAND


## Tumble frames for `duration` seconds (4 × 50 ms at ×1), then the face lands.
func play_roll(duration: float) -> void:
	_rolling = duration
	_glyph.visible = false
	_mod.visible = false
	set_process(true)


func finish_roll() -> void:
	_rolling = 0.0
	_body.texture = Art.dice("die_body")
	_glyph.visible = true
	_mod.visible = true
	set_process(false)


func _process(delta: float) -> void:
	_rolling -= delta
	if _rolling <= 0.0:
		finish_roll()
		return
	var f := int(_rolling / ROLL_FRAME_TIME) % 4
	_body.texture = Art.frame("res://assets/sprites/dice/die_roll.png", 20, f)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(index)
		accept_event()
