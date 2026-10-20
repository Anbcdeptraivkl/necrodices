extends TestSuite
## Project settings required by ART_SPEC §2 / GAME_SPEC D-03.

const COVERS: Array[String] = ["project.godot", "ui/theme/", "assets/fonts/"]


func test_virtual_resolution() -> void:
	_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 480, "viewport width")
	_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 270, "viewport height")
	_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport", "stretch mode")
	_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 0, "landscape")
	_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer", "integer scale")
	# expand + integer is godot#92055; tall screens are handled by DisplayFit (D-A08).
	_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep", "aspect keep")


func test_pixel_filtering() -> void:
	# Project setting enum: 0 Nearest (differs from CanvasItem.TextureFilter).
	_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "nearest filter")
	_check(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"), "snap transforms")
	_check(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel"), "snap vertices")


func test_web_compatible_renderer() -> void:
	_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "renderer")


func test_pixel_font() -> void:
	var theme: Theme = load("res://ui/theme/pixel_theme.tres")
	_check(theme.default_font != null and theme.default_font.resource_path.ends_with("fusion_pixel_8px.otf"), "theme font is Fusion Pixel 8 px")
	var font: FontFile = load("res://assets/fonts/fusion_pixel/fusion_pixel_12px.otf")
	_eq(font.antialiasing, TextServer.FONT_ANTIALIASING_NONE, "font imported without antialiasing")
	_check(not font.allow_system_fallback, "no system fallback")
