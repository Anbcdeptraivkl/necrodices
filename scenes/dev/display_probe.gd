extends Control
## Dev probe: prints the window size, integer scale and canvas the Display autoload picked,
## then quits. Usage: godot --path . --resolution 540x1200 res://scenes/dev/display_probe.tscn


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var display := get_node("/root/Display")
	print("window=%s scale=%d canvas=%s visible=%s" % [get_window().size, display.get("scale"),
		display.get("canvas_size"), get_viewport().get_visible_rect().size])
	get_tree().quit()
