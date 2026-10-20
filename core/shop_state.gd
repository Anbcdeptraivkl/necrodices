class_name ShopState
extends RefCounted
## One shop visit (GAME_SPEC §4.6): three item slots rolled on entry (SHOP stream) and stored
## in the run, a reroll counter that resets per visit, and the buy / sell / reroll commands.
## The night's equipment offer lives on the run (one per night).

const KIND_RELIC := "RELIC"
const KIND_CONSUMABLE := "CONSUMABLE"

## {kind, id, price, sold}
var items: Array[Dictionary] = []
var reroll_count := 0


static func open(db: ContentDb, run: RunState) -> ShopState:
	var shop := ShopState.new()
	shop._roll_items(db, run)
	return shop


func reroll_cost(db: ContentDb, run: RunState) -> int:
	var e := db.economy
	var cost := int(e["shop_reroll_base"]) + int(e["shop_reroll_step"]) * reroll_count
	cost -= run.equipment_bonus("shop_reroll_discount", db)
	return maxi(int(e["shop_reroll_min"]), cost)


func can_reroll(db: ContentDb, run: RunState) -> bool:
	return run.money >= reroll_cost(db, run)


func reroll(db: ContentDb, run: RunState) -> bool:
	if not can_reroll(db, run):
		return false
	run.money -= reroll_cost(db, run)
	reroll_count += 1
	_roll_items(db, run)
	return true


func can_buy(db: ContentDb, run: RunState, slot: int) -> bool:
	if slot < 0 or slot >= items.size() or items[slot]["sold"] or run.money < items[slot]["price"]:
		return false
	if items[slot]["kind"] == KIND_RELIC:
		return run.relics.size() < run.relic_slots(db)
	return run.consumables.size() < run.consumable_slots(db)


func buy(db: ContentDb, run: RunState, slot: int) -> bool:
	if not can_buy(db, run, slot):
		return false
	var item := items[slot]
	run.money -= item["price"]
	item["sold"] = true
	if item["kind"] == KIND_RELIC:
		run.relics.append(RelicInstance.new(item["id"]))
	else:
		run.consumables.append(item["id"])
	return true


## Buy & Use: consumables only, no slot needed (§4.6).
func can_buy_use(db: ContentDb, run: RunState, slot: int, targets: Array[Vector2i]) -> bool:
	if slot < 0 or slot >= items.size() or items[slot]["sold"] or items[slot]["kind"] != KIND_CONSUMABLE:
		return false
	return run.money >= items[slot]["price"] and ConsumableFx.can_apply(db, run, items[slot]["id"], targets)


func buy_use(db: ContentDb, run: RunState, slot: int, targets: Array[Vector2i]) -> bool:
	if not can_buy_use(db, run, slot, targets):
		return false
	run.money -= items[slot]["price"]
	items[slot]["sold"] = true
	return ConsumableFx.apply(db, run, items[slot]["id"], targets)


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
	# Dice equipment adds its dice now (the other effects are read when an encounter starts).
	for i in int(db.equipment[id]["effect"].get("dice", 0)):
		if run.dice.size() < int(db.economy["max_dice"]):
			run.dice.append(Die.standard())
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


func _roll_items(db: ContentDb, run: RunState) -> void:
	items.clear()
	var e := db.economy
	var cat_weights: Dictionary = e["shop_category_weights"]
	for i in int(e["shop_item_slots"]):
		var category: String = run.rng.pick_weighted("SHOP", cat_weights.keys(), cat_weights.values())
		var id := _pick_relic(db, run) if category == "RELIC" else ""
		if id != "":
			items.append({"kind": KIND_RELIC, "id": id, "price": int(db.relics[id]["price"]), "sold": false})
			continue
		if category == "RELIC":
			category = "TOME"  # every relic owned or offered: fall back to a consumable
		var pool := _consumables_of(db, category)
		id = run.rng.pick("SHOP", pool)
		items.append({"kind": KIND_CONSUMABLE, "id": id, "price": int(db.consumables[id]["price"]), "sold": false})


## Rarity by weight, then a relic not owned and not already offered; a rarity with nothing
## left falls back to the remaining rarities in weight order.
func _pick_relic(db: ContentDb, run: RunState) -> String:
	var weights: Dictionary = db.economy["relic_rarity_weights"]
	var rarity: String = run.rng.pick_weighted("SHOP", weights.keys(), weights.values())
	var order: Array = [rarity]
	for r: String in weights:
		if r != rarity:
			order.append(r)
	for r: String in order:
		var pool: Array = []
		for id: String in db.relics:
			if db.relics[id]["rarity"] == r and not run.has_relic(id) and not _offered(id):
				pool.append(id)
		if not pool.is_empty():
			return run.rng.pick("SHOP", pool)
	return ""


func _offered(id: String) -> bool:
	return items.any(func(item: Dictionary) -> bool: return item["id"] == id)


static func _consumables_of(db: ContentDb, kind: String) -> Array:
	var out: Array = []
	for id: String in db.consumables:
		if db.consumables[id]["kind"] == kind:
			out.append(id)
	return out


func to_dict() -> Dictionary:
	return {"items": items.duplicate(true), "reroll_count": reroll_count}


static func from_dict(d: Dictionary) -> ShopState:
	var shop := ShopState.new()
	for item: Dictionary in d["items"]:
		shop.items.append(item.duplicate())
	shop.reroll_count = d["reroll_count"]
	return shop
