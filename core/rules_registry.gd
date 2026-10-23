class_name RulesRegistry
extends RefCounted
## The one list of legal names in content data (GAME_SPEC §9.1): triggers, effect ops,
## conditions with their required parameters, value sources, runes, combos, unit kinds, boss
## rules. `validate(db)` checks every data row against it; tests fail on any unknown name.

const ELEMENTS: PackedStringArray = ["BONE", "FIRE", "ICE", "LEAF", "VOLT", "METAL"]
## Combo ids in rank order (GAME_SPEC §4.3); Combos.detect refers to them by name.
const COMBOS: PackedStringArray = ["RABBLE", "DUO_PACT", "TRIO", "RAINBOW", "FULL_MOON", "RITUAL",
	"QUARTET", "QUINTET"]
const RUNES: PackedStringArray = ["SHARP", "SWARM", "WILD", "GLASS", "IRON", "TOMB", "GILDED", "LUCKY"]
const UNIT_KINDS: PackedStringArray = ["T1", "HYBRID", "RITUAL", "ELITE", "LEGEND", "PARADE", "WISP"]
const DISPLAYS: PackedStringArray = ["horde", "single", "legend"]
const RARITIES: PackedStringArray = ["COMMON", "UNCOMMON", "RARE"]
const TRIGGERS: PackedStringArray = ["ROLL", "DIE", "SQUAD", "RESOLVE", "SUMMON", "SPOILS"]
## Legal ops per trigger.
const TRIGGER_OPS := {
	"ROLL": ["ensure_face"],
	"DIE": ["add_power", "add_count", "mul_power", "mul_count"],
	"SQUAD": ["add_power", "add_count", "mul_power", "mul_count"],
	"RESOLVE": ["mul_damage", "add_damage"],
	"SUMMON": ["add_money"],
	"SPOILS": ["add_money"],
}
const SOURCES: PackedStringArray = ["money", "rerolls_left", "summons_left", "squads_before",
	"bosses_defeated", "counter", "scored_dice"]
## Per-element sources: "scored:FIRE" (scored dice of FIRE), "held:BONE" (held dice showing BONE).
const ELEMENT_SOURCE_PREFIXES: PackedStringArray = ["scored:", "held:"]
## Condition type -> required parameter names.
const CONDS := {
	"always": [],
	"die_element": ["element"],
	"die_points_lte": ["n"],
	"squad_combo": ["combo"],
	"squad_combo_in": ["combos"],
	"squad_has_element": ["element"],
	"squad_element_count_gte": ["element", "n"],
	"squad_all_points_gte": ["n"],
	"squad_is_first": [],
	"squad_is_last": [],
	"squad_unit_repeated": [],
	"battle_distinct_elements_gte": ["n"],
	"squads_gte": ["n"],
}
## Conditions about one scored die: only in DIE blocks.
const DIE_CONDS: PackedStringArray = ["die_element", "die_points_lte"]
## Conditions about the squad being summoned: not in RESOLVE / SPOILS / ROLL blocks.
const SQUAD_CONDS: PackedStringArray = ["squad_combo", "squad_combo_in", "squad_has_element",
	"squad_element_count_gte", "squad_all_points_gte", "squad_is_first", "squad_is_last",
	"squad_unit_repeated", "battle_distinct_elements_gte"]
const NO_SQUAD_TRIGGERS: PackedStringArray = ["RESOLVE", "SPOILS", "ROLL"]
const BOSS_RULES: PackedStringArray = ["EXORCIST", "WITCH_HUNTER", "BELL_RINGER", "INQUISITOR", "ENRAGED"]
const CONSUMABLE_KINDS: PackedStringArray = ["POTION", "GEM"]
const POTION_ACTIONS: PackedStringArray = ["element", "points", "rune", "mirror", "money_double"]
const COFFER_KINDS: PackedStringArray = ["POTION", "GEM", "TRINKET", "BONE"]
const COFFER_SIZES: PackedStringArray = ["NORMAL", "JUMBO", "MEGA"]
const EQUIPMENT_EFFECTS: PackedStringArray = ["summons", "rerolls", "relic_slots", "consumable_slots",
	"shop_reroll_discount", "shop_card_slots", "interest_cap"]
