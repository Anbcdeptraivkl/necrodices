class_name InfoText
extends RefCounted
## Builds the info-panel / tooltip content for every inspectable thing (ART_SPEC §6.1, §6.6):
## {icon: Texture2D, title: String, kind: String, body: String}. All wording comes from
## strings_en.json or the content rows.


static func relic(db: ContentDb, r: RelicInstance, bosses_defeated: int = 0) -> Dictionary:
	var row: Dictionary = db.relics[r.id]
	var body: String = row["text"]
	body = body.replace("{counter}", str(r.counter))
	body = body.replace("{value}", RelicEval.fmt(1.0 + 0.25 * bosses_defeated))
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
		"kind": db.text("info_kind_consumable") % [db.text("kind_" + row["kind"].to_lower()), row["price"]],
		"body": row["text"]}


static func equipment(db: ContentDb, id: String) -> Dictionary:
	var row: Dictionary = db.equipment[id]
	var body: String = row["text"]
	if row["requires"] != null:
		body += "\n" + db.text("info_requires") % db.equipment[row["requires"]]["name"]
	return {"icon": Art.equipment(id), "title": row["name"],
		"kind": db.text("info_kind_equipment") % row["price"], "body": body}


static func unit(db: ContentDb, unit_id: String, level: int, elements: PackedStringArray = []) -> Dictionary:
	var row: Dictionary = db.units[unit_id]
	var stats := db.unit_stats(unit_id, level)
	var recipe: String
	if row.get("fallback", false):
		recipe = db.text("info_wisp_recipe")
	else:
		recipe = " + ".join(PackedStringArray((row["recipe"] as Array).map(func(e: String) -> String:
			return db.text("element_" + e.to_lower()))))
	return {"icon": Art.unit(unit_id, 0, elements), "title": row["name"],
		"kind": db.text("info_kind_unit") % [db.text("tier_" + row["tier"].to_lower()), level],
		"body": db.text("info_unit_body") % [recipe, RelicEval.fmt(stats.x), RelicEval.fmt(stats.y)]}


static func face(db: ContentDb, f: Face) -> Dictionary:
	var body := db.text("info_face_element") % db.text("element_" + f.element.to_lower())
	if f.modifier != "":
		body += "\n" + db.text("mod_" + f.modifier.to_lower())
	return {"icon": Art.face_glyph(f), "title": db.text("element_" + f.element.to_lower()),
		"kind": db.text("info_kind_face"), "body": body}


static func rule(db: ContentDb, rule_id: String) -> Dictionary:
	return {"icon": Art.stat("lock"), "title": db.text("rule_name_" + rule_id.to_lower()),
		"kind": db.text("info_kind_rule"), "body": db.boss_rules[rule_id]["text"]}


static func enemy(db: ContentDb, entry: Dictionary) -> Dictionary:
	var row: Dictionary = db.enemies[entry["enemy"]]
	var body := db.text("info_enemy_body") % [NumberFormat.format(entry["hp"]),
		int(db.economy["reward_" + (entry["role"] as String).to_lower()])]
	for r: String in entry["rules"]:
		body += "\n" + db.boss_rules[r]["text"]
	return {"icon": Art.enemy(entry["enemy"]), "title": row["name"],
		"kind": db.text("role_" + (entry["role"] as String).to_lower()), "body": body}
