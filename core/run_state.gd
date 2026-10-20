class_name RunState
extends RefCounted
## Everything a run owns (GAME_SPEC §4.1, §7, §12.1), as plain data. The phase is stored, so a
## loaded save routes on it. Mutations happen through RunFlow / ShopState / EncounterState /
## ConsumableFx commands, which validate first.

enum Phase { NIGHT_MAP, ENCOUNTER, SHOP, GAME_OVER, VICTORY }

const SAVE_VERSION := 1

var seed := ""
var phase: Phase = Phase.NIGHT_MAP
var money := 0
var dice: Array[Die] = []
var relics: Array[RelicInstance] = []
var consumables: PackedStringArray = []
var levels := {}              # unit id -> level
var night := 1
var encounter_index := 0      # 0 Mob, 1 Champion, 2 Boss within the night
## The night's three encounters: {enemy, role, rules: Array, hp}.
var night_plan: Array[Dictionary] = []
var equipment: PackedStringArray = []
var equipment_offer := ""     # "" = nothing on offer this night
var equipment_sold := false
var bosses_defeated := 0
var last_boss_rule := ""
var shop: ShopState            # set while phase == SHOP
var stats := {"best_damage": 0.0, "summons": {}, "wins": 0}
var rng: RngStreams
## Debug overrides (GAME_SPEC M3): never saved, never read by content code.
var debug_hp_mult := 1.0


func current_encounter() -> Dictionary:
	return night_plan[encounter_index]


func equipment_bonus(key: String, db: ContentDb) -> int:
	var total := 0
	for id in equipment:
		total += int(db.equipment[id]["effect"].get(key, 0))
	return total


func relic_slots(db: ContentDb) -> int:
	return int(db.economy["relic_slots"]) + equipment_bonus("relic_slots", db)


func consumable_slots(db: ContentDb) -> int:
	return int(db.economy["consumable_slots"]) + equipment_bonus("consumable_slots", db)


func level_of(unit_id: String) -> int:
	return levels.get(unit_id, 1)


func has_relic(id: String) -> bool:
	return relics.any(func(r: RelicInstance) -> bool: return r.id == id)


func record_summon(unit_id: String) -> void:
	var counts: Dictionary = stats["summons"]
	counts[unit_id] = counts.get(unit_id, 0) + 1


func most_summoned() -> String:
	var best := ""
	var counts: Dictionary = stats["summons"]
	for id: String in counts:
		if best == "" or counts[id] > counts[best]:
			best = id
	return best


func to_dict() -> Dictionary:
	var ds: Array = []
	for d in dice:
		ds.append(d.to_dict())
	var rs: Array = []
	for r in relics:
		rs.append(r.to_dict())
	return {
		"version": SAVE_VERSION, "seed": seed, "phase": Phase.keys()[phase], "money": money,
		"dice": ds, "relics": rs, "consumables": Array(consumables), "levels": levels.duplicate(),
		"night": night, "encounter_index": encounter_index, "night_plan": night_plan.duplicate(true),
		"equipment": Array(equipment), "equipment_offer": equipment_offer,
		"equipment_sold": equipment_sold, "bosses_defeated": bosses_defeated,
		"last_boss_rule": last_boss_rule, "shop": shop.to_dict() if shop != null else null,
		"stats": stats.duplicate(true), "rng": rng.to_dict(),
	}


static func from_dict(d: Dictionary) -> RunState:
	var run := RunState.new()
	run.seed = d["seed"]
	run.phase = Phase.keys().find(d["phase"]) as Phase
	run.money = d["money"]
	for dd: Array in d["dice"]:
		run.dice.append(Die.from_dict(dd))
	for rd: Dictionary in d["relics"]:
		run.relics.append(RelicInstance.from_dict(rd))
	run.consumables = PackedStringArray(d["consumables"])
	run.levels = d["levels"].duplicate()
	run.night = d["night"]
	run.encounter_index = d["encounter_index"]
	for e: Dictionary in d["night_plan"]:
		run.night_plan.append(e.duplicate(true))
	run.equipment = PackedStringArray(d["equipment"])
	run.equipment_offer = d["equipment_offer"]
	run.equipment_sold = d["equipment_sold"]
	run.bosses_defeated = d["bosses_defeated"]
	run.last_boss_rule = d["last_boss_rule"]
	if d["shop"] != null:
		run.shop = ShopState.from_dict(d["shop"])
	run.stats = d["stats"].duplicate(true)
	run.rng = RngStreams.from_dict(run.seed, d["rng"])
	return run