const ROLES: PackedStringArray = ["MOB", "CHAMPION", "BOSS"]
## Unit kinds each element must have one of (Trio / Quartet / Quintet units).
const PER_ELEMENT_KINDS: PackedStringArray = ["T1", "ELITE", "LEGEND"]


static func validate(db: ContentDb) -> PackedStringArray:
	var errors: PackedStringArray = []
	_validate_units(db, errors)
	_validate_combos(db, errors)
	for id: String in db.relics:
		_validate_relic(db, db.relics[id], errors)
	for id: String in db.consumables:
		_validate_consumable(db, db.consumables[id], errors)
	for id: String in db.coffers:
		var k: Dictionary = db.coffers[id]
		if not COFFER_KINDS.has(k["kind"]) or not COFFER_SIZES.has(k["size"]):
			errors.append("coffer %s: kind %s size %s" % [id, k["kind"], k["size"]])
		if int(k["picks"]) < 1 or int(k["picks"]) > int(k["choices"]):
			errors.append("coffer %s: picks %s of %s" % [id, k["picks"], k["choices"]])
	for id: String in db.equipment:
		var q: Dictionary = db.equipment[id]
		for key: String in q["effect"]:
			if not EQUIPMENT_EFFECTS.has(key):
				errors.append("equipment %s: effect %s" % [id, key])
		if q["requires"] != null and not db.equipment.has(q["requires"]):
			errors.append("equipment %s: requires %s" % [id, q["requires"]])
	for id: String in db.enemies:
		var en: Dictionary = db.enemies[id]
		if not ROLES.has(en["role"]):
			errors.append("enemy %s: role %s" % [id, en["role"]])
		if en["rule"] != null and not db.boss_rules.has(en["rule"]):
			errors.append("enemy %s: rule %s" % [id, en["rule"]])
	for id: String in db.boss_rules:
		if not BOSS_RULES.has(id):
			errors.append("boss rule %s unknown" % id)
	var runes: Dictionary = db.economy["runes"]
	for id: String in runes:
		if not RUNES.has(id):
			errors.append("rune %s unknown" % id)
	for id in RUNES:
		if not runes.has(id):
			errors.append("rune %s has no economy row" % id)
	return errors


static func relic_blocks(row: Dictionary) -> Array:
	if row.has("blocks"):
		return row["blocks"]
	return [{"trigger": row["trigger"], "cond": row["cond"], "effects": row["effects"]}]


static func _validate_units(db: ContentDb, errors: PackedStringArray) -> void:
	for id: String in db.units:
		var row: Dictionary = db.units[id]
		if not UNIT_KINDS.has(row["kind"]) or not DISPLAYS.has(row["display"]):
			errors.append("unit %s: kind %s display %s" % [id, row["kind"], row["display"]])
		for e: String in row["elements"]:
			if not ELEMENTS.has(e):
				errors.append("unit %s: element %s" % [id, e])
		if row["display"] == "horde" and not row.has("mini"):
			errors.append("unit %s: horde unit needs a mini" % id)
	for kind in PER_ELEMENT_KINDS:
		var by: Dictionary = db.units_by_kind[kind]
		for e in ELEMENTS:
			if not by.has(e):
				errors.append("units: no %s unit for %s" % [kind, e])
	if db.parade_unit == "" or db.wisp_unit == "":
		errors.append("units: Phantom Parade and Wisp are required")


static func _validate_combos(db: ContentDb, errors: PackedStringArray) -> void:
	if PackedStringArray(db.combo_order) != COMBOS:
		errors.append("combos: ids / rank order %s, expected %s" % [db.combo_order, COMBOS])
	for ritual: Dictionary in db.rituals:
		var unit: String = ritual["unit"]
		if not db.units.has(unit) or db.units[unit]["kind"] != "RITUAL":
			errors.append("ritual %s: not a RITUAL unit" % unit)
			continue
		var els: Array = ritual["elements"]
		if els.size() != 3 or not els.has(ritual["core"]) or els != db.units[unit]["elements"]:
			errors.append("ritual %s: elements %s core %s" % [unit, els, ritual["core"]])


