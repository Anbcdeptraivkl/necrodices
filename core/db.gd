class_name ContentDb
extends RefCounted
## Loads and validates every content file in res://data (GAME_SPEC §9). Rows are kept as
## dictionaries keyed by id, plus the lookup tables the rules need (units by kind and element,
## combos in rank order, rituals). Unknown or inconsistent data is reported in `errors` and
## fails the boot — never skipped silently.
## Player-facing text lives apart from the rules, in res://data/text (designer-edited):
## `ui/*.json` = flat key -> string per screen, merged into `strings`; `content/*.json` = names,
## effects and lore per id, merged into the rows (`name`, `text`, `lore`, `short`).

const FILES := ["elements", "combos", "units", "relics", "consumables", "coffers", "equipment",
	"enemies", "curve", "economy"]
const UI_TEXT := ["common", "battle", "market", "spoils", "tooltips", "codex", "tutorial", "settings",
	"end_screen"]
## content text file -> [db table, {text field -> row field}]
const CONTENT_TEXT := {
	"units": ["units", {"name": "name", "lore": "lore"}],
	"combos": ["combos", {"name": "name", "pattern": "text", "lore": "lore"}],
	"trinkets": ["relics", {"name": "name", "effect": "text", "lore": "lore"}],
	"potions": ["consumables", {"name": "name", "effect": "text", "lore": "lore"}],
	"gems": ["consumables", {"name": "name", "effect": "text", "lore": "lore"}],
	"gear": ["equipment", {"name": "name", "effect": "text", "lore": "lore"}],
	"coffers": ["coffers", {"name": "name", "lore": "lore"}],
}
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
## Rune id -> {name, effect, lore} (runes are rules in economy.json; their words live here).
var runes := {}
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
	_load_text(dir.path_join("text"))
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


func _load_text(dir: String) -> void:
	strings = {}
	for name: String in UI_TEXT:
		var d: Variant = JsonUtil.load_file(dir.path_join("ui/%s.json" % name), errors)
		if d is Dictionary:
			for key: String in d:
				if strings.has(key):
					errors.append("text: key %s in two ui files" % key)
				strings[key] = d[key]
	for name: String in CONTENT_TEXT:
		var spec: Array = CONTENT_TEXT[name]
		_merge_text(dir.path_join("content/%s.json" % name), get(spec[0]), spec[1])
	var h: Variant = JsonUtil.load_file(dir.path_join("content/hunters.json"), errors)
	if h is Dictionary:
		_merge(h["hunters"], enemies, {"name": "name", "lore": "lore"}, "hunters")
		_merge(h["rules"], boss_rules, {"name": "name", "short": "short", "effect": "text"}, "rules")
	var r: Variant = JsonUtil.load_file(dir.path_join("content/runes.json"), errors)
	runes = r if r is Dictionary else {}
	for table: String in ["units", "combos", "relics", "consumables", "equipment", "coffers", "enemies"]:
		for id: String in get(table):
			if not (get(table)[id] as Dictionary).has("name"):
				errors.append("text: %s %s has no name" % [table, id])


func _merge_text(path: String, table: Dictionary, fields: Dictionary) -> void:
	var d: Variant = JsonUtil.load_file(path, errors)
	if d is Dictionary:
		_merge(d, table, fields, path.get_file())


func _merge(entries: Dictionary, table: Dictionary, fields: Dictionary, what: String) -> void:
	for id: String in entries:
		if not table.has(id):
			errors.append("text %s: unknown id %s" % [what, id])
			continue
		for f: String in fields:
			if entries[id].has(f):
				table[id][fields[f]] = entries[id][f]


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
