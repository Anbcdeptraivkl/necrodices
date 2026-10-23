class_name Combos
extends RefCounted
## Combo detection (GAME_SPEC §4.3–§4.4). Reads the elements of the picked faces (pick order;
## TOMB = no element, always scores; WILD = every element) and returns the highest-ranked
## pattern, the positions that score and the squad's unit:
## {combo, scored: PackedInt32Array, elements: PackedStringArray, unit, unit_elements}.
## WILD faces try every element; the best (rank, scored points) wins, ties → the assignment
## found first (lowest element indices). Returns {} for fewer than 1 face.


static func detect(db: ContentDb, faces: Array[Face]) -> Dictionary:
	if faces.is_empty():
		return {}
	var base: PackedStringArray = []
	var wild_slots: PackedInt32Array = []
	for i in faces.size():
		base.append("" if faces[i].is_tomb() else faces[i].element)
		if faces[i].is_wild() and not faces[i].is_tomb():
			wild_slots.append(i)
	var n_el := RulesRegistry.ELEMENTS.size()
	var best := {}
	var best_key := Vector2i(-1, -1)
	for assignment in int(pow(n_el, wild_slots.size())):
		var elements := base.duplicate()
		var a := assignment
		for slot in wild_slots:
			elements[slot] = RulesRegistry.ELEMENTS[a % n_el]
			a /= n_el
		var m := _match(db, elements, faces)
		var key := Vector2i(db.combos[m["combo"]]["rank"], _scored_points(faces, m["scored"]))
		if key > best_key:
			best_key = key
			best = m
	return best


static func _scored_points(faces: Array[Face], scored: PackedInt32Array) -> int:
	var total := 0
	for k in scored:
		if not faces[k].is_tomb():
			total += faces[k].points
	return total


## Positions per element, in pick order; elements listed by first appearance.
static func _positions(elements: PackedStringArray) -> Dictionary:
	var out := {}
	for i in elements.size():
		var e := elements[i]
		if e == "":
			continue
		if not out.has(e):
			out[e] = PackedInt32Array()
		out[e].append(i)
	return out


static func _match(db: ContentDb, elements: PackedStringArray, faces: Array[Face]) -> Dictionary:
	var pos := _positions(elements)
	var by_count: Array = pos.keys()
	by_count.sort_custom(func(x: String, y: String) -> bool:
		var nx := (pos[x] as PackedInt32Array).size()
		var ny := (pos[y] as PackedInt32Array).size()
		return nx > ny or (nx == ny and pos[x][0] < pos[y][0]))
	var top: String = by_count[0] if by_count.size() > 0 else ""
	var second: String = by_count[1] if by_count.size() > 1 else ""
	var n_top: int = pos[top].size() if top != "" else 0
	var n_second: int = pos[second].size() if second != "" else 0
	var out := {}
	if n_top >= 5:
		out = _result(db, "QUINTET", pos[top].slice(0, 5), db.unit_for("LEGEND", top), [top])
	elif n_top >= 4:
		out = _result(db, "QUARTET", pos[top].slice(0, 4), db.unit_for("ELITE", top), [top])
	if out.is_empty():
		out = _ritual(db, pos)
	if out.is_empty() and n_top >= 3 and n_second >= 2:
		var scored: PackedInt32Array = pos[top].slice(0, 3)
		scored.append_array(pos[second].slice(0, 2))
		var unit := db.hybrid_for(top, second)
		out = _result(db, "FULL_MOON", scored, unit if unit != "" else db.unit_for("T1", top),
			[top, second] if unit != "" else [top])
	if out.is_empty() and pos.size() >= 5:
		var scored := PackedInt32Array()
		for e: String in pos:
			scored.append(pos[e][0])
		out = _result(db, "RAINBOW", scored, db.parade_unit, [])
	if out.is_empty() and n_top >= 3:
		out = _result(db, "TRIO", pos[top].slice(0, 3), db.unit_for("T1", top), [top])
	if out.is_empty() and n_top >= 2 and n_second >= 2:
		var scored: PackedInt32Array = pos[top].slice(0, 2)
		scored.append_array(pos[second].slice(0, 2))
		var unit := db.hybrid_for(top, second)
		out = _result(db, "DUO_PACT", scored, unit if unit != "" else db.wisp_unit, [top, second])
	if out.is_empty():
		out = _rabble(db, elements, faces, by_count)
	# TOMB faces always score, in pick order.
	var scored: PackedInt32Array = out["scored"]
	for i in elements.size():
		if elements[i] == "" and not scored.has(i):
			scored.append(i)
	scored.sort()
	out["scored"] = scored
	out["elements"] = elements
	return out


static func _ritual(db: ContentDb, pos: Dictionary) -> Dictionary:
	for ritual: Dictionary in db.rituals:
		var core: String = ritual["core"]
		var ok := pos.has(core) and (pos[core] as PackedInt32Array).size() >= 2
		for e: String in ritual["elements"]:
			ok = ok and pos.has(e)
		if not ok:
			continue
		var scored := PackedInt32Array()
		for e: String in ritual["elements"]:
			scored.append_array(pos[e].slice(0, 2 if e == core else 1))
		return _result(db, "RITUAL", scored, ritual["unit"], ritual["elements"])
	return {}


## Rabble: only the highest-points die scores (first one on ties); Wisp tinted by the two
## most common elements.
static func _rabble(db: ContentDb, elements: PackedStringArray, faces: Array[Face], by_count: Array) -> Dictionary:
	var best := -1
	for i in elements.size():
		if elements[i] != "" and (best == -1 or faces[i].points > faces[best].points):
			best = i
	var scored := PackedInt32Array()
	if best >= 0:
		scored.append(best)
	return _result(db, "RABBLE", scored, db.wisp_unit, by_count.slice(0, 2))


static func _result(_db: ContentDb, combo: String, scored: PackedInt32Array, unit: String, unit_elements: Array) -> Dictionary:
	return {"combo": combo, "scored": scored, "unit": unit, "unit_elements": PackedStringArray(unit_elements)}
