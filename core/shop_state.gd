class_name ShopState
extends RefCounted
## One Crypt Market visit (GAME_SPEC §7): item cards and coffers rolled on entry (SHOP / DICE
## streams) and stored in the run, a reroll counter that resets per visit, the coffer being
## opened (its choices are rolled on purchase and stored, so Continue restores it) and the
## buy / buy & use / open / take / sell / reroll commands. The night's gear lives on the run.

const KIND_RELIC := "RELIC"
const KIND_POTION := "POTION"
const KIND_GEM := "GEM"
const KIND_DIE := "DIE"
## Card category (economy weights) / coffer kind -> item kind.
const CATEGORY_KIND := {"TRINKET": KIND_RELIC, "POTION": KIND_POTION, "GEM": KIND_GEM, "DIE": KIND_DIE,
	"BONE": KIND_DIE}

## {kind, id, price, sold, die?: Array (Die.to_dict)}
var cards: Array[Dictionary] = []
## {id, price, sold}
var coffers: Array[Dictionary] = []
## {} or {id, kind, picks_left, choices: [{kind, id, die?, taken}]}
var open_coffer := {}
var reroll_count := 0


static func open(db: ContentDb, run: RunState) -> ShopState:
	var shop := ShopState.new()
	shop._roll_cards(db, run)
	shop._roll_coffers(db, run)
	return shop


func reroll_cost(db: ContentDb, run: RunState) -> int:
	var e := db.economy
	var cost := int(e["shop_reroll_base"]) + int(e["shop_reroll_step"]) * reroll_count
	cost -= run.equipment_bonus("shop_reroll_discount", db)
	return maxi(int(e["shop_reroll_min"]), cost)


func can_reroll(db: ContentDb, run: RunState) -> bool:
	return open_coffer.is_empty() and run.money >= reroll_cost(db, run)


func reroll(db: ContentDb, run: RunState) -> bool:
	if not can_reroll(db, run):
		return false
	run.money -= reroll_cost(db, run)
	reroll_count += 1
	_roll_cards(db, run)
	return true


func can_buy(db: ContentDb, run: RunState, slot: int) -> bool:
	if not open_coffer.is_empty() or slot < 0 or slot >= cards.size() or cards[slot]["sold"]:
		return false
	return run.money >= int(cards[slot]["price"]) and has_room(db, run, cards[slot]["kind"])


func buy(db: ContentDb, run: RunState, slot: int) -> bool:
	if not can_buy(db, run, slot):
		return false
	var item := cards[slot]
	run.money -= int(item["price"])
	item["sold"] = true
	_receive(run, item)
	return true


## Buy & Use: potions / gems only, no slot needed.
func can_buy_use(db: ContentDb, run: RunState, slot: int, targets: Array[Vector2i]) -> bool:
	if not open_coffer.is_empty() or slot < 0 or slot >= cards.size() or cards[slot]["sold"]:
		return false
	if not cards[slot]["kind"] in [KIND_POTION, KIND_GEM]:
		return false
	return run.money >= int(cards[slot]["price"]) and ConsumableFx.can_apply(db, run, cards[slot]["id"], targets)


func buy_use(db: ContentDb, run: RunState, slot: int, targets: Array[Vector2i]) -> bool:
	if not can_buy_use(db, run, slot, targets):
		return false
	run.money -= int(cards[slot]["price"])
	cards[slot]["sold"] = true
	return ConsumableFx.apply(db, run, cards[slot]["id"], targets)


func can_buy_coffer(_db: ContentDb, run: RunState, i: int) -> bool:
	return open_coffer.is_empty() and i >= 0 and i < coffers.size() and not coffers[i]["sold"] \
		and run.money >= int(coffers[i]["price"])


## Buys and opens a coffer: its choices are rolled now and stored.
func buy_coffer(db: ContentDb, run: RunState, i: int) -> bool:
	if not can_buy_coffer(db, run, i):
		return false
	var row: Dictionary = db.coffers[coffers[i]["id"]]
	run.money -= int(coffers[i]["price"])
	coffers[i]["sold"] = true
	var kind: String = CATEGORY_KIND[row["kind"]]
	var choices: Array = []
	for item in _roll_kind(db, run, kind, int(row["choices"])):
		item["taken"] = false
		choices.append(item)
	open_coffer = {"id": row["id"], "kind": kind, "picks_left": int(row["picks"]), "choices": choices}
	return true


