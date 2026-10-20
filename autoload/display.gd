extends Node
## Keeps the root window's canvas at a whole-number scale with the design width and as much
## height as the screen allows (DisplayFit). Applied on start and on every resize, so every
## scene (including dev sandboxes) gets the same canvas.

## Tallest canvas, in virtual px (ART_SPEC §2: extra height goes to the battlefield).
const MAX_HEIGHT := 640

var scale := 1
var canvas_size := Vector2i(270, 480)


func _ready() -> void:
	get_window().size_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var base := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var result := DisplayFit.fit(get_window().size, base, MAX_HEIGHT)
	scale = result["scale"]
	canvas_size = result["size"]
	get_window().content_scale_size = canvas_size
