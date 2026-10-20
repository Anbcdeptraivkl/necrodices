class_name HpBar
extends Control
## Enemy HP bar (ART_SPEC §6.2, §7): hp_frame 9-slice, R1 fill tiled, projected damage as a G1
## segment taken from the right end of the remaining HP. `shown_hp` is tweened by playback.

var max_hp := 1.0:
	set(v):
		max_hp = maxf(1.0, v)
		queue_redraw()
var shown_hp := 1.0:
	set(v):
		shown_hp = clampf(v, 0.0, max_hp)
		queue_redraw()
var projected := 0.0:
	set(v):
		projected = maxf(0.0, v)
		queue_redraw()

var _frame: StyleBoxTexture


func _ready() -> void:
	_frame = StyleBoxTexture.new()
	_frame.texture = Art.ui("hp_frame")
	_frame.set_texture_margin_all(3)


func _draw() -> void:
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var inner := Rect2(1, 1, size.x - 2, size.y - 2)
	var hp_w := floorf(inner.size.x * shown_hp / max_hp)
	if hp_w > 0:
		draw_texture_rect(Art.ui("hp_fill"), Rect2(inner.position, Vector2(hp_w, inner.size.y)), true)
	var preview_w := minf(hp_w, ceilf(inner.size.x * minf(projected, shown_hp) / max_hp))
	if preview_w > 0:
		draw_texture_rect(Art.ui("hp_preview"),
			Rect2(inner.position + Vector2(hp_w - preview_w, 0), Vector2(preview_w, inner.size.y)), true)
