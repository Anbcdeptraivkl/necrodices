class_name InfoText
extends RefCounted
## Builds the tooltip / Codex content for every inspectable thing (ART_SPEC §6.1, §6.6):
## {icon: Texture2D, title: String, kind: String, kind_colour: Color, price: String, body: String,
## lore: String}. The kind line names what the thing is (Trinket / Potion / Gem / Gear …) in its
## colour code. Every idea sits on its own line (kind, rarity, price), never joined with dots;
## price is the formatted cost, "" when there is none.
## All wording comes from data/text (UI strings and content rows).


static func relic(db: ContentDb, r: RelicInstance, bosses_defeated: int = 0) -> Dictionary:
	var row: Dictionary = db.relics[r.id]
	var body: String = row["text"]
	body = body.replace("{counter}", str(r.counter))
	body = body.replace("{value}", RelicEval.fmt(1.0 + 0.25 * bosses_defeated))
	if r.disabled:
		body += "\n" + db.text("info_relic_disabled")
	return {"icon": Art.relic(r.id), "title": row["name"], "kind_colour": Art.kind_colour("RELIC"),
		"kind": db.text("info_kind_relic") % db.text("rarity_" + row["rarity"].to_lower()),
		"price": _price(db, int(row["price"])), "body": body, "lore": row.get("lore", "")}


static func relic_offer(db: ContentDb, id: String) -> Dictionary:
	return relic(db, RelicInstance.new(id))


static func consumable(db: ContentDb, id: String) -> Dictionary:
	var row: Dictionary = db.consumables[id]
	var kind: String = row["kind"]
	return {"icon": Art.consumable(id), "title": row["name"], "kind_colour": Art.kind_colour(kind),
		"kind": db.text("info_kind_" + kind.to_lower()), "price": _price(db, int(row["price"])), "body": row["text"],
		"lore": row.get("lore", "")}


static func coffer(db: ContentDb, id: String) -> Dictionary:
	var row: Dictionary = db.coffers[id]
	return {"icon": Art.coffer(id), "title": row["name"], "kind": db.text("info_kind_coffer"),
		"price": _price(db, int(row["price"])), "kind_colour": Art.kind_colour("COFFER"), "lore": row.get("lore", ""),
		"body": db.text("info_coffer_body") % [int(row["picks"]), int(row["choices"]),
			db.text("coffer_kind_" + (row["kind"] as String).to_lower())]}


static func equipment(db: ContentDb, id: String) -> Dictionary:
	var row: Dictionary = db.equipment[id]
	var body: String = row["text"]
	if row["requires"] != null:
		body += "\n" + db.text("info_requires") % db.equipment[row["requires"]]["name"]
	return {"icon": Art.equipment(id), "title": row["name"], "kind_colour": Art.kind_colour("GEAR"),
		"kind": db.text("info_kind_equipment"), "price": _price(db, int(row["price"])), "body": body,
		"lore": row.get("lore", "")}


## A market / coffer die: its six faces, one per line.
static func die(db: ContentDb, d: Die, price: int = -1) -> Dictionary:
	var parts: PackedStringArray = []
	for f in d.faces:
		parts.append(face_short(db, f))
	return {"icon": Art.die_body(d.faces[0]), "title": db.text("item_die"), "kind_colour": Art.kind_colour("DIE"),
		"kind": db.text("info_kind_die"), "price": _price(db, price), "body": "\n".join(parts)}


static func _price(db: ContentDb, price: int) -> String:
	return db.text("info_price") % price if price >= 0 else ""


static func face_short(db: ContentDb, f: Face) -> String:
	if f.is_tomb():
		return db.runes["TOMB"]["name"]
	var s := "%s %d" % [db.text("element_" + f.element.to_lower()), f.points]
	if f.rune != "":
		s += " " + db.runes[f.rune]["name"]
	return s


static func unit(db: ContentDb, unit_id: String, elements: PackedStringArray = []) -> Dictionary:
	var row: Dictionary = db.units[unit_id]
	return {"icon": Art.unit(unit_id, 0, elements), "title": row["name"],
		"kind": db.text("unit_kind_" + (row["kind"] as String).to_lower()), "lore": row.get("lore", ""),
		"body": db.text("info_unit_body_" + (row["display"] as String))}


## How a unit is summoned, in words ("Summoned by a Quartet of METAL.").
static func unit_recipe(db: ContentDb, unit_id: String) -> String:
	var row: Dictionary = db.units[unit_id]
	var els: Array = row["elements"]
	var names := PackedStringArray()
	for e: String in els:
		names.append(db.text("element_" + e.to_lower()))
	match row["kind"]:
		"T1", "ELITE", "LEGEND":
			return db.text("recipe_" + (row["kind"] as String).to_lower()) % names[0]
		"HYBRID":
			return db.text("recipe_hybrid") % [names[0], names[1]]
		"RITUAL":
			for ritual: Dictionary in db.rituals:
				if ritual["unit"] == unit_id:
					var core := db.text("element_" + (ritual["core"] as String).to_lower())
					return db.text("recipe_ritual") % [" + ".join(names), core]
	return db.text("recipe_" + (row["kind"] as String).to_lower())


static func squad(db: ContentDb, s: Squad) -> Dictionary:
	var combo: Dictionary = db.combos[s.combo]
	var r := s.result
	return {"icon": Art.unit(s.unit_id, 0, s.unit_elements), "title": db.units[s.unit_id]["name"],
		"kind": combo["name"], "body": db.text("info_squad_body") % [RelicEval.fmt(r.power), RelicEval.fmt(r.count),
			NumberFormat.format(r.strength)]}


static func combo(db: ContentDb, id: String, level: int) -> Dictionary:
	var row: Dictionary = db.combos[id]
	var stats := db.combo_stats(id, level)
	return {"icon": null, "title": row["name"], "kind": db.text("info_kind_combo") % level, "lore": row.get("lore", ""),
		"body": "%s\n%s" % [row["text"], db.text("info_combo_stats") % [RelicEval.fmt(stats.x), RelicEval.fmt(stats.y)]]}


static func rune(db: ContentDb, id: String) -> Dictionary:
	var row: Dictionary = db.runes[id]
	return {"icon": Art.die_body(Face.new("FIRE", 3, id)), "title": row["name"], "kind": db.text("info_kind_rune"),
		"kind_colour": Art.kind_colour("RUNE"), "body": row["effect"], "lore": row.get("lore", "")}


static func hunter(db: ContentDb, enemy_id: String) -> Dictionary:
	var row: Dictionary = db.enemies[enemy_id]
	var body := ""
	if row["rule"] != null:
		var rule: Dictionary = db.boss_rules[row["rule"]]
		body = "%s: %s" % [rule["name"], rule["text"]]
	return {"icon": Art.enemy(enemy_id), "title": row["name"], "lore": row.get("lore", ""),
		"kind": db.text("info_kind_hunter") % db.text("role_" + (row["role"] as String).to_lower()), "body": body}


static func face(db: ContentDb, f: Face) -> Dictionary:
	var body: String
	if f.is_tomb():
		body = db.runes["TOMB"]["effect"]
	else:
		body = db.text("info_face_body") % [db.text("element_" + f.element.to_lower()), f.points]
		if f.rune != "":
			body += "\n" + db.runes[f.rune]["effect"]
	return {"icon": Art.face_glyph(f) if not f.is_tomb() else Art.die_body(f), "title": face_short(db, f),
		"kind": db.text("info_kind_face"), "kind_colour": Art.kind_colour("RUNE") if f.rune != "" else Color.WHITE,
		"body": body}
