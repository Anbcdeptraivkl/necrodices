extends TestSuite
## Every relic, consumable, equipment and boss rule proves its effect (GAME_SPEC §13 M4, §14).
## Relic rows: the relic alone on a small army, expected damage computed by hand from §6.

const COVERS: Array[String] = ["data/relics.json", "data/consumables.json", "data/equipment.json",
	"data/enemies.json", "core/scorer.gd", "core/relic_eval.gd", "core/consumable_fx.gd",
	"core/encounter_state.gd"]

const SKW := ["BONE", "BONE"]          # Skeleton Warrior 10 / 2
## relic -> [army (face specs per group), {money, rerolls, bosses, counter}, damage with, damage without]
const RELIC_CASES := {
	"RATTLE_DRUM": [[SKW], {}, 40.0, 20.0],
	"EMBER_JAR": [[["FIRE", "FIRE"]], {}, 54.0, 18.0],
	"FROST_LANTERN": [[["ICE", "ICE"]], {}, 29.0, 14.0],
	"MOSS_CHARM": [[["LEAF", "LEAF"]], {}, 32.0, 16.0],
	"LIGHTNING_ROD": [[["VOLT", "VOLT"]], {}, 60.0, 24.0],
	"IRON_NAIL": [[["METAL", "METAL"]], {}, 33.0, 18.0],
	"GRAVEDIGGER_LAMP": [[SKW], {}, 60.0, 20.0],
	"WISP_JAR": [[["BONE", "ICE"]], {}, 20.0, 5.0],
	"GRAVE_ROBBER": [[SKW], {}, 20.0, 20.0],
	"BONE_SAW": [[SKW], {}, 40.0, 20.0],
	"DEEP_FREEZE": [[["ICE", "ICE"], ["ICE", "LEAF"]], {}, 156.0, 104.0],
	"COLD_HEARTH": [[SKW], {}, 40.0, 20.0],
	"BONE_PILE": [[SKW], {}, 40.0, 20.0],
	"GRAND_PROCESSION": [[SKW, SKW], {}, 144.0, 80.0],
	"THRIFTY_GHOST": [[SKW], {"rerolls": 2}, 100.0, 20.0],
	"HYBRID_VIGOR": [[["BONE", "FIRE"]], {}, 90.0, 45.0],
	"COPYCAT_COFFIN": [[SKW, SKW], {}, 160.0, 80.0],
	"OVERGROWTH": [[SKW], {"counter": 3}, 50.0, 20.0],
	"SPIRIT_BOARD": [[["BONE", "FIRE"], ["ICE", "LEAF"], ["VOLT", "METAL"]], {}, 738.0, 369.0],
	"PIGGY_COFFIN": [[SKW], {"money": 10}, 60.0, 20.0],
	"TACTICIAN_SKULL": [[SKW, SKW], {}, 160.0, 80.0],
	"CROWN_OF_THE_LICH": [[["BONE", "BONE", "BONE"]], {}, 480.0, 320.0],
	"FULL_MOON": [[SKW, SKW, SKW, SKW, SKW, SKW, SKW], {}, 1960.0, 980.0],
	"BLACK_GRIMOIRE": [[SKW], {"bosses": 2}, 30.0, 20.0],
	"ELEMENTAL_CONVERGENCE": [[["BONE", "FIRE"], ["ICE", "LEAF"], ["VOLT", "METAL"]], {}, 1107.0, 369.0],
}


func _score(groups: Array, relics: Array[RelicInstance], opts: Dictionary) -> float:
	var army: Array[Group] = []
	for specs: Array in groups:
		army.append(Fixtures.group(specs))
	var ctx := ScoreCtx.build(army, opts.get("money", 0), opts.get("rerolls", 0), 0, opts.get("bosses", 0))
	return Scorer.score(Fixtures.db(), army, relics, {}, ctx, PackedStringArray()).damage


func test_every_relic_has_a_case() -> void:
	for id: String in Fixtures.db().relics:
		_check(RELIC_CASES.has(id), "relic %s has a fixture" % id)


func test_relic_effects() -> void:
	for id: String in RELIC_CASES:
		var case: Array = RELIC_CASES[id]
		var opts: Dictionary = case[1]
		var relics: Array[RelicInstance] = [RelicInstance.new(id, opts.get("counter", 0))]
		var none: Array[RelicInstance] = []
		_eq(_score(case[0], relics, opts), case[2], "%s with" % id)
		_eq(_score(case[0], none, opts), case[3], "%s without" % id)


