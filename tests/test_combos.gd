extends TestSuite
## Combo detection (GAME_SPEC §4.3–§4.4): every pattern, scored dice, units, TOMB and WILD.

const COVERS: Array[String] = ["core/combos.gd", "core/db.gd", "data/combos.json", "data/units.json"]


func _detect(specs: Array) -> Dictionary:
	return Combos.detect(Fixtures.db(), Fixtures.faces(specs))


func _case(specs: Array, combo: String, scored: Array, unit: String) -> void:
	var m := _detect(specs)
	_eq(m["combo"], combo, "%s combo" % [specs])
	_eq(Array(m["scored"]), scored, "%s scored" % [specs])
	_eq(m["unit"], unit, "%s unit" % [specs])


func test_patterns() -> void:
	_case(["FIRE1", "FIRE2", "FIRE3", "ICE4"], "TRIO", [0, 1, 2], "FIRE_IMP")
	_case(["BONE", "FIRE2", "BONE", "LEAF1"], "RITUAL", [0, 1, 2, 3], "HEADLESS_HORSEMAN")
	_case(["ICE1", "LEAF2", "ICE3", "LEAF4"], "DUO_PACT", [0, 1, 2, 3], "BOG_WITCH")
	_case(["FIRE1", "FIRE2", "VOLT3", "VOLT4"], "DUO_PACT", [0, 1, 2, 3], "WISP")
	_case(["FIRE1", "ICE2", "FIRE3", "ICE4", "FIRE5"], "FULL_MOON", [0, 1, 2, 3, 4], "STEAM_SLIME")
	_case(["LEAF1", "LEAF2", "LEAF3", "VOLT4", "VOLT5"], "FULL_MOON", [0, 1, 2, 3, 4], "PUMPKINLING")
	_case(["BONE", "FIRE1", "ICE2", "LEAF3", "VOLT4"], "RAINBOW", [0, 1, 2, 3, 4], "PHANTOM_PARADE")
	_case(["METAL1", "METAL2", "FIRE5", "METAL3", "METAL4"], "QUARTET", [0, 1, 3, 4], "GARGOYLE")
	_case(["VOLT1", "VOLT2", "VOLT3", "VOLT4", "VOLT5"], "QUINTET", [0, 1, 2, 3, 4], "STORM_TITAN")
	_case(["FIRE1", "ICE5", "LEAF2"], "RABBLE", [1], "WISP")


func test_ritual_needs_the_core_twice() -> void:
	_eq(_detect(["BONE", "FIRE1", "LEAF2", "VOLT3"])["combo"], "RABBLE", "BONE FIRE LEAF without a 2nd BONE")
	_case(["VOLT1", "BONE", "METAL2", "VOLT3"], "RITUAL", [0, 1, 2, 3], "STITCHED_GOLEM")
	_case(["METAL1", "FIRE2", "ICE3", "METAL4", "LEAF5"], "RITUAL", [0, 1, 2, 3], "CLOCKWORK_KRAKEN")


func test_tomb_always_scores_and_has_no_element() -> void:
	_case(["FIRE1", "FIRE2", "FIRE3", "TOMB"], "TRIO", [0, 1, 2, 3], "FIRE_IMP")
	var m := _detect(["TOMB", "TOMB", "ICE2"])
	_eq(m["combo"], "RABBLE", "two tombs are no pair")
	_eq(Array(m["scored"]), [0, 1, 2], "tombs + the one die")


func test_wild_takes_the_best_combo() -> void:
	_eq(_detect(["FIRE1", "FIRE2", "ICE3+WILD", "FIRE4"])["combo"], "QUARTET", "wild completes a quartet")
	_eq(_detect(["BONE", "FIRE1", "LEAF2", "VOLT3+WILD"])["unit"], "HEADLESS_HORSEMAN", "wild is the 2nd core")
	_eq(_detect(["BONE", "FIRE1", "ICE2", "LEAF3", "FIRE4+WILD"])["combo"], "RITUAL", "wild = 2nd BONE beats rainbow")
	_eq(_detect(["BONE", "FIRE1", "ICE2", "VOLT3", "METAL4+WILD"])["combo"], "RAINBOW", "wild turns LEAF")
	var m := _detect(["ICE1+WILD", "ICE2+WILD", "ICE3+WILD"])
	_eq(m["combo"], "TRIO", "three wilds: a trio")
	_eq(m["elements"][0], "BONE", "ties go to the lowest element")


func test_rabble_wisp_tint() -> void:
	var m := _detect(["LEAF1", "VOLT2", "LEAF3"])
	_eq(m["combo"], "RABBLE", "a pair is a rabble")
	_eq(Array(m["unit_elements"]), ["LEAF", "VOLT"], "most common first")
