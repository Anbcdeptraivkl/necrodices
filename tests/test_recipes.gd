extends TestSuite
## Recipe table and WILD resolution (GAME_SPEC §5.1, §5.2, §6.3, §6.4), content registry.

const COVERS: Array[String] = ["core/recipes.gd", "core/rules_registry.gd", "core/db.gd", "data/"]


func test_pair_matrix_matches_spec() -> void:
	var db := Fixtures.db()
	var expected := {
		"BONE+BONE": "SKELETON_WARRIOR", "BONE+FIRE": "FLAME_SKULL", "BONE+ICE": "WISP",
		"BONE+LEAF": "SCARECROW", "BONE+VOLT": "WISP", "BONE+METAL": "SHIELD_SKELETON",
		"FIRE+FIRE": "FIRE_IMP", "FIRE+ICE": "STEAM_SLIME", "FIRE+LEAF": "JACK_O_LANTERN",
		"FIRE+VOLT": "WISP", "FIRE+METAL": "WISP", "ICE+ICE": "FROST_BAT", "ICE+LEAF": "BOG_WITCH",
		"ICE+VOLT": "STORM_BANSHEE", "ICE+METAL": "WISP", "LEAF+LEAF": "PUMPKINLING",
		"LEAF+VOLT": "WISP", "LEAF+METAL": "WISP", "VOLT+VOLT": "VOLT_GHOST",
		"VOLT+METAL": "TESLA_SPIDER", "METAL+METAL": "HAUNTED_ARMOR",
	}
	for key: String in expected:
		var res := Recipes.resolve(db, Fixtures.faces(key.split("+")), {})
		_eq(res.get("unit", ""), expected[key], key)


func test_triples() -> void:
	var db := Fixtures.db()
	var valid := 0
	var invalid := 0
	var els := RulesRegistry.ELEMENTS
	for a in els.size():
		for b in range(a, els.size()):
			for c in range(b, els.size()):
				var res := Recipes.resolve(db, Fixtures.faces([els[a], els[b], els[c]]), {})
				if res.is_empty():
					invalid += 1
				else:
					valid += 1
	_eq(valid, 4, "valid triples")
	_eq(invalid, 52, "invalid triples")


func test_tray_order_does_not_matter() -> void:
	var res := Recipes.resolve(Fixtures.db(), Fixtures.faces(["LEAF", "BONE", "FIRE"]), {})
	_eq(res.get("unit", ""), "HEADLESS_HORSEMAN", "LEAF+BONE+FIRE")
	_eq(res["elements"], PackedStringArray(["LEAF", "BONE", "FIRE"]), "elements keep tray order")


func test_wild_prefers_t3() -> void:
	var db := Fixtures.db()
	var res := Recipes.resolve(db, Fixtures.faces(["BONE", "BONE", "FIRE+WILD"]), {})
	_eq(res.get("unit", ""), "LICH", "BONE BONE WILD → Lich")
	_eq(res["elements"][2], "BONE", "wild resolved to BONE")
	var pair := Recipes.resolve(db, Fixtures.faces(["ICE", "METAL+WILD"]), {})
	# Best ICE pair by P×C at level 1: Storm Banshee 22×2=44 vs Bog Witch 12×3=36 vs Steam Slime 40.
	_eq(pair.get("unit", ""), "STORM_BANSHEE", "ICE + WILD → best tier-2 pair")


func test_wild_tie_breaks_by_table_index() -> void:
	# Two wilds: best is T2 by P×C; ensure deterministic result twice.
	var db := Fixtures.db()
	var a := Recipes.resolve(db, Fixtures.faces(["BONE+WILD", "BONE+WILD"]), {})
	var b := Recipes.resolve(db, Fixtures.faces(["BONE+WILD", "BONE+WILD"]), {})
	_eq(a, b, "deterministic")
	_eq(db.unit_tier(a["unit"]), "T2", "two wilds make a T2 pair")


func test_registry_accepts_all_content() -> void:
	_eq(RulesRegistry.validate(Fixtures.db()), PackedStringArray(), "no registry errors")


func test_registry_rejects_unknown_names() -> void:
	var db := ContentDb.new()
	db.load_all()
	db.relics["RATTLE_DRUM"] = db.relics["RATTLE_DRUM"].duplicate(true)
	db.relics["RATTLE_DRUM"]["cond"] = {"type": "group_is_spooky"}
	db.relics["EMBER_JAR"] = db.relics["EMBER_JAR"].duplicate(true)
	db.relics["EMBER_JAR"]["effects"] = [{"op": "add_money", "value": 1}]
	var errors := RulesRegistry.validate(db)
	_check(errors.size() >= 2, "bad condition and illegal op reported: %s" % [errors])


func test_every_scoring_term_is_used() -> void:
	var db := Fixtures.db()
	var used := {}
	for id: String in db.relics:
		var row: Dictionary = db.relics[id]
		for block: Dictionary in RulesRegistry.relic_blocks(row):
			used[block["cond"]["type"]] = true
			for e: Dictionary in block["effects"]:
				used[e["op"]] = true
		if row.has("counter"):
			used[row["counter"]["cond"]["type"]] = true
	for cond: String in RulesRegistry.CONDS:
		_check(used.has(cond), "condition %s used by some relic" % cond)
	for op in RulesRegistry.OPS:
		_check(used.has(op), "op %s used by some relic" % op)