## Taking a coffer choice: potions / gems are used at once (targets), trinkets need a free
## slot, dice need room in the set.
func can_take(db: ContentDb, run: RunState, c: int, targets: Array[Vector2i]) -> bool:
	if open_coffer.is_empty() or c < 0 or c >= open_coffer["choices"].size():
		return false
	var item: Dictionary = open_coffer["choices"][c]
	if item["taken"]:
		return false
	if item["kind"] in [KIND_POTION, KIND_GEM]:
		return ConsumableFx.can_apply(db, run, item["id"], targets)
	return has_room(db, run, item["kind"])


func take(db: ContentDb, run: RunState, c: int, targets: Array[Vector2i]) -> bool:
	if not can_take(db, run, c, targets):
		return false
	var item: Dictionary = open_coffer["choices"][c]
	if item["kind"] in [KIND_POTION, KIND_GEM]:
		ConsumableFx.apply(db, run, item["id"], targets)
	else:
		_receive(run, item)
	item["taken"] = true
	open_coffer["picks_left"] = int(open_coffer["picks_left"]) - 1
	if open_coffer["picks_left"] <= 0:
		open_coffer = {}
	return true


func skip_coffer() -> bool:
	if open_coffer.is_empty():
		return false
	open_coffer = {}
	return true


## Whether an item of this kind fits: trinket slots, potion / gem slots, dice below the max.
static func has_room(db: ContentDb, run: RunState, kind: String) -> bool:
	match kind:
		KIND_RELIC:
			return run.relics.size() < run.relic_slots(db)
		KIND_DIE:
			return run.dice.size() < int(db.economy["max_dice"])
	return run.consumables.size() < run.consumable_slots(db)


static func can_buy_equipment(db: ContentDb, run: RunState) -> bool:
	return run.equipment_offer != "" and not run.equipment_sold \
		and run.money >= int(db.equipment[run.equipment_offer]["price"])


static func buy_equipment(db: ContentDb, run: RunState) -> bool:
	if not can_buy_equipment(db, run):
		return false
	var id := run.equipment_offer
	run.money -= int(db.equipment[id]["price"])
	run.equipment.append(id)
	run.equipment_sold = true
	return true


static func sell_relic(db: ContentDb, run: RunState, index: int) -> bool:
	if index < 0 or index >= run.relics.size():
		return false
	run.money += Economy.sell_price_relic(db, run.relics[index].id)
	run.relics.remove_at(index)
	return true


static func sell_consumable(db: ContentDb, run: RunState, index: int) -> bool:
	if index < 0 or index >= run.consumables.size():
		return false
	run.money += Economy.sell_price_consumable(db)
	run.consumables.remove_at(index)
	return true


static func _receive(run: RunState, item: Dictionary) -> void:
	match item["kind"]:
		KIND_RELIC:
			run.relics.append(RelicInstance.new(item["id"]))
		KIND_DIE:
			run.dice.append(Die.from_dict(item["die"]))
		_:
			run.consumables.append(item["id"])


func _roll_cards(db: ContentDb, run: RunState) -> void:
	cards.clear()
	var weights: Dictionary = db.economy["shop_card_weights"]
	var slots := int(db.economy["shop_card_slots"]) + run.equipment_bonus("shop_card_slots", db)
	for i in slots:
		var category: String = run.rng.pick_weighted("SHOP", weights.keys(), weights.values())
		var item: Dictionary = _roll_kind(db, run, CATEGORY_KIND[category], 1)[0]
		item["sold"] = false
		cards.append(item)


