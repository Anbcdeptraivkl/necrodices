class_name Recipes
extends RefCounted
## Recipe resolution (GAME_SPEC §5.1) with WILD faces (§5.2): each WILD face tries all six
## elements; the assignment whose unit maximises (tier rank, P×C at its level) wins, ties go
## to the lower unit-table index. Returns {} when the faces form no valid group.

const MAX_WILDS := 3


## faces: 2 or 3 faces in tray order. levels: unit id -> level (missing = 1).
## Returns {"unit": id, "elements": PackedStringArray (resolved, same order as faces)}.
static func resolve(db: ContentDb, faces: Array[Face], levels: Dictionary) -> Dictionary:
	if faces.size() < 2 or faces.size() > 3:
		return {}
	var wild_slots: PackedInt32Array = []
	var base: PackedStringArray = []
	for i in faces.size():
		base.append(faces[i].element)
		if faces[i].is_wild():
			wild_slots.append(i)
	if wild_slots.is_empty():
		var unit := _unit_for(db, base)
		return {} if unit == "" else {"unit": unit, "elements": base}
	var best := {}
	var best_key := Vector3i(-1, -1, 0)
	var combos := int(pow(RulesRegistry.ELEMENTS.size(), wild_slots.size()))
	for combo in combos:
		var elements := base.duplicate()
		var n := combo
		for slot in wild_slots:
			elements[slot] = RulesRegistry.ELEMENTS[n % RulesRegistry.ELEMENTS.size()]
			n /= RulesRegistry.ELEMENTS.size()
		var unit := _unit_for(db, elements)
		if unit == "":
			continue
		var key := _rank(db, unit, levels)
		if key > best_key:
			best_key = key
			best = {"unit": unit, "elements": elements}
	return best


## True when these faces can be bound (BIND enabled, §4.3).
static func can_bind(db: ContentDb, faces: Array[Face], levels: Dictionary) -> bool:
	return not resolve(db, faces, levels).is_empty()


static func _unit_for(db: ContentDb, elements: PackedStringArray) -> String:
	var key := ContentDb.recipe_key(Array(elements))
	if db.recipes.has(key):
		return db.recipes[key]
	return ""


## Larger is better: (tier rank, P×C, -table index) — the negated index makes lower win ties.
static func _rank(db: ContentDb, unit: String, levels: Dictionary) -> Vector3i:
	var stats := db.unit_stats(unit, levels.get(unit, 1))
	var tier_rank: int = db.raw["units"]["tier_rank"][db.units[unit]["tier"]]
	return Vector3i(tier_rank, int(stats.x * stats.y), -db.unit_order.find(unit))
