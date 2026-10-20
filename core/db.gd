class_name ContentDb
extends RefCounted
## Loads and validates every content file in res://data (GAME_SPEC §9). Rows are kept as
## dictionaries keyed by id; typed accessors grow with M1. Unknown or inconsistent data is
## reported in `errors` and fails the boot — never skipped silently.

const FILES := ["elements", "units", "relics", "consumables", "equipment", "enemies",
	"curve", "economy", "strings_en"]
const ELEMENTS: PackedStringArray = ["BONE", "FIRE", "ICE", "LEAF", "VOLT", "METAL"]
const PAIR_KEY_COUNT := 21
const TRIPLE_COUNT := 4

var raw := {}          # file name -> parsed JSON
var units := {}        # id -> row
var relics := {}
var consumables := {}
var equipment := {}
var enemies := {}
var boss_rules := {}
var economy := {}
var curve := {}
var strings := {}
## Canonical recipe key ("BONE+METAL") -> unit id; WISP keys included.
var recipes := {}
## Unit ids in table order (§6.2); WILD ties resolve to the lower index.
var unit_order: PackedStringArray = []
var errors: PackedStringArray = []


func load_all(dir: String = "res://data") -> bool:
	errors.clear()
	for name: String in FILES:
		raw[name] = JsonUtil.load_file(dir.path_join(name + ".json"), errors)
	if not errors.is_empty():
		return false
	units = _index(raw["units"]["units"], "units")
	unit_order = PackedStringArray(units.keys())
	relics = _index(raw["relics"]["relics"], "relics")
	consumables = _index(raw["consumables"]["consumables"], "consumables")
	equipment = _index(raw["equipment"]["equipment"], "equipment")
	enemies = _index(raw["enemies"]["enemies"], "enemies")
	boss_rules = _index(raw["enemies"]["boss_rules"], "boss_rules")
	economy = raw["economy"]
	curve = raw["curve"]
	strings = raw["strings_en"]
	_build_recipes()
	_validate_recipes()
	errors.append_array(RulesRegistry.validate(self))
	return errors.is_empty()


static func recipe_key(elements: Array) -> String:
	var sorted: Array = elements.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool: return ELEMENTS.find(a) < ELEMENTS.find(b))
	return "+".join(PackedStringArray(sorted))


## Power / Count of a unit at a level (§4.7): base + growth × (level − 1).
func unit_stats(unit_id: String, level: int) -> Vector2:
	var row: Dictionary = units[unit_id]
	var steps := maxi(0, level - 1)
	return Vector2(row["base_p"] + row["grow_p"] * steps, row["base_c"] + row["grow_c"] * steps)


func unit_tier(unit_id: String) -> String:
	return units[unit_id]["tier"]


## Units whose recipe contains `element` (once per unit), plus WISP — the Tome rule (§4.7).
func tome_targets(element: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for id in unit_order:
		var row: Dictionary = units[id]
		if row.get("fallback", false) or (row["recipe"] as Array).has(element):
			out.append(id)
	return out


func text(key: String) -> String:
	if not strings.has(key):
		push_error("missing string key %s" % key)
		return key
	return strings[key]


func _index(rows: Array, what: String) -> Dictionary:
	var out := {}
	for row: Dictionary in rows:
		if out.has(row["id"]):
			errors.append("%s: duplicate id %s" % [what, row["id"]])
		out[row["id"]] = row
	return out


func _build_recipes() -> void:
	recipes.clear()
	for id: String in units:
		var row: Dictionary = units[id]
		if row.get("fallback", false):
			continue
		recipes[recipe_key(row["recipe"])] = id
	for key: String in raw["units"]["wisp_keys"]:
		if recipes.has(key):
			errors.append("units: wisp key %s collides with a recipe" % key)
		recipes[key] = "WISP"


## GAME_SPEC §5.1 startup assertion: all 21 pair keys resolve, exactly 4 triples exist.
func _validate_recipes() -> void:
	var pairs := 0
	var triples := 0
	for i in ELEMENTS.size():
		for j in range(i, ELEMENTS.size()):
			if recipes.has(recipe_key([ELEMENTS[i], ELEMENTS[j]])):
				pairs += 1
	for key: String in recipes:
		if key.count("+") == 2:
			triples += 1
	if pairs != PAIR_KEY_COUNT:
		errors.append("recipes: %d of %d pair keys resolve" % [pairs, PAIR_KEY_COUNT])
	if triples != TRIPLE_COUNT:
		errors.append("recipes: %d triples, expected %d" % [triples, TRIPLE_COUNT])
