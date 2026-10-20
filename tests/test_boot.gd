extends TestSuite
## The title scene instantiates with the placeholder art and theme, without script errors.

const COVERS: Array[String] = ["scenes/title/", "scenes/boot/", "ui/theme/", "autoload/"]


func test_title_instantiates() -> void:
	var packed: PackedScene = load("res://scenes/title/title.tscn")
	_check(packed != null, "title scene loads")
	var title: Control = packed.instantiate()
	tree.root.add_child(title)
	await tree.process_frame
	_eq((title.get_node("%NewRun") as Button).size, Vector2(140, 24), "menu button size")
	_eq((title.get_node("%Settings") as Button).global_position, Vector2(170, 188), "settings button at ART §6.5 rect (base canvas)")
	title.queue_free()
	await tree.process_frame


func test_boot_scene_is_preload_free() -> void:
	for line in FileAccess.get_file_as_string("res://scenes/boot/boot.gd").split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		_check(not line.contains("preload("), "boot.gd has no preload: %s" % line)
		_check(not line.begins_with("class_name"), "boot.gd declares no class_name")
