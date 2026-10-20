class_name ConsumableFx
extends RefCounted
## Consumable rules (GAME_SPEC §4.7, §4.8). Targets are Vector2i(die index, face index).
## `can_apply` is what buttons show; `apply` re-checks it, then mutates the run.


static func target_count(db: ContentDb, id: String) -> int:
	return int(db.consumables[id]["max_targets"])


## Exact target rule: Sigil 1–2 faces, Ink exactly 1, Tome / Die none.
static func can_apply(db: ContentDb, run: RunState, id: String, targets: Array[Vector2i]) -> bool:
	if not db.consumables.has(id):
		return false
	var row: Dictionary = db.consumables[id]
	for t in targets:
		if t.x < 0 or t.x >= run.dice.size() or t.y < 0 or t.y >= Die.FACE_COUNT:
			return false
	if _has_duplicates(targets):
		return false
	match row["kind"]:
		"TOME":
			return targets.is_empty()
		"SIGIL":
			return targets.size() >= 1 and targets.size() <= int(row["max_targets"])
		"INK":
			return targets.size() == 1
		"DIE":
			return targets.is_empty() and run.dice.size() < int(db.economy["max_dice"])
	return false


static func apply(db: ContentDb, run: RunState, id: String, targets: Array[Vector2i]) -> bool:
	if not can_apply(db, run, id, targets):
		return false
	var row: Dictionary = db.consumables[id]
	match row["kind"]:
		"TOME":
			for unit in db.tome_targets(row["element"]):
				run.levels[unit] = run.level_of(unit) + 1
		"SIGIL":
			for t in targets:
				run.dice[t.x].faces[t.y].element = row["element"]
		"INK":
			run.dice[targets[0].x].faces[targets[0].y].modifier = row["modifier"]
		"DIE":
			run.dice.append(Die.standard())
	return true


## Uses the held consumable at `index` (removing it) — shop or encounter.
static func use_held(db: ContentDb, run: RunState, index: int, targets: Array[Vector2i]) -> bool:
	if index < 0 or index >= run.consumables.size():
		return false
	if not apply(db, run, run.consumables[index], targets):
		return false
	run.consumables.remove_at(index)
	return true


static func _has_duplicates(targets: Array[Vector2i]) -> bool:
	var seen := {}
	for t in targets:
		if seen.has(t):
			return true
		seen[t] = true
	return false
