class_name RulesRegistry
extends RefCounted
## The one list of legal names in content data (GAME_SPEC §9.1): triggers, effect ops,
## conditions with their required parameters, value sources, face modifiers, boss rules.
## `validate(db)` checks every data row against it; tests fail on any unknown name.

const ELEMENTS: PackedStringArray = ["BONE", "FIRE", "ICE", "LEAF", "VOLT", "METAL"]
const TIERS: PackedStringArray = ["T1", "T2", "T3", "WISP"]
const RARITIES: PackedStringArray = ["COMMON", "UNCOMMON", "RARE"]
const TRIGGERS: PackedStringArray = ["GROUP", "FINAL", "SUMMON", "FIGHT_END"]
const OPS: PackedStringArray = ["add_power", "add_count", "mul_power", "mul_count", "add_money"]
## Ops that may run during scoring (GROUP / FINAL); add_money only at SUMMON / FIGHT_END.
const SCORING_OPS: PackedStringArray = ["add_power", "add_count", "mul_power", "mul_count"]
const ECONOMY_OPS: PackedStringArray = ["add_money"]
const SOURCES: PackedStringArray = ["money", "rerolls_left", "summons_left", "groups",
	"bosses_defeated", "counter"]
const ESSENCE_SOURCE_PREFIX := "essence:"
## Condition type -> required parameter names.
const CONDS := {
	"always": [],
	"group_has_element": ["element"],
	"group_tier": ["tier"],
	"group_unit": ["unit"],
	"group_is_first": [],
	"group_unit_repeated": [],
	"essence_gte": ["element", "n"],
	"essence_eq": ["element", "n"],
	"distinct_elements_gte": ["n"],
	"all_elements_present": [],
	"groups_gte": ["n"],
}
## Conditions that need a group (only legal in GROUP / SUMMON triggers).
const GROUP_CONDS: PackedStringArray = ["group_has_element", "group_tier", "group_unit",
	"group_is_first", "group_unit_repeated"]
const MODIFIERS: PackedStringArray = ["SHARP", "SWARM", "HEX", "GOLD", "WILD"]
const BOSS_RULES: PackedStringArray = ["EXORCIST", "WITCH_HUNTER", "BELL_RINGER", "INQUISITOR", "ENRAGED"]
const CONSUMABLE_KINDS: PackedStringArray = ["TOME", "SIGIL", "INK", "DIE"]
const EQUIPMENT_EFFECTS: PackedStringArray = ["dice", "summons", "rerolls", "relic_slots",
	"consumable_slots", "shop_reroll_discount"]
const ROLES: PackedStringArray = ["MOB", "CHAMPION", "BOSS"]


static func validate(db: ContentDb) -> PackedStringArray:
	var errors: PackedStringArray = []
	for id: String in db.units:
		var row: Dictionary = db.units[id]
		if not TIERS.has(row["tier"]):
			errors.append("unit %s: tier %s" % [id, row["tier"]])
		for e: String in row["recipe"]:
			if not ELEMENTS.has(e):
				errors.append("unit %s: element %s" % [id, e])
	for id: String in db.relics:
		_validate_relic(db, db.relics[id], errors)
	for id: String in db.consumables:
		var c: Dictionary = db.consumables[id]
		if not CONSUMABLE_KINDS.has(c["kind"]):
			errors.append("consumable %s: kind %s" % [id, c["kind"]])
		if c["kind"] in ["TOME", "SIGIL"] and not ELEMENTS.has(c["element"]):
			errors.append("consumable %s: element %s" % [id, c["element"]])
		if c["kind"] == "INK" and not MODIFIERS.has(c["modifier"]):
			errors.append("consumable %s: modifier %s" % [id, c["modifier"]])
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
	for id: String in db.economy["modifiers"]:
		if not MODIFIERS.has(id):
			errors.append("modifier %s unknown" % id)
	return errors


static func relic_blocks(row: Dictionary) -> Array:
	if row.has("blocks"):
		return row["blocks"]
	return [{"trigger": row["trigger"], "cond": row["cond"], "effects": row["effects"]}]


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
		_validate_cond(db, id, block["cond"], trigger, errors)
		for effect: Dictionary in block["effects"]:
			var op: String = effect["op"]
			var legal := ECONOMY_OPS if trigger in ["SUMMON", "FIGHT_END"] else SCORING_OPS
			if not legal.has(op):
				errors.append("relic %s: op %s not legal in %s" % [id, op, trigger])
			_validate_value(id, effect["value"], errors)


static func _validate_cond(db: ContentDb, id: String, cond: Dictionary, trigger: String, errors: PackedStringArray) -> void:
	var type: String = cond.get("type", "")
	if not CONDS.has(type):
		errors.append("relic %s: condition %s" % [id, type])
		return
	for param: String in CONDS[type]:
		if not cond.has(param):
			errors.append("relic %s: condition %s needs %s" % [id, type, param])
	if GROUP_CONDS.has(type) and trigger in ["FINAL", "FIGHT_END"]:
		errors.append("relic %s: group condition %s in %s" % [id, type, trigger])
	if cond.has("element") and not ELEMENTS.has(cond["element"]):
		errors.append("relic %s: element %s" % [id, cond["element"]])
	if cond.has("unit") and not db.units.has(cond["unit"]):
		errors.append("relic %s: unit %s" % [id, cond["unit"]])
	if cond.has("tier") and not TIERS.has(cond["tier"]):
		errors.append("relic %s: tier %s" % [id, cond["tier"]])


static func _validate_value(id: String, value: Variant, errors: PackedStringArray) -> void:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return
	if typeof(value) != TYPE_DICTIONARY:
		errors.append("relic %s: value %s" % [id, value])
		return
	var per: String = value.get("per", "")
	if not (SOURCES.has(per) or (per.begins_with(ESSENCE_SOURCE_PREFIX)
			and ELEMENTS.has(per.trim_prefix(ESSENCE_SOURCE_PREFIX)))):
		errors.append("relic %s: source %s" % [id, per])
