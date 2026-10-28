extends TestSuite
## Every trinket, potion, gem, gear and boss rule proves its effect (GAME_SPEC §6, §15).
## Trinket rows: the trinket alone on a small squad, expected strength computed by hand.

const COVERS: Array[String] = ["data/relics.json", "data/consumables.json", "data/equipment.json",
	"data/enemies.json", "data/coffers.json", "core/scorer.gd", "core/relic_eval.gd",
	"core/consumable_fx.gd", "core/encounter_state.gd", "core/economy.gd"]

const F3 := ["FIRE1", "FIRE1", "FIRE1"]   # Trio: (30 + 3) × 3 = 99
const RAINBOW := ["BONE", "FIRE1", "ICE1", "LEAF1", "VOLT1"]  # (35 + 10) × 4 = 180
## trinket -> [pick, held, ctx opts, strength with, strength without]
const CASES := {
	"RATTLE_DRUM": [["BONE", "BONE", "BONE"], [], {}, 576.0, 144.0],
	"EMBER_JAR": [F3, [], {}, 279.0, 99.0],
	"FROST_LANTERN": [["ICE1", "ICE1", "ICE1"], [], {}, 144.0, 99.0],
	"MOSS_CHARM": [["LEAF1", "LEAF1", "LEAF1"], [], {}, 297.0, 99.0],
	"LIGHTNING_ROD": [["VOLT1", "VOLT1", "VOLT1"], [], {}, 378.0, 99.0],
	"IRON_NAIL": [["METAL1", "METAL1", "METAL1"], [], {}, 189.0, 99.0],
	"GRAVEDIGGER_LAMP": [F3, [], {}, 231.0, 99.0],
	"TRIO_TOTEM": [F3, [], {}, 363.0, 99.0],
	"MOON_CHARM": [["FIRE1", "FIRE1", "FIRE1", "ICE1", "ICE1"], [], {}, 630.0, 180.0],
	"BONE_SAW": [["FIRE4", "FIRE4", "FIRE4"], [], {}, 246.0, 126.0],
	"WISP_JAR": [["FIRE1", "ICE5", "LEAF2"], [], {}, 45.0, 15.0],
	"DEEP_FREEZE": [["ICE1", "ICE1", "ICE1"], [], {}, 165.0, 99.0],
	"THRIFTY_GHOST": [F3, [], {"rerolls": 2}, 297.0, 99.0],
	"HYBRID_VIGOR": [["BONE", "FIRE1", "BONE", "FIRE1"], [], {}, 272.0, 68.0],
	"COPYCAT_COFFIN": [F3, [], {"seen": ["FIRE_IMP"]}, 363.0, 99.0],
	"OVERGROWTH": [F3, [], {"counter": 3}, 198.0, 99.0],
	"SPIRIT_BOARD": [RAINBOW, [], {}, 360.0, 180.0],
	"PIGGY_COFFIN": [F3, [], {"money": 10}, 159.0, 99.0],
	"BONE_PILE": [F3, ["BONE", "BONE"], {}, 231.0, 99.0],
	"COLD_HEARTH": [F3, [], {}, 234.0, 99.0],
	"GRAND_PROCESSION": [F3, [], {"squads_before": 2}, 189.0, 99.0],
	"TACTICIAN_SKULL": [F3, [], {}, 198.0, 99.0],
	"CROWN_OF_THE_LICH": [["FIRE1", "FIRE1", "FIRE1", "FIRE1"], [], {}, 896.0, 448.0],
	"LAST_RITES": [F3, [], {"summons_left": 0}, 297.0, 99.0],
	"ELEMENTAL_CONVERGENCE": [RAINBOW, [], {"battle": ["METAL"]}, 540.0, 180.0],
}
## Trinkets that act outside the squad score, each with its own test below.
const OTHER := ["GRAVE_ROBBER", "LOADED_BONE", "GILDED_TOOTH", "BLOOD_MOON", "BLACK_GRIMOIRE"]


func _strength(pick: Array, held: Array, relic: String, opts: Dictionary) -> float:
	var squad := Fixtures.squad_of(pick, held)
	var relics: Array[RelicInstance] = []
	if relic != "":
		relics.append(RelicInstance.new(relic, opts.get("counter", 0)))
	var ctx := ScoreCtx.new()
	ctx.money = opts.get("money", 0)
	ctx.rerolls_left = opts.get("rerolls", 0)
	ctx.summons_left = opts.get("summons_left", 1)
	ctx.squads_before = opts.get("squads_before", 0)
	for u: String in opts.get("seen", []):
		ctx.seen_units[u] = true
	for e: String in opts.get("battle", []):
		ctx.battle_elements[e] = true
	return Scorer.score_squad(Fixtures.db(), squad, relics, {}, ctx, PackedStringArray()).strength


