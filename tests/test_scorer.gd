extends TestSuite
## Squad scorer and resolve (GAME_SPEC §5): the worked example, levels, runes, boss rules,
## rounding, trinket order and the resolve multipliers.

const COVERS: Array[String] = ["core/scorer.gd", "core/relic_eval.gd", "core/score_ctx.gd",
	"core/trace_step.gd", "core/squad.gd", "data/relics.json", "data/economy.json"]


func test_worked_example() -> void:
	var r := Fixtures.score(["FIRE4", "FIRE2+SHARP", "FIRE5", "ICE3"], ["EMBER_JAR", "TRIO_TOTEM"])
	_eq(r.power, 131.0, "power")
	_eq(r.count, 11.0, "count")
	_eq(r.strength, 1441.0, "strength (GAME_SPEC §5.6)")
	var kinds: Array = []
	for s in r.trace:
		kinds.append(TraceStep.Kind.keys()[s.kind])
	_eq(kinds, ["COMBO", "DIE", "TRINKET", "DIE", "RUNE", "TRINKET", "DIE", "TRINKET", "TRINKET", "STRENGTH"],
		"trace order")
	_eq(r.trace[-1].p_after * r.trace[-1].c_after, 1441.0, "last step = strength")


func test_rabble_and_levels() -> void:
	_eq(Fixtures.score(["FIRE1", "ICE5", "LEAF2"]).strength, 15.0, "rabble: (10 + 5) × 1")
	var r := Fixtures.score(["FIRE1", "FIRE1", "FIRE1"], [], [], {"TRIO": 2})
	_eq([r.power, r.count], [53.0, 5.0], "trio level 2: 50 + 3 points, 3 + 2 count")


func test_runes() -> void:
	_eq(Fixtures.score(["FIRE1", "FIRE1", "FIRE1+SWARM"]).count, 7.0, "SWARM +4 Count")
	_eq(Fixtures.score(["FIRE1", "FIRE1", "FIRE1+GLASS"]).count, 6.0, "GLASS ×2 Count")
	_eq(Fixtures.score(["FIRE1", "FIRE1", "FIRE1", "TOMB"]).power, 83.0, "TOMB +50 Power, no points")
	_eq(Fixtures.score(["FIRE1", "FIRE1", "FIRE1"], [], ["ICE2+IRON"]).count, 5.0, "held IRON ×1.5 (3 → 5)")
	_eq(Fixtures.score(["FIRE1", "FIRE1", "FIRE1+IRON"]).count, 3.0, "IRON does nothing when scored")
	var squad := Fixtures.squad_of(["FIRE1", "FIRE1", "FIRE1+LUCKY"])
	var ctx := ScoreCtx.new()
	_eq(Scorer.score_squad(Fixtures.db(), squad, [], {}, ctx, []).count, 3.0, "no luck rolled: nothing")
	squad.luck[2] = {"count": true, "money": false}
	_eq(Scorer.score_squad(Fixtures.db(), squad, [], {}, ScoreCtx.new(), []).count, 13.0, "lucky +10 Count")
	_eq(Fixtures.score(["FIRE1", "ICE5+WILD", "FIRE2"]).power, 38.0, "WILD makes a trio: 30 + 1 + 5 + 2")


func test_exorcist_and_rounding() -> void:
	var rules := PackedStringArray(["EXORCIST"])
	_eq(Fixtures.score(["BONE", "BONE", "BONE"], [], [], {}, rules).power, 30.0, "holy water: BONE scores 0")
	_eq(Fixtures.score(["ICE1", "ICE1", "ICE1"], ["DEEP_FREEZE"]).count, 5.0, "3 × 1.5 = 4.5 rounds half up to 5")


func test_trinket_order_matters() -> void:
	var a := Fixtures.score(["FIRE1", "ICE2", "LEAF3"], ["WISP_JAR", "GRAVEDIGGER_LAMP"])
	var b := Fixtures.score(["FIRE1", "ICE2", "LEAF3"], ["GRAVEDIGGER_LAMP", "WISP_JAR"])
	_eq(a.count, 7.0, "×3 then +4")
	_eq(b.count, 15.0, "+4 then ×3")


func test_resolve_multipliers() -> void:
	var db := Fixtures.db()
	var relics: Array[RelicInstance] = [RelicInstance.new("BLOOD_MOON"), RelicInstance.new("BLACK_GRIMOIRE")]
	var ctx := ScoreCtx.new()
	ctx.bosses_defeated = 2
	var two: Array[float] = [100.0, 50.0]
	var r := Scorer.resolve(db, two, relics, ctx)
	_eq(r.army, 150.0, "army sum")
	_eq(r.damage, 225.0, "two squads: no blood moon; grimoire ×1.5")
	var three: Array[float] = [100.0, 50.0, 50.0]
	r = Scorer.resolve(db, three, relics, ctx)
	_eq(r.damage, 450.0, "200 × 1.5 × 1.5")
	_eq(r.shares, [225.0, 112.5, 112.5] as Array[float], "shares split the damage by strength")
