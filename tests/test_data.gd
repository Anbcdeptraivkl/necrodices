extends TestSuite
## Content loads and validates (GAME_SPEC §6, §9); every UI string key exists.

const COVERS: Array[String] = ["data/", "core/db.gd", "core/json_util.gd", "core/rules_registry.gd",
	"scenes/", "ui/", "fx/"]


func _db() -> ContentDb:
	var db := ContentDb.new()
	_check(db.load_all(), "data loads: %s" % [db.errors])
	return db


func test_counts() -> void:
	var db := _db()
	_eq(db.units.size(), 32, "units")
	_eq(db.combos.size(), 8, "combos")
	_eq(db.rituals.size(), 4, "rituals")
	_eq(db.relics.size(), 30, "trinkets")
	_eq(db.ids_of_kind(db.consumables, "POTION").size(), 17, "potions")
	_eq(db.ids_of_kind(db.consumables, "GEM").size(), 8, "gems")
	_eq(db.coffers.size(), 12, "coffers")
	_eq(db.equipment.size(), 13, "gear")
	_eq(db.enemies.size(), 9, "hunters")


func test_unit_tables() -> void:
	var db := _db()
	_eq(db.unit_for("T1", "ICE"), "FROST_BAT", "ice trio")
	_eq(db.unit_for("ELITE", "BONE"), "LICH", "bone quartet")
	_eq(db.unit_for("LEGEND", "LEAF"), "ELDER_HOLLOW", "leaf quintet")
	_eq(db.hybrid_for("METAL", "BONE"), "SHIELD_SKELETON", "hybrid key is order-free")
	_eq(db.hybrid_for("FIRE", "VOLT"), "", "no hybrid")


func test_whole_numbers_are_ints() -> void:
	var db := _db()
	_eq(typeof(db.relics["RATTLE_DRUM"]["price"]), TYPE_INT, "price narrowed to int")
	_eq(typeof(db.economy["runes"]["IRON"]["value"]), TYPE_FLOAT, "1.5 stays float")


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
