extends TestSuite
## Scorer fixtures (GAME_SPEC §5.5, §14): worked example, order sensitivity, boss rule,
## HEX rounding, trace contract.

const COVERS: Array[String] = ["core/scorer.gd", "core/relic_eval.gd", "core/score_ctx.gd",
	"core/trace_step.gd", "data/relics.json", "data/units.json"]

var _db: ContentDb


func _content() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		_check(_db.load_all(), "data loads")
	return _db


## A summoned group from "ELEMENT[+MOD]" face specs, resolved through the recipe table.
func _group(specs: Array) -> Group:
	var faces: Array[Face] = []
	for spec: String in specs:
		var parts := spec.split("+")
		faces.append(Face.new(parts[0], parts[1] if parts.size() > 1 else ""))
	var res := Recipes.resolve(_content(), faces, {})
	var g := Group.new()
	g.unit_id = res["unit"]
	g.faces = faces
	g.elements = res["elements"]
	return g


func _relics(ids: Array) -> Array[RelicInstance]:
	var out: Array[RelicInstance] = []
	for id: String in ids:
		out.append(RelicInstance.new(id))
	return out


func _example_army() -> Array[Group]:
	var army: Array[Group] = [
		_group(["BONE+SHARP", "BONE"]),
		_group(["FIRE", "ICE"]),
		_group(["BONE", "BONE", "BONE"]),
	]
	return army


func _score(army: Array[Group], relic_ids: Array, rules: PackedStringArray = []) -> ScoreResult:
	var ctx := ScoreCtx.build(army, 0, 0, 0, 0)
	return Scorer.score(_content(), army, _relics(relic_ids), {}, ctx, rules)


func test_worked_example() -> void:
	var army := _example_army()
	_eq(army[0].unit_id, "SKELETON_WARRIOR", "group 1 unit")
	_eq(army[1].unit_id, "STEAM_SLIME", "group 2 unit")
	_eq(army[2].unit_id, "LICH", "group 3 unit")
	var r := _score(army, ["RATTLE_DRUM", "CROWN_OF_THE_LICH", "GRAVEDIGGER_LAMP", "BONE_PILE"])
	_eq(r.power, 70.0, "power")
	_eq(r.count, 36.0, "count")
	_eq(r.damage, 2520.0, "damage")
	var steps: Array = []
	for s in r.trace:
		steps.append([s.source_id, s.p_after, s.c_after])
	_eq(steps, [
		["SKELETON_WARRIOR", 10.0, 2.0], ["SHARP", 20.0, 2.0], ["RATTLE_DRUM", 20.0, 4.0],
		["STEAM_SLIME", 30.0, 8.0],
		["LICH", 70.0, 16.0], ["RATTLE_DRUM", 70.0, 18.0], ["CROWN_OF_THE_LICH", 70.0, 27.0],
		["GRAVEDIGGER_LAMP", 70.0, 31.0], ["BONE_PILE", 70.0, 36.0], ["TOTAL", 70.0, 36.0],
	], "trace matches the §5.5 table")


func test_order_sensitivity() -> void:
	var r := _score(_example_army(), ["CROWN_OF_THE_LICH", "RATTLE_DRUM", "GRAVEDIGGER_LAMP", "BONE_PILE"])
	_eq(r.damage, 2450.0, "swapped relics")


func test_exorcist() -> void:
	var r := _score(_example_army(), ["RATTLE_DRUM", "CROWN_OF_THE_LICH", "GRAVEDIGGER_LAMP", "BONE_PILE"],
		PackedStringArray(["EXORCIST"]))
	_eq(r.power, 45.0, "halved BONE base power")
	_eq(r.damage, 1620.0, "boss fixture")


func test_hex_rounds_half_up() -> void:
	# Scarecrow (C 3) with HEX: 3 × 1.5 = 4.5 → 5.
	var army: Array[Group] = [_group(["BONE+HEX", "LEAF"])]
	_eq(_score(army, []).count, 5.0, "HEX 3 → 5")


func test_trace_ends_with_result() -> void:
	var r := _score(_example_army(), ["TACTICIAN_SKULL", "BLACK_GRIMOIRE"])
	var last: TraceStep = r.trace[-1]
	_eq(last.kind, TraceStep.Kind.TOTAL, "last step is total")
	_eq(last.value, r.damage, "total step carries the damage")
	_check(r.trace.any(func(s: TraceStep) -> bool: return s.source_id == "BLACK_GRIMOIRE" and s.label == "×1 Count"),
		"Black Grimoire at 0 bosses still shows ×1 Count")
