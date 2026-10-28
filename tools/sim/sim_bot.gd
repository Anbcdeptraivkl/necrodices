class_name SimBot
extends RefCounted
## Balance bot (GAME_SPEC §12). It plays through the same EncounterState / ShopState / RunFlow
## commands the UI uses, so a bot result is evidence about the real rules (balance evidence
## only — never fun evidence).
## Battle: roll; while the best squad is weaker than a Trio and rerolls are left, keep the dice
## of the most common element and reroll up to five others; summon the strongest preview;
## attack as soon as the army beats the HP (or the summons run out).
## Market: best trinket, a die when affordable, gems for its most-used combo, coffers it can
## use at once, gear — keeping $5 from Night 2 for interest.

const KEEP_FROM_NIGHT := 2
const KEEP := 5

var db: ContentDb
var combo_tally := {}


func _init(p_db: ContentDb) -> void:
	db = p_db


func free_dice(enc: EncounterState) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in enc.tray_size:
		if i != enc.shackled:
			out.append(i)
	return out


## The pick (tray indices) with the strongest preview among subsets of min(5, free) dice.
func best_pick(enc: EncounterState) -> PackedInt32Array:
	var free := free_dice(enc)
	var size := mini(int(db.economy["pick_max"]), free.size())
	var best := PackedInt32Array()
	var best_v := -1.0
	for subset: PackedInt32Array in combinations(free, size):
		enc.picked = subset
		var p := enc.preview()
		if p != null and p.result.strength > best_v:
			best_v = p.result.strength
			best = subset
	enc.picked = PackedInt32Array()
	return best


static func combinations(items: PackedInt32Array, k: int) -> Array:
	var out: Array = []
	if k == 0:
		out.append(PackedInt32Array())
		return out
	for n in range(items.size() - k + 1):
		for tail: PackedInt32Array in combinations(items.slice(n + 1), k - 1):
			var c := PackedInt32Array([items[n]])
			c.append_array(tail)
			out.append(c)
	return out


func _combo_rank(enc: EncounterState, pick: PackedInt32Array) -> int:
	enc.picked = pick
	var p := enc.preview()
	enc.picked = PackedInt32Array()
	return int(db.combos[p.combo]["rank"]) if p != null else 0


## Dice to reroll: everything not showing the most common element (BONE counts double as a tie
## breaker by points), at most pick_max.
func reroll_set(enc: EncounterState) -> PackedInt32Array:
	var count := {}
	for i in free_dice(enc):
		var f := enc.face_at(i)
		var e := "" if f.is_tomb() else f.element
		count[e] = count.get(e, 0) * 1.0 + 1.0 + f.points * 0.01
	var keep := ""
	for e: String in count:
		if e != "" and (keep == "" or count[e] > count[keep]):
			keep = e
	var out := PackedInt32Array()
	for i in free_dice(enc):
		var f := enc.face_at(i)
		if out.size() < int(db.economy["pick_max"]) and (f.is_tomb() or f.element != keep) and f.rune == "":
			out.append(i)
	return out


func play_encounter(enc: EncounterState) -> void:
	var trio_rank := int(db.combos["TRIO"]["rank"])
	while enc.phase != EncounterState.Phase.DONE:
		if enc.phase == EncounterState.Phase.AWAIT_ROLL:
			# Attack as soon as the army is enough (unused summons pay), or when out of summons.
			if enc.can(EncounterState.Verb.ATTACK) and (enc.army_resolution().damage >= enc.hp
					or not enc.can(EncounterState.Verb.ROLL)):
				enc.attack()
				return
			enc.roll()
		var best := best_pick(enc)
		if enc.rerolls_left > 0 and _combo_rank(enc, best) < trio_rank:
			var again := reroll_set(enc)
			if not again.is_empty():
				enc.picked = again
				if enc.reroll():
					continue
		enc.picked = best
		var p := enc.preview()
		if p != null:
			combo_tally[p.combo] = combo_tally.get(p.combo, 0) + 1
		if not enc.summon():
			push_error("bot could not summon")
			return


