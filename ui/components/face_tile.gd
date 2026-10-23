class_name FaceTile
extends Control
## One die face in the Dice Inspector / dice strips (ART_SPEC §4.6, 16×16): the face tile in
## its rune's material, glyph8 at (2, 2), points digit bottom-right, G1 ring when selected
## (with the pick order for ordered potions). Custom-drawn, no theme.

signal pressed(die: int, face: int)

var die_index := -1
var face_index := -1
var face: Face
var order := 0          # 1-based pick order shown when > 0
var show_points := true
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var hovered := false:
	set(v):
		hovered = v
		queue_redraw()
var _font: Font


func _init() -> void:
	custom_minimum_size = Vector2(16, 16)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_meta(&"press_fx", true)
	set_meta(&"hover_fx", true)


func _ready() -> void:
	_font = load("res://assets/fonts/fusion_pixel/fusion_pixel_8px.otf")


func show_face(f: Face, die: int, index: int) -> void:
	face = f
	die_index = die
	face_index = index
	queue_redraw()


func _draw() -> void:
	draw_texture(Art.face_tile(face), Vector2.ZERO)
	if face == null:
		return
	var g := Art.face_glyph(face, true)
	if g != null:
		draw_texture(g, Vector2(2, 2))
	if show_points and not face.is_tomb() and _font != null:
		draw_string_outline(_font, Vector2(10, 15), str(face.points), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2,
			Art.colour("N0"))
		draw_string(_font, Vector2(10, 15), str(face.points), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Art.colour("N7"))
	if selected:
		Art.draw_ring(self, Rect2(Vector2.ZERO, size), Art.colour("G1"))
		if order > 0 and _font != null:
			draw_string(_font, Vector2(1, 7), str(order), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Art.colour("G1"))
	elif hovered:
		Art.draw_ring(self, Rect2(Vector2.ZERO, size), Art.colour("N5"))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(die_index, face_index)
		accept_event()
