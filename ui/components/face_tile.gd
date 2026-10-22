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
var hovered := false:
	set(v):
		hovered = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(16, 16)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_meta(&"press_fx", true)
	set_meta(&"hover_fx", true)


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
		Art.draw_ring(self, Rect2(Vector2.ZERO, size), Art.colour("G1"))
	elif hovered:
		Art.draw_ring(self, Rect2(Vector2.ZERO, size), Art.colour("N5"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(die_index, face_index)
		accept_event()