func play_shop(run: RunState) -> void:
	var shop := run.shop
	var keep := KEEP if run.night >= KEEP_FROM_NIGHT else 0
	var rank := {"RARE": 3, "UNCOMMON": 2, "COMMON": 1}
	var order: Array = range(shop.cards.size())
	order.sort_custom(func(a: int, b: int) -> bool: return _value(shop.cards[a], rank) > _value(shop.cards[b], rank))
	for i: int in order:
		var item := shop.cards[i]
		if item["sold"] or (run.money - int(item["price"]) < keep and item["kind"] != ShopState.KIND_RELIC):
			continue
		if item["kind"] == ShopState.KIND_GEM:
			if item["id"] == _favourite_gem():
				shop.buy_use(db, run, i, _none())
		elif item["kind"] != ShopState.KIND_POTION:
			shop.buy(db, run, i)
	for i in shop.coffers.size():
		var kind: String = db.coffers[shop.coffers[i]["id"]]["kind"]
		if kind in ["TRINKET", "BONE", "GEM"] and run.money - int(shop.coffers[i]["price"]) >= keep:
			if shop.buy_coffer(db, run, i):
				_take_best(run)
	if ShopState.can_buy_equipment(db, run) and run.money - int(db.equipment[run.equipment_offer]["price"]) >= keep:
		ShopState.buy_equipment(db, run)


func _value(item: Dictionary, rank: Dictionary) -> int:
	match item["kind"]:
		ShopState.KIND_RELIC:
			return 10 + rank[db.relics[item["id"]]["rarity"]]
		ShopState.KIND_DIE:
			return 9
		ShopState.KIND_GEM:
			return 5 if item["id"] == _favourite_gem() else 0
	return 0


func _take_best(run: RunState) -> void:
	var shop := run.shop
	while not shop.open_coffer.is_empty():
		var choices: Array = shop.open_coffer["choices"]
		var took := false
		var fav := _favourite_gem()
		for c in choices.size():
			var item: Dictionary = choices[c]
			if item["kind"] == ShopState.KIND_GEM and item["id"] != fav and choices.any(
					func(x: Dictionary) -> bool: return x["id"] == fav and not x["taken"]):
				continue
			if shop.take(db, run, c, _none()):
				took = true
				break
		if not took:
			shop.skip_coffer()


func _favourite_gem() -> String:
	var best := "TRIO"
	for c: String in combo_tally:
		if combo_tally[c] > combo_tally.get(best, 0):
			best = c
	for id: String in db.consumables:
		if db.consumables[id]["kind"] == "GEM" and db.consumables[id]["combo"] == best:
			return id
	return ""


static func _none() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	return out


## Plays a whole run; returns {night, won, best, died, ratios, relics, money, dice}.
func play_run(seed: String) -> Dictionary:
	combo_tally.clear()
	var run := RunFlow.new_run(db, seed)
	var reached := 1
	var died := ""
	var ratios := {}   # night -> Array of damage / HP
	while run.phase == RunState.Phase.NIGHT_MAP:
		reached = run.night
		var enc := RunFlow.start_encounter(db, run)
		enc.begin()
		play_encounter(enc)
		if not ratios.has(run.night):
			ratios[run.night] = []
		ratios[run.night].append(enc.resolution.damage / enc.hp)
		if not enc.win:
			died = "%d-%s%s" % [run.night, enc.entry["role"], "" if enc.rules.is_empty() else "-" + "+".join(enc.rules)]
		RunFlow.finish_encounter(db, run, enc)
		if run.phase == RunState.Phase.SHOP:
			play_shop(run)
			RunFlow.leave_shop(run)
	return {"night": reached, "won": run.phase == RunState.Phase.VICTORY, "best": run.stats["best_damage"],
		"died": died, "ratios": ratios, "relics": run.relics.size(), "money": run.money, "dice": run.dice.size()}