static func _validate_consumable(db: ContentDb, c: Dictionary, errors: PackedStringArray) -> void:
	var id: String = c["id"]
	if not CONSUMABLE_KINDS.has(c["kind"]):
		errors.append("consumable %s: kind %s" % [id, c["kind"]])
		return
	if c["kind"] == "GEM":
		if c["action"] != "level" or not COMBOS.has(c.get("combo", "")):
			errors.append("gem %s: action %s combo %s" % [id, c["action"], c.get("combo")])
		return
	if not POTION_ACTIONS.has(c["action"]):
		errors.append("potion %s: action %s" % [id, c["action"]])
	if c["action"] == "element" and not ELEMENTS.has(c.get("element", "")):
		errors.append("potion %s: element %s" % [id, c.get("element")])
	if c["action"] == "rune" and not RUNES.has(c.get("rune", "")):
		errors.append("potion %s: rune %s" % [id, c.get("rune")])
	if int(c["min_targets"]) > int(c["max_targets"]):
		errors.append("potion %s: targets %s..%s" % [id, c["min_targets"], c["max_targets"]])


static func _validate_relic(db: ContentDb, row: Dictionary, errors: PackedStringArray) -> void:
	var id: String = row["id"]
	if not RARITIES.has(row["rarity"]):
		errors.append("relic %s: rarity %s" % [id, row["rarity"]])
	if row.has("counter"):
		var counter: Dictionary = row["counter"]
		if counter["on"] != "SUMMON":
			errors.append("relic %s: counter on %s" % [id, counter["on"]])
		_validate_cond(db, id, counter["cond"], "SUMMON", errors)
	for block: Dictionary in relic_blocks(row):
		var trigger: String = block["trigger"]
		if not TRIGGERS.has(trigger):
			errors.append("relic %s: trigger %s" % [id, trigger])
			continue
		_validate_cond(db, id, block["cond"], trigger, errors)
		for effect: Dictionary in block["effects"]:
			var op: String = effect["op"]
			if not (TRIGGER_OPS[trigger] as Array).has(op):
				errors.append("relic %s: op %s not legal in %s" % [id, op, trigger])
			if op == "ensure_face" and not ELEMENTS.has(effect.get("element", "")):
				errors.append("relic %s: ensure_face element %s" % [id, effect.get("element")])
			_validate_value(id, effect["value"], errors)


static func _validate_cond(db: ContentDb, id: String, cond: Dictionary, trigger: String, errors: PackedStringArray) -> void:
	var type: String = cond.get("type", "")
	if not CONDS.has(type):
		errors.append("relic %s: condition %s" % [id, type])
		return
	for param: String in CONDS[type]:
		if not cond.has(param):
			errors.append("relic %s: condition %s needs %s" % [id, type, param])
	if DIE_CONDS.has(type) and trigger != "DIE":
		errors.append("relic %s: die condition %s in %s" % [id, type, trigger])
	if SQUAD_CONDS.has(type) and NO_SQUAD_TRIGGERS.has(trigger):
		errors.append("relic %s: squad condition %s in %s" % [id, type, trigger])
	if cond.has("element") and not ELEMENTS.has(cond["element"]):
		errors.append("relic %s: element %s" % [id, cond["element"]])
	if cond.has("combo") and not COMBOS.has(cond["combo"]):
		errors.append("relic %s: combo %s" % [id, cond["combo"]])
	for combo: String in cond.get("combos", []):
		if not COMBOS.has(combo):
			errors.append("relic %s: combo %s" % [id, combo])


static func _validate_value(id: String, value: Variant, errors: PackedStringArray) -> void:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("relic %s: value %s" % [id, value])
		return
	if not is_source(value.get("per", "")):
		errors.append("relic %s: source %s" % [id, value.get("per")])


static func is_source(name: String) -> bool:
	if SOURCES.has(name):
		return true
	for prefix in ELEMENT_SOURCE_PREFIXES:
		if name.begins_with(prefix) and ELEMENTS.has(name.trim_prefix(prefix)):
			return true
	return false
