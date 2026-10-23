class_name ContentDb
extends RefCounted
## Loads and validates every content file in res://data (GAME_SPEC §9). Rows are kept as
## dictionaries keyed by id, plus the lookup tables the rules need (units by kind and element,
## combos in rank order, rituals). Unknown or inconsistent data is reported in `errors` and
## fails the boot — never skipped silently.

const FILES := ["elements", "combos", "units", "relics", "consumables", "coffers", "equipment",
	"enemies", "curve", "economy", "strings_en"]
const ELEMENTS: PackedStringArray = ["BONE", "FIRE", "ICE", "LEAF", "VOLT", "METAL"]

var raw := {}          # file name -> parsed JSON
var combos := {}       # id -> row
var combo_order: Array[String] = []   # ids by rank, lowest first
var rituals: Array[Dictionary] = []
var units := {}
## kind -> {element -> unit id} for T1 / ELITE / LEGEND; HYBRID -> {"BONE+FIRE" -> id}.
var units_by_kind := {}
var parade_unit := ""
var wisp_unit := ""
var relics := {}
var consumables := {}
var coffers := {}
var equipment := {}
var enemies := {}
var boss_rules := {}
var economy := {}
var curve := {}
var strings := {}
var errors: PackedStringArray = []


func load_all(dir: String = "res://data") -> bool:
	errors.clear()
	for name: String in FILES:
		raw[name] = JsonUtil.load_file(dir.path_join(name + ".json"), errors)
	if not errors.is_empty():
		return false
	combos = _index(raw["combos"]["combos"], "combos")
	var rows: Array = raw["combos"]["combos"].duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["rank"] < b["rank"])
	combo_order.clear()
	for row: Dictionary in rows:
		combo_order.append(row["id"])
	rituals.assign(raw["combos"]["rituals"])
	units = _index(raw["units"]["units"], "units")
	_index_units()
	relics = _index(raw["relics"]["relics"], "relics")
	consumables = _index(raw["consumables"]["consumables"], "consumables")
	coffers = _index(raw["coffers"]["coffers"], "coffers")
	equipment = _index(raw["equipment"]["equipment"], "equipment")
	enemies = _index(raw["enemies"]["enemies"], "enemies")
	boss_rules = _index(raw["enemies"]["boss_rules"], "boss_rules")
	economy = raw["economy"]
	curve = raw["curve"]
	strings = raw["strings_en"]
	errors.append_array(RulesRegistry.validate(self))
	return errors.is_empty()


## Canonical "A+B" key of two elements in element order.
static func pair_key(a: String, b: String) -> String:
	return a + "+" + b if ELEMENTS.find(a) <= ELEMENTS.find(b) else b + "+" + a


## Base Power / Count of a combo at a level (GAME_SPEC §4.7).
func combo_stats(combo: String, level: int) -> Vector2:
	var row: Dictionary = combos[combo]
	var steps := maxi(0, level - 1)
	return Vector2(row["base_p"] + row["lvl_p"] * steps, row["base_c"] + row["lvl_c"] * steps)


func unit_for(kind: String, element: String) -> String:
	return units_by_kind[kind].get(element, "")


func hybrid_for(a: String, b: String) -> String:
	return units_by_kind["HYBRID"].get(pair_key(a, b), "")


func display_of(unit_id: String) -> String:
	return units[unit_id]["display"]


func ids_of_kind(table: Dictionary, kind: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in table:
		if table[id]["kind"] == kind:
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


func _index_units() -> void:
	units_by_kind = {"T1": {}, "ELITE": {}, "LEGEND": {}, "HYBRID": {}}
	parade_unit = ""
	wisp_unit = ""
	for id: String in units:
		var row: Dictionary = units[id]
		var els: Array = row["elements"]
		match row["kind"]:
			"T1", "ELITE", "LEGEND":
				units_by_kind[row["kind"]][els[0]] = id
			"HYBRID":
				var key := pair_key(els[0], els[1])
				if units_by_kind["HYBRID"].has(key):
					errors.append("units: two hybrids for %s" % key)
				units_by_kind["HYBRID"][key] = id
			"PARADE":
				parade_unit = id
			"WISP":
				wisp_unit = id
