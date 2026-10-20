extends TestSuite
## DisplayFit: whole-number scale, design width, extra height on tall screens (D-A08).

const COVERS: Array[String] = ["core/display_fit.gd", "autoload/display.gd"]
const BASE := Vector2i(270, 480)


func _fit(w: int, h: int) -> Dictionary:
	return DisplayFit.fit(Vector2i(w, h), BASE, 640)


func test_default_window() -> void:
	_eq(_fit(540, 960), {"scale": 2, "size": Vector2i(270, 480)}, "540x960")


func test_tall_phone_gets_extra_height() -> void:
	_eq(_fit(1080, 2400), {"scale": 4, "size": Vector2i(270, 600)}, "20:9 phone")
	_eq(_fit(1170, 2532), {"scale": 4, "size": Vector2i(270, 633)}, "iPhone-class")


func test_landscape_desktop_letterboxes_sides() -> void:
	_eq(_fit(1920, 1080), {"scale": 2, "size": Vector2i(270, 540)}, "1080p window")


func test_height_cap_and_tiny_window() -> void:
	_eq(_fit(270, 1400), {"scale": 1, "size": Vector2i(270, 640)}, "capped height")
	_eq(_fit(200, 300), {"scale": 1, "size": Vector2i(270, 480)}, "never below base")