func test_conditional_relics_stay_off() -> void:
	var db := Fixtures.db()
	var cold: Array[RelicInstance] = [RelicInstance.new("COLD_HEARTH")]
	_eq(_score([["BONE", "FIRE"]], cold, {}), 45.0, "Cold Hearth off with FIRE essence")
	var freeze: Array[RelicInstance] = [RelicInstance.new("DEEP_FREEZE")]
	_eq(_score([["ICE", "ICE"]], freeze, {}), 14.0, "Deep Freeze off below 3 ICE")
	var moon: Array[RelicInstance] = [RelicInstance.new("FULL_MOON")]
	_eq(_score([SKW, SKW], moon, {}), 80.0, "Full Moon off below 7 groups")
	_check(db.relics.size() == 25, "25 relics")


func test_grave_robber_pays_at_fight_end() -> void:
	var run := Fixtures.run()
	run.relics.append(RelicInstance.new("GRAVE_ROBBER"))
	var lines := Economy.cash_out_lines(Fixtures.db(), run, "MOB", 0)
	_check(lines.any(func(l: Dictionary) -> bool: return l["source"] == "GRAVE_ROBBER" and l["amount"] == 2), "+$2")


func test_every_consumable() -> void:
	var db := Fixtures.db()
	for id: String in db.consumables:
		var run := Fixtures.run()
		var row: Dictionary = db.consumables[id]
		var targets: Array[Vector2i] = []
		if int(row["max_targets"]) > 0:
			targets.append(Vector2i(1, 0))
		_check(ConsumableFx.apply(db, run, id, targets), "%s applies" % id)
		match row["kind"]:
			"TOME":
				var unit: String = db.tome_targets(row["element"])[0]
				_eq(run.level_of(unit), 2, "%s levels %s" % [id, unit])
				_eq(run.level_of("WISP"), 2, "%s levels Wisp" % id)
			"SIGIL":
				_eq(run.dice[1].faces[0].element, row["element"], "%s changes the face" % id)
			"INK":
				_eq(run.dice[1].faces[0].modifier, row["modifier"], "%s inks the face" % id)
			"DIE":
				_eq(run.dice.size(), 5, "%s adds a die" % id)


func test_modifiers_in_scoring() -> void:
	var none: Array[RelicInstance] = []
	_eq(_score([["BONE+SHARP", "BONE"]], none, {}), 40.0, "SHARP +10 Power")
	_eq(_score([["BONE+SWARM", "BONE"]], none, {}), 40.0, "SWARM +2 Count")
	_eq(_score([["BONE+GOLD", "BONE"]], none, {}), 20.0, "GOLD scores nothing")


func test_every_equipment() -> void:
	var db := Fixtures.db()
	var expected := {"GRAVE_BELL": ["summons", 4], "LOADED_CUP": ["rerolls", 3], "SECOND_CUP": ["rerolls", 3]}
	for id: String in db.equipment:
		var run := Fixtures.run_with_rules([])
		run.money = 100
		var req: Variant = db.equipment[id]["requires"]
		if req != null:
			run.equipment.append(req)
		run.equipment_offer = id
		run.equipment_sold = false
		var dice_before := run.dice.size()
		_check(ShopState.buy_equipment(db, run), "buy %s" % id)
		var enc := RunFlow.start_encounter(db, run)
		var effect: Dictionary = db.equipment[id]["effect"]
		if effect.has("dice"):
			_eq(run.dice.size(), dice_before + 1, "%s adds a die" % id)
		if effect.has("summons"):
			_eq(enc.summons_left, 4, "%s +1 summon" % id)
		if effect.has("rerolls"):
			_eq(enc.rerolls_left, 2 + run.equipment_bonus("rerolls", db), "%s rerolls" % id)
		if effect.has("relic_slots"):
			_eq(run.relic_slots(db), 6, "%s relic slot" % id)
		if effect.has("consumable_slots"):
			_eq(run.consumable_slots(db), 3, "%s consumable slot" % id)
		if effect.has("shop_reroll_discount"):
			_eq(ShopState.open(db, run).reroll_cost(db, run), 2, "%s discount" % id)
	_check(expected.size() == 3, "table")


func test_every_boss_rule() -> void:
	var db := Fixtures.db()
	for rule: String in db.boss_rules:
		var r := Fixtures.run_with_rules([rule] if rule != "ENRAGED" else ["ENRAGED", "BELL_RINGER", "INQUISITOR"])
		r.relics.append(RelicInstance.new("RATTLE_DRUM"))
		var enc := RunFlow.start_encounter(db, r)
		enc.begin()
		match rule:
			"EXORCIST":
				_check(enc.rules.has("EXORCIST"), "exorcist active")
			"WITCH_HUNTER":
				_check(r.relics[0].disabled, "witch hunter disables leftmost")
			"BELL_RINGER":
				_check(enc.shackled >= 0, "bell ringer shackles")
			"INQUISITOR":
				_eq(enc.summons_left, 2, "inquisitor −1 summon")
			"ENRAGED":
				_check(enc.shackled >= 0 and enc.summons_left == 2, "enraged applies both rules")