## Coffers: kind and size by weight; the first visit of a run guarantees the configured kind.
func _roll_coffers(db: ContentDb, run: RunState) -> void:
	coffers.clear()
	var data: Dictionary = db.raw["coffers"]
	for i in int(db.economy["shop_coffer_slots"]):
		var kind: String = run.rng.pick_weighted("SHOP", data["kind_weights"].keys(), data["kind_weights"].values())
		if i == 0 and run.shop_visits == 0:
			kind = data["first_visit_kind"]
		var size: String = run.rng.pick_weighted("SHOP", data["size_weights"].keys(), data["size_weights"].values())
		for id: String in db.coffers:
			if db.coffers[id]["kind"] == kind and db.coffers[id]["size"] == size:
				coffers.append({"id": id, "price": int(db.coffers[id]["price"]), "sold": false})
				break


## `n` items of one kind, distinct where the pool allows: [{kind, id, price, die?}].
## Trinkets exclude owned and already offered ones (falling back to potions when none are left).
func _roll_kind(db: ContentDb, run: RunState, kind: String, n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in n:
		match kind:
			KIND_RELIC:
				var id := _pick_relic(db, run, out)
				if id == "":
					out.append(_consumable_item(db, run, KIND_POTION, out))
				else:
					out.append({"kind": KIND_RELIC, "id": id, "price": int(db.relics[id]["price"])})
			KIND_DIE:
				var die := new_die(db, run)
				out.append({"kind": KIND_DIE, "id": "DIE", "price": Economy.die_price(db, die), "die": die.to_dict()})
			_:
				out.append(_consumable_item(db, run, kind, out))
	return out


func _consumable_item(db: ContentDb, run: RunState, kind: String, taken: Array[Dictionary]) -> Dictionary:
	var pool: Array = []
	for id in db.ids_of_kind(db.consumables, kind):
		if not taken.any(func(x: Dictionary) -> bool: return x["id"] == id):
			pool.append(id)
	if pool.is_empty():
		pool = db.ids_of_kind(db.consumables, kind)
	var id: String = run.rng.pick("SHOP", pool)
	return {"kind": kind, "id": id, "price": int(db.consumables[id]["price"])}


## A market die (§6.5): shuffled points, and a rune on one non-BONE face at `die_rune_chance`.
static func new_die(db: ContentDb, run: RunState) -> Die:
	var rng := run.rng.stream("DICE")
	var die := Die.random(rng)
	if rng.randf() < float(db.economy["die_rune_chance"]):
		var weights: Dictionary = db.economy["die_rune_weights"]
		var rune: String = run.rng.pick_weighted("DICE", weights.keys(), weights.values())
		die.faces[rng.randi_range(1, Die.FACE_COUNT - 1)].rune = rune
	return die


## Rarity by weight, then a trinket not owned and not on offer; a rarity with nothing left
## falls back to the remaining rarities in weight order.
func _pick_relic(db: ContentDb, run: RunState, extra: Array[Dictionary]) -> String:
	var weights: Dictionary = db.economy["relic_rarity_weights"]
	var rarity: String = run.rng.pick_weighted("SHOP", weights.keys(), weights.values())
	var order: Array = [rarity]
	for r: String in weights:
		if r != rarity:
			order.append(r)
	for r: String in order:
		var pool: Array = []
		for id: String in db.relics:
			if db.relics[id]["rarity"] == r and not run.has_relic(id) and not _offered(id, extra):
				pool.append(id)
		if not pool.is_empty():
			return run.rng.pick("SHOP", pool)
	return ""


func _offered(id: String, extra: Array[Dictionary]) -> bool:
	var has := func(item: Dictionary) -> bool: return item["id"] == id
	if cards.any(has) or extra.any(has):
		return true
	return not open_coffer.is_empty() and (open_coffer["choices"] as Array).any(has)


func to_dict() -> Dictionary:
	return {"cards": cards.duplicate(true), "coffers": coffers.duplicate(true),
		"open_coffer": open_coffer.duplicate(true), "reroll_count": reroll_count}


static func from_dict(d: Dictionary) -> ShopState:
	var shop := ShopState.new()
	for item: Dictionary in d["cards"]:
		shop.cards.append(item.duplicate(true))
	for item: Dictionary in d["coffers"]:
		shop.coffers.append(item.duplicate(true))
	shop.open_coffer = d["open_coffer"].duplicate(true)
	shop.reroll_count = d["reroll_count"]
	return shop
