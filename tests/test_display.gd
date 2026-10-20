extends TestSuite
## DisplayFit: whole-number scale, canvas grown on either axis up to the cap (D-A08).

const COVERS: Array[String] = ["core/display_fit.gd", "autoload/display.gd"]
const BASE := Vector2i(480, 270)
const MAX := Vector2i(640, 300)


func _fit(w: int, h: int) -> Dictionary:
	return DisplayFit.fit(Vector2i(w, h), BASE, MAX)


func test_itch_embed_and_fullscreen_16_9() -> void:
	_eq(_fit(960, 540), {"scale": 2, "size": Vector2i(480, 270)}, "960x540 embed")
	_eq(_fit(1920, 1080), {"scale": 4, "size": Vector2i(480, 270)}, "1080p fullscreen")
	_eq(_fit(3840, 2160), {"scale": 8, "size": Vector2i(480, 270)}, "4K")


func test_other_aspects_grow_the_canvas() -> void:
	_eq(_fit(1920, 1200), {"scale": 4, "size": Vector2i(480, 300)}, "16:10")
	_eq(_fit(2560, 1080), {"scale": 4, "size": Vector2i(640, 270)}, "21:9")
	_eq(_fit(1366, 768), {"scale": 2, "size": Vector2i(640, 300)}, "1366x768 capped both ways")
	_eq(_fit(2400, 1080), {"scale": 4, "size": Vector2i(600, 270)}, "20:9 phone landscape")


func test_tiny_window_never_below_base() -> void:
	_eq(_fit(400, 200), {"scale": 1, "size": Vector2i(480, 270)}, "tiny window")