func _t(items: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(items)
	return out


func test_every_trinket_has_a_case() -> void:
	for id: String in Fixtures.db().relics:
		_check(CASES.has(id) or OTHER.has(id), "trinket %s has a fixture" % id)


func test_trinket_effects() -> void:
	for id: String in CASES:
		var c: Array = CASES[id]
		_eq(_strength(c[0], c[1], id, c[2]), c[3], "%s with" % id)
		_eq(_strength(c[0], c[1], "", c[2]), c[4], "%s without" % id)


func test_conditional_trinkets_stay_off() -> void:
	_eq(_strength(F3, [], "TACTICIAN_SKULL", {"squads_before": 1}), 99.0, "Tactician only on the first squad")
	_eq(_strength(F3, [], "LAST_RITES", {"summons_left": 1}), 99.0, "Last Rites only on the last")
	_eq(_strength(["ICE1", "ICE1", "FIRE1"], [], "DEEP_FREEZE", {}), 11.0, "Deep Freeze needs 3 ICE (rabble)")
	_eq(_strength(["FIRE4", "FIRE4", "FIRE3"], [], "BONE_SAW", {}), 123.0, "Bone Saw needs every die 4+")


func test_spoils_and_summon_money() -> void:
	var enc := Fixtures.battle([], 1.0, ["GRAVE_ROBBER", "GILDED_TOOTH"])
	Fixtures.set_tray(enc, ["BONE", "BONE", "BONE"])
	Fixtures.pick(enc, [0, 1, 2])
	var money := enc.run.money
	enc.summon()
	_eq(enc.run.money, money + 3, "Gilded Tooth: $1 per scored BONE")
	var lines := Economy.spoils_lines(Fixtures.db(), enc.run, enc)
	_check(lines.any(func(l: Dictionary) -> bool: return l["source"] == "GRAVE_ROBBER" and l["amount"] == 2),
		"Grave Robber +$2")


func test_resolve_trinkets() -> void:
	var enc := Fixtures.battle([], 1.0e9, ["BLOOD_MOON"])
	for n in 3:
		if enc.phase == EncounterState.Phase.AWAIT_ROLL:
			enc.roll()
		Fixtures.set_tray(enc, F3)
		Fixtures.pick(enc, [0, 1, 2])
		enc.summon()
	enc.attack()
	_eq(enc.resolution.army, 297.0, "three trios")
	_eq(enc.resolution.damage, 446.0, "blood moon ×1.5 rounds half up")


func test_potions_and_gems() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run()
	var bone := Vector2i(0, 0)
	var fire := Vector2i(0, 1)
	_check(ConsumableFx.apply(db, run, "ELIXIR_ICE", _t([bone])), "elixir on the BONE face")
	_eq([run.dice[0].faces[0].element, run.dice[0].faces[0].points], ["ICE", 3], "former BONE → 3 points")
	_check(ConsumableFx.apply(db, run, "ELIXIR_BONE", _t([fire])), "elixir of bone")
	_eq(run.dice[0].faces[1].points, 6, "BONE is 6")
	_check(not ConsumableFx.can_apply(db, run, "STRENGTH_TONIC", _t([fire])), "no tonic on BONE")
	var leaf := Vector2i(1, 3)
	run.dice[1].faces[3].points = 8
	_check(ConsumableFx.apply(db, run, "STRENGTH_TONIC", _t([leaf])), "tonic")
	_eq(run.dice[1].faces[3].points, 9, "capped at 9")
	_check(ConsumableFx.apply(db, run, "GLASS_DRAUGHT", _t([leaf])), "rune")
	_eq(run.dice[1].faces[3].rune, "GLASS", "glass rune")
	_check(not ConsumableFx.can_apply(db, run, "GLASS_DRAUGHT", _t([leaf, fire])), "glass: 1 face")
	_check(ConsumableFx.apply(db, run, "MIRROR_DRAUGHT", _t([leaf, Vector2i(2, 2)])), "mirror")
	_eq(run.dice[2].faces[2].to_dict(), run.dice[1].faces[3].to_dict(), "second face copies the first")
	run.money = 7
	_check(ConsumableFx.apply(db, run, "HERMIT_BREW", _t([])), "hermit")
	_eq(run.money, 14, "doubled")
	run.money = 50
	ConsumableFx.apply(db, run, "HERMIT_BREW", _t([]))
	_eq(run.money, 70, "max +$20")
	_check(ConsumableFx.apply(db, run, "AMBER", _t([])), "gem")
	_eq(run.level_of("TRIO"), 2, "trio level 2")
	for id: String in db.consumables:
		var row: Dictionary = db.consumables[id]
		var targets: Array[Vector2i] = []
		for t in int(row["min_targets"]):
			targets.append(Vector2i(t + 2, 4))
		_check(ConsumableFx.can_apply(db, run, id, targets), "%s applies to its minimum targets" % id)


func test_gear_effects() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run_with_rules([])
	run.equipment = PackedStringArray(["GRAVE_BELL", "LOADED_CUP", "RELIQUARY", "POCKET_CRYPT", "GRAVE_GOODS"])
	var enc := RunFlow.start_encounter(db, run)
	_eq(enc.summons_left, 4, "+1 summon")
	_eq(enc.rerolls_left, 3, "+1 reroll")
	_eq(run.relic_slots(db), 6, "+1 trinket slot")
	_eq(run.consumable_slots(db), 3, "+1 potion slot")
	_eq(Economy.interest(db, run, 100), 10, "interest cap +$5")
	run.equipment.append("OVERSTOCK")
	_eq(ShopState.open(db, run).cards.size(), 3, "+1 market card")


func test_boss_rules() -> void:
	_eq(Fixtures.battle(["INQUISITOR"]).summons_left, 2, "Inquisitor")
	var db := Fixtures.db()
	for id: String in db.boss_rules:
		_check(float(db.boss_rules[id]["hp_mult"]) > 0.0, "%s prices its HP" % id)
