class_name ConsumableFx
extends RefCounted
## Potion and gem rules (GAME_SPEC §6.6, §6.7). Targets are Vector2i(die index, face index),
## in the order the player picked them (Mirror copies the first onto the second).
## `can_apply` is what buttons show; `apply` re-checks it, then mutates the run.


static func target_count(db: ContentDb, id: String) -> int:
	return int(db.consumables[id]["max_targets"])


static func min_targets(db: ContentDb, id: String) -> int:
	return int(db.consumables[id]["min_targets"])


static func can_apply(db: ContentDb, run: RunState, id: String, targets: Array[Vector2i]) -> bool:
	if not db.consumables.has(id):
		return false
	var row: Dictionary = db.consumables[id]
	if targets.size() < int(row["min_targets"]) or targets.size() > int(row["max_targets"]):
		return false
	var seen := {}
	for t in targets:
		if t.x < 0 or t.x >= run.dice.size() or t.y < 0 or t.y >= Die.FACE_COUNT or seen.has(t):
			return false
		seen[t] = true
	if row["action"] == "points":
		for t in targets:
			if run.dice[t.x].faces[t.y].element == "BONE":
				return false
	return true


static func apply(db: ContentDb, run: RunState, id: String, targets: Array[Vector2i]) -> bool:
	if not can_apply(db, run, id, targets):
		return false
	var row: Dictionary = db.consumables[id]
	var e := db.economy
	match row["action"]:
		"element":
			for t in targets:
				_face(run, t).set_element(row["element"], int(e["former_bone_points"]))
		"points":
			for t in targets:
				var f := _face(run, t)
				f.points = mini(int(e["max_points"]), f.points + int(row["delta"]))
		"rune":
			for t in targets:
				_face(run, t).rune = row["rune"]
		"mirror":
			var src := _face(run, targets[0])
			var dst := _face(run, targets[1])
			dst.element = src.element
			dst.points = src.points
			dst.rune = src.rune
		"money_double":
			run.money += mini(int(row["max"]), maxi(0, run.money))
		"level":
			run.levels[row["combo"]] = run.level_of(row["combo"]) + 1
	return true


## Uses the held consumable at `index` (removing it) — market or battle.
static func use_held(db: ContentDb, run: RunState, index: int, targets: Array[Vector2i]) -> bool:
	if index < 0 or index >= run.consumables.size():
		return false
	if not apply(db, run, run.consumables[index], targets):
		return false
	run.consumables.remove_at(index)
	return true


static func _face(run: RunState, t: Vector2i) -> Face:
	return run.dice[t.x].faces[t.y]
