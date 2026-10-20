class_name ItemSlot
extends Control
## A 20×20 slot (ART_SPEC §7 slot.png) holding a 16×16 icon: relic, consumable or empty.
## Relic slots support drag-to-reorder through Godot's drag-and-drop API; the owner turns
## dragging off during combat playback and applies the move with one command on drop.
## A disabled relic (Witch Hunter) gets the N0 checker dim (ART_SPEC §6.2).

signal pressed(index: int)
signal reorder_requested(from: int, to: int)

const DRAG_KIND := "relic_slot"

var index := -1
var draggable := false
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()
var icon: Texture2D:
	set(v):
		icon = v
		queue_redraw()
## Horizontal icon offset in px, tweened by playback to shake a relic that fires.
var shake := 0.0:
	set(v):
		shake = v
		queue_redraw()


func _draw() -> void:
	draw_texture(Art.ui("slot_selected" if selected else "slot"), Vector2.ZERO)
	if icon != null:
		var at := ((size - icon.get_size()) / 2.0).floor() + Vector2(roundf(shake), 0)
		draw_texture(icon, at)
	if dimmed:
		var dark := Art.colour("N0")
		for y in range(1, 19):
			for x in range(1 + (y % 2), 19, 2):
				draw_rect(Rect2(x, y, 1, 1), dark)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(index)


func _get_drag_data(_at: Vector2) -> Variant:
	if not draggable or icon == null:
		return null
	var preview := TextureRect.new()
	preview.texture = icon
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_drag_preview(preview)
	return {"kind": DRAG_KIND, "index": index, "owner": get_parent()}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return draggable and typeof(data) == TYPE_DICTIONARY and data.get("kind") == DRAG_KIND \
		and data.get("owner") == get_parent() and data["index"] != index and index >= 0


func _drop_data(_at: Vector2, data: Variant) -> void:
	reorder_requested.emit(data["index"], index)
