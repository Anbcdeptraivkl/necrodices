class_name NightGen
extends RefCounted
## Night generation (GAME_SPEC §7.2, §6.9): Mob and Champion from their pools (ENEMY stream),
## the boss by the selection rules (BOSS stream), the equipment offer (SHOP stream). Rolled once
## when the night starts and stored in the run.


static func generate(db: ContentDb, run: RunState) -> void:
	run.night_plan.clear()
	for role: String in ["MOB", "CHAMPION"]:
		var enemy: String = run.rng.pick("ENEMY", _pool(db, role))
		run.night_plan.append(_entry(db, run.night, enemy, role, []))
	run.night_plan.append(_boss(db, run))
	run.encounter_index = 0
	run.equipment_offer = _equipment_offer(db, run)
	run.equipment_sold = false


static func _pool(db: ContentDb, role: String) -> Array:
	var out: Array = []
	for id: String in db.enemies:
		if db.enemies[id]["role"] == role:
			out.append(id)
	return out


static func _entry(db: ContentDb, night: int, enemy: String, role: String, rules: Array) -> Dictionary:
	return {"enemy": enemy, "role": role, "rules": rules, "hp": Economy.hp_for(db, night, role, rules)}


static func _boss(db: ContentDb, run: RunState) -> Dictionary:
	var sel: Dictionary = db.raw["enemies"]["boss_selection"]
	var bosses := _pool(db, "BOSS")
	if run.night >= int(sel["enraged_night"]):
		var sprite: String = run.rng.pick("BOSS", bosses)
		var rules: Array = []
		for id: String in bosses:
			rules.append(db.enemies[id]["rule"])
		var picked: Array = ["ENRAGED"]
		for i in int(sel["enraged_rule_count"]):
			var rule: String = run.rng.pick("BOSS", rules)
			rules.erase(rule)
			picked.append(rule)
		return _entry(db, run.night, sprite, "BOSS", picked)
	var candidates: Array = []
	for id: String in bosses:
		var rule: String = db.enemies[id]["rule"]
		if run.night == 1 and not (sel["night1_pool"] as Array).has(rule):
			continue
		if sel["no_repeat"] and rule == run.last_boss_rule:
			continue
		candidates.append(id)
	var boss: String = run.rng.pick("BOSS", candidates)
	run.last_boss_rule = db.enemies[boss]["rule"]
	return _entry(db, run.night, boss, "BOSS", [run.last_boss_rule])


static func _equipment_offer(db: ContentDb, run: RunState) -> String:
	var eligible: Array = []
	for id: String in db.equipment:
		var req: Variant = db.equipment[id]["requires"]
		if not run.equipment.has(id) and (req == null or run.equipment.has(req)):
			eligible.append(id)
	if eligible.is_empty():
		return ""
	return run.rng.pick("SHOP", eligible)


## Rules active in an encounter entry, with Enraged expanded to its two concrete rules.
static func active_rules(entry: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for rule: String in entry["rules"]:
		if rule != "ENRAGED":
			out.append(rule)
	return out
