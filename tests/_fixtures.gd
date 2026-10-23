class_name Fixtures
extends RefCounted
## Shared builders for core tests: one loaded ContentDb, faces from short specs, runs with a
## fixed seed, forced trays.

static var _db: ContentDb


static func db() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		if not _db.load_all():
			push_error("fixture data failed: %s" % [_db.errors])
	return _db


## "FIRE4" -> FIRE 4 points; "FIRE2+SHARP" -> with a rune; "BONE" -> BONE 6; "TOMB" -> a TOMB face.
static func face(spec: String) -> Face:
	var parts := spec.split("+")
	var head := parts[0]
	var rune := parts[1] if parts.size() > 1 else ""
	if head == "TOMB":
		return Face.new("BONE", 6, "TOMB")
	var element := head.rstrip("0123456789")
	var digits := head.trim_prefix(element)
	return Face.new(element, int(digits) if digits != "" else 3, rune)


static func faces(specs: Array) -> Array[Face]:
	var out: Array[Face] = []
	for s: String in specs:
		out.append(face(s))
	return out


static func run(seed: String = "TESTSEED") -> RunState:
	return RunFlow.new_run(db(), seed)


## A run whose current battle has the given boss rules and HP.
static func run_with_rules(rules: Array, hp: float = 1.0e9) -> RunState:
	var r := run()
	r.night_plan[0] = {"enemy": "MOB_TORCH_VILLAGER", "role": "MOB", "rules": rules, "hp": hp}
	return r


static func battle(rules: Array = [], hp: float = 1.0e9, relics: Array = []) -> EncounterState:
	var r := run_with_rules(rules, hp)
	for id: String in relics:
		r.relics.append(RelicInstance.new(id))
	var enc := RunFlow.start_encounter(db(), r)
	enc.begin()
	return enc


## Forces the tray: die i shows `specs[i]` (rewriting that face of the die) and the battle is in
## PICK. Extra dice beyond the specs keep a rolled face.
static func set_tray(enc: EncounterState, specs: Array) -> void:
	if enc.phase == EncounterState.Phase.AWAIT_ROLL:
		enc.roll()
	for i in specs.size():
		var f := face(specs[i])
		var die := enc.run.dice[i]
		var k := die.face_of(f.element)
		if f.is_tomb():
			k = 0
		die.faces[k] = f
		enc.top[i] = k
	enc.shackled = -1 if not enc.rules.has("BELL_RINGER") else enc.shackled
	enc.picked.clear()


static func pick(enc: EncounterState, idx: Array) -> void:
	enc.picked.clear()
	for i: int in idx:
		enc.toggle_select(i)


## Picks the first `n` dice that are not shackled.
static func pick_free(enc: EncounterState, n: int) -> void:
	enc.picked.clear()
	for i in enc.tray_size:
		if enc.picked.size() < n and i != enc.shackled:
			enc.toggle_select(i)


static func no_targets() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	return out


## A squad from face specs (all picked, nothing held) scored with `relics`.
static func score(specs: Array, relics: Array = [], held: Array = [], levels: Dictionary = {},
		rules: PackedStringArray = []) -> ScoreResult:
	var squad := squad_of(specs, held)
	var rs: Array[RelicInstance] = []
	for id: String in relics:
		rs.append(RelicInstance.new(id))
	var ctx := ScoreCtx.new()
	ctx.squad = squad
	return Scorer.score_squad(db(), squad, rs, levels, ctx, rules)


static func squad_of(specs: Array, held: Array = []) -> Squad:
	var squad := Squad.new()
	squad.faces = faces(specs)
	for i in specs.size():
		squad.dice.append(i)
	var m := Combos.detect(db(), squad.faces)
	squad.combo = m["combo"]
	squad.unit_id = m["unit"]
	squad.unit_elements = m["unit_elements"]
	squad.elements = m["elements"]
	squad.scored = m["scored"]
	for j in held.size():
		squad.held.append(specs.size() + j)
		squad.held_faces.append(face(held[j]))
	return squad
