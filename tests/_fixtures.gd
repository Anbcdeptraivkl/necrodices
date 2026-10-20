class_name Fixtures
extends RefCounted
## Shared builders for core tests: one loaded ContentDb, groups from face specs, runs with a
## fixed seed, scripted encounter turns.

static var _db: ContentDb


static func db() -> ContentDb:
	if _db == null:
		_db = ContentDb.new()
		if not _db.load_all():
			push_error("fixture data failed: %s" % [_db.errors])
	return _db


## "BONE+SHARP" -> Face(BONE, SHARP)
static func face(spec: String) -> Face:
	var parts := spec.split("+")
	return Face.new(parts[0], parts[1] if parts.size() > 1 else "")


static func faces(specs: Array) -> Array[Face]:
	var out: Array[Face] = []
	for s: String in specs:
		out.append(face(s))
	return out


static func group(specs: Array, levels: Dictionary = {}) -> Group:
	var fs := faces(specs)
	var res := Recipes.resolve(db(), fs, levels)
	var g := Group.new()
	g.unit_id = res["unit"]
	g.faces = fs
	g.elements = res["elements"]
	return g


static func run(seed: String = "TESTSEED") -> RunState:
	return RunFlow.new_run(db(), seed)


## A run whose current encounter has the given boss rules and HP.
static func run_with_rules(rules: Array, hp: float = 1000.0) -> RunState:
	var r := run()
	r.night_plan[0] = {"enemy": "MOB_TORCH_VILLAGER", "role": "MOB", "rules": rules, "hp": hp}
	return r


## Forces the rolled faces of the tray (test setup only).
static func set_tray(enc: EncounterState, elements: Array) -> void:
	for i in elements.size():
		var die := enc.run.dice[i]
		var idx := -1
		for k in die.faces.size():
			if die.faces[k].element == elements[i]:
				idx = k
		enc.top[i] = idx
