class_name CodexCell
extends Control
## One entry in a Codex grid (ART_SPEC §6.6): a 34×34 cell with the entry's art drawn at an
## integer scale (16 px icons ×2, 32 px sprites ×1), a kind-coloured ring, N5 ring on hover and
## G1 when selected. Custom-drawn; emits `picked(key)` on hover and on click.

signal picked(key: String, pinned: bool)

const SIZE := Vector2(34, 34)

var key := ""
var texture: Texture2D
var ring := Color(0, 0, 0, 0)
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var hovered := false:
	set(v):
		hovered = v
		queue_redraw()
		if v:
			picked.emit(key, false)


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_meta(&"hover_fx", true)
	set_meta(&"press_fx", true)


func show_entry(p_key: String, tex: Texture2D, p_ring: Color) -> void:
	key = p_key
	texture = tex
	ring = p_ring
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Art.colour("N1"))
	if texture != null:
		var s := texture.get_size()
		var k := maxf(1.0, floorf(32.0 / maxf(s.x, s.y)))
		var at := ((SIZE - s * k) / 2.0).floor()
		draw_texture_rect(texture, Rect2(at, s * k), false)
	var edge := Art.colour("G1") if selected else (Art.colour("N5") if hovered else ring)
	if edge.a > 0.0:
		Art.draw_ring(self, Rect2(Vector2.ZERO, SIZE), edge)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(key, true)
		accept_event()
