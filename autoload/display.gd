extends Node
## Keeps the root window's canvas at a whole-number scale, grown to fill the window up to
## MAX_SIZE (DisplayFit). Applied on start and on every resize, so every
## scene (including dev sandboxes) gets the same canvas.

## Largest canvas in virtual px (ART_SPEC §2): 640 wide covers 21:9, 300 tall covers 16:10.
const MAX_SIZE := Vector2i(640, 300)

var scale := 1
var canvas_size := Vector2i(480, 270)


func _ready() -> void:
	get_window().size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var base := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var result := DisplayFit.fit(get_window().size, base, MAX_SIZE)
	scale = result["scale"]
	canvas_size = result["size"]
	get_window().content_scale_size = canvas_size
