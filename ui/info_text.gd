class_name InfoText
extends RefCounted
## Builds the info-panel / tooltip content for every inspectable thing (ART_SPEC §6.1, §6.6):
## {icon: Texture2D, title: String, kind: String, body: String}. All wording comes from
## strings_en.json or the content rows; players see trinket / potion / gem / gear, never the
## code names (relic / consumable / equipment).


static func relic(db: ContentDb, r: RelicInstance, bosses_defeated: int = 0) -> Dictionary:
	var row: Dictionary = db.relics[r.id]
	var body: String = row["text"]
	body = body.replace("{counter}", str(r.counter))
	body = body.replace("{value}", RelicEval.fmt(1.0 + 0.25 * bosses_defeated))
	var trigger: String = RulesRegistry.relic_blocks(row)[0]["trigger"]
	body += "\n" + db.text("timing_" + trigger.to_lower())
	if r.disabled:
		body += "\n" + db.text("info_relic_disabled")
	return {"icon": Art.relic(r.id), "title": row["name"],
		"kind": db.text("info_kind_relic") % [db.text("rarity_" + row["rarity"].to_lower()), row["price"]],
		"body": body}


static func relic_offer(db: ContentDb, id: String) -> Dictionary:
	return relic(db, RelicInstance.new(id))


static func consumable(db: ContentDb, id: String) -> Dictionary:
	var row: Dictionary = db.consumables[id]
	return {"icon": Art.consumable(id), "title": row["name"],
		"kind": db.text("info_kind_" + (row["kind"] as String).to_lower()) % row["price"],
		"body": row["text"]}


static func coffer(db: ContentDb, id: String) -> Dictionary:
	var row: Dictionary = db.coffers[id]
	return {"icon": Art.coffer(id), "title": row["name"], "kind": db.text("info_kind_coffer") % row["price"],
		"body": db.text("info_coffer_body") % [int(row["picks"]), int(row["choices"]),
			db.text("coffer_kind_" + (row["kind"] as String).to_lower())]}


static func equipment(db: ContentDb, id: String) -> Dictionary:
	var row: Dictionary = db.equipment[id]
	var body: String = row["text"]
	if row["requires"] != null:
		body += "\n" + db.text("info_requires") % db.equipment[row["requires"]]["name"]
	return {"icon": Art.equipment(id), "title": row["name"],
		"kind": db.text("info_kind_equipment") % row["price"], "body": body}


## A market / coffer die: its six faces in one line.
static func die(db: ContentDb, d: Die, price: int = -1) -> Dictionary:
	var parts: PackedStringArray = []
	for f in d.faces:
		parts.append(face_short(db, f))
	return {"icon": Art.die_body(d.faces[0]), "title": db.text("item_die"),
		"kind": db.text("info_kind_die") % price if price >= 0 else db.text("info_kind_die_owned"),
		"body": "  ".join(parts)}


static func face_short(db: ContentDb, f: Face) -> String:
	if f.is_tomb():
		return db.text("rune_name_tomb")
	var s := "%s %d" % [db.text("element_" + f.element.to_lower()), f.points]
	if f.rune != "":
		s += " " + db.text("rune_name_" + f.rune.to_lower())
	return s


static func unit(db: ContentDb, unit_id: String, elements: PackedStringArray = []) -> Dictionary:
	var row: Dictionary = db.units[unit_id]
	return {"icon": Art.unit(unit_id, 0, elements), "title": row["name"],
		"kind": db.text("unit_kind_" + (row["kind"] as String).to_lower()), "body": db.text("info_unit_body_" +
			(row["display"] as String))}


static func squad(db: ContentDb, s: Squad) -> Dictionary:
	var combo: Dictionary = db.combos[s.combo]
	var r := s.result
	return {"icon": Art.unit(s.unit_id, 0, s.unit_elements), "title": db.units[s.unit_id]["name"],
		"kind": combo["name"], "body": db.text("info_squad_body") % [RelicEval.fmt(r.power), RelicEval.fmt(r.count),
			NumberFormat.format(r.strength)]}


static func combo(db: ContentDb, id: String, level: int) -> Dictionary:
	var row: Dictionary = db.combos[id]
	var stats := db.combo_stats(id, level)
	return {"icon": null, "title": row["name"], "kind": db.text("info_kind_combo") % level,
		"body": "%s\n%s" % [row["text"], db.text("info_combo_stats") % [RelicEval.fmt(stats.x), RelicEval.fmt(stats.y)]]}


static func face(db: ContentDb, f: Face) -> Dictionary:
	var body: String
	if f.is_tomb():
		body = db.text("rune_tomb")
	else:
		body = db.text("info_face_body") % [db.text("element_" + f.element.to_lower()), f.points]
		if f.rune != "":
			body += "\n" + db.text("rune_" + f.rune.to_lower())
	return {"icon": Art.face_glyph(f) if not f.is_tomb() else Art.die_body(f), "title": face_short(db, f),
		"kind": db.text("info_kind_face"), "body": body}
