extends TestSuite
## Content loads, validates and resolves recipes (GAME_SPEC §5.1, §6).

const COVERS: Array[String] = ["data/", "core/db.gd", "core/json_util.gd", "scenes/", "ui/"]


func _db() -> ContentDb:
	var db := ContentDb.new()
	_check(db.load_all(), "data loads: %s" % [db.errors])
	return db


func test_counts() -> void:
	var db := _db()
	_eq(db.units.size(), 19, "units")
	_eq(db.relics.size(), 25, "relics")
	_eq(db.consumables.size(), 18, "consumables")
	_eq(db.equipment.size(), 8, "equipment")
	_eq(db.enemies.size(), 9, "enemies")


func test_pair_matrix() -> void:
	var db := _db()
	_eq(db.recipes[ContentDb.recipe_key(["METAL", "BONE"])], "SHIELD_SKELETON", "BONE+METAL")
	_eq(db.recipes[ContentDb.recipe_key(["ICE", "FIRE"])], "STEAM_SLIME", "FIRE+ICE")
	_eq(db.recipes[ContentDb.recipe_key(["VOLT", "LEAF"])], "WISP", "LEAF+VOLT is wisp")
	_eq(db.recipes[ContentDb.recipe_key(["VOLT", "LEAF", "ICE"])], "WITCH_QUEEN", "ICE+LEAF+VOLT")
	_check(not db.recipes.has(ContentDb.recipe_key(["FIRE", "FIRE", "FIRE"])), "invalid triple")


func test_whole_numbers_are_ints() -> void:
	var db := _db()
	_eq(typeof(db.relics["RATTLE_DRUM"]["price"]), TYPE_INT, "price narrowed to int")
	_eq(typeof(db.economy["modifiers"]["HEX"]["value"]), TYPE_FLOAT, "1.5 stays float")


## Every literal key passed to db.text("...") in game code exists in strings_en.json, so no UI
## text falls back to its key.
func test_every_text_key_exists() -> void:
	var db := _db()
	var re := RegEx.create_from_string(r'text\("([a-z0-9_]+)"\)')
	for path in _gd_files("res://"):
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			_check(db.strings.has(m.get_string(1)), "%s: string key %s" % [path, m.get_string(1)])


func _gd_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_gd_files(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
