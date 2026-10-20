class_name FaceTile
extends Control
## One die face in the Dice Inspector / dice strips (ART_SPEC §4.6 face_tile 16×16): tile,
## glyph8 centred, modifier badge top-right, G1 ring when selected. Custom-drawn, no theme.

signal pressed(die: int, face: int)

var die_index := -1
var face_index := -1
var face: Face
var selected := false:
	set(v):
		selected = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(16, 16)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func show_face(f: Face, die: int, index: int) -> void:
	face = f
	die_index = die
	face_index = index
	queue_redraw()


func _draw() -> void:
	draw_texture(Art.dice("face_tile"), Vector2.ZERO)
	if face == null:
		return
	draw_texture(Art.face_glyph(face, true), Vector2(4, 4))
	var badge := Art.modifier(face.modifier)
	if badge != null:
		draw_texture(badge, Vector2(11, 0))
	if selected:
		draw_rect(Rect2(0.5, 0.5, 15, 15), Art.colour("G1"), false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(die_index, face_index)
		accept_event()
