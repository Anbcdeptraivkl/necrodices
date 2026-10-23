extends TestSuite
## Run loop, spoils, market, coffers, gear, save and determinism (GAME_SPEC §4.1, §4.8, §7, §13, §15).

const COVERS: Array[String] = ["core/run_state.gd", "core/run_flow.gd", "core/economy.gd",
	"core/shop_state.gd", "core/consumable_fx.gd", "core/save_store.gd", "core/rng_streams.gd",
	"core/night_gen.gd", "core/number_format.gd", "core/die.gd", "core/face.gd",
	"data/economy.json", "data/curve.json", "data/coffers.json"]

const SAVE_DIR := "user://sav_test"


func test_new_run_setup() -> void:
	var run := Fixtures.run()
	_eq(run.money, 4, "start money")
	_eq(run.dice.size(), 5, "start dice")
	_eq(run.night_plan.size(), 3, "three battles")
	var layouts := {}
	for d in run.dice:
		_eq(d.faces[0].element, "BONE", "face 0 is BONE")
		_eq(d.faces[0].points, 6, "BONE is 6")
		var pts: Array = []
		for k in range(1, 6):
			pts.append(d.faces[k].points)
			_eq(d.faces[k].element, RulesRegistry.ELEMENTS[k], "faces in element order")
		var sorted := pts.duplicate()
		sorted.sort()
		_eq(sorted, [1, 2, 3, 4, 5], "points 1..5 once each")
		layouts[str(pts)] = true
	_check(layouts.size() > 1, "dice differ from each other")
	var db := Fixtures.db()
	var base: float = db.curve["night_base"][0]
	_eq(run.night_plan[0]["hp"], roundf(base * db.curve["role_mult"]["MOB"]), "night 1 mob HP")
	_check(run.night_plan[2]["rules"][0] in ["EXORCIST", "BELL_RINGER"], "night 1 boss pool")


func test_hp_curve() -> void:
	var db := Fixtures.db()
	var nb: Array = db.curve["night_base"]
	var m := func(r: String) -> float: return float(db.boss_rules[r]["hp_mult"])
	_eq(Economy.hp_for(db, 8, "BOSS", ["ENRAGED", "EXORCIST", "INQUISITOR"]),
		roundf(float(nb[7]) * m.call("ENRAGED") * m.call("EXORCIST") * m.call("INQUISITOR")), "enraged = product")
	_eq(Economy.hp_for(db, 5, "CHAMPION", []), roundf(float(nb[4]) * db.curve["role_mult"]["CHAMPION"]), "champion")


func test_boss_never_repeats_and_enraged() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run("BOSSES01")
	var last := ""
	for night in range(1, 9):
		run.night = night
		NightGen.generate(db, run)
		var rules: Array = run.night_plan[2]["rules"]
		if night == 8:
			_eq(rules.size(), 3, "enraged + 2 rules")
			_eq(rules[0], "ENRAGED", "enraged first")
		else:
			_check(rules[0] != last, "night %d boss differs from the previous" % night)
			last = rules[0]


func test_spoils_lines() -> void:
	var db := Fixtures.db()
	var enc := Fixtures.battle([], 1.0, ["GRAVE_ROBBER"])
	Fixtures.set_tray(enc, ["FIRE1", "FIRE1", "FIRE1", "ICE2+GILDED"])
	Fixtures.pick(enc, [0, 1, 2])
	enc.summon()
	enc.run.money = 12
	var by_key := {}
	for l in Economy.spoils_lines(db, enc.run, enc):
		by_key[l["key"]] = l["amount"]
	_eq(by_key, {"spoils_bounty": 3, "spoils_unused_summons": 2, "spoils_interest": 2, "spoils_gilded": 3,
		"spoils_trinket": 2}, "bounty, 2 unused summons, interest on $12, a gilded face, Grave Robber")
	var lines := RunFlow.finish_encounter(db, enc.run, enc)
	_eq(enc.run.money, 12 + Economy.total(lines), "paid")
	_eq(enc.run.phase, RunState.Phase.SHOP, "to the market")
	var run := Fixtures.run()
	_eq(Economy.interest(db, run, 40), 5, "interest cap")


func test_final_boss_bounty() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run()
	run.night = 8
	run.night_plan[0] = {"enemy": "BOSS_EXORCIST", "role": "BOSS", "rules": ["EXORCIST"], "hp": 1.0}
	var enc := RunFlow.start_encounter(db, run)
	enc.begin()
	enc.roll()
	Fixtures.pick(enc, [0, 1, 2])
	enc.summon()
	_eq(Economy.spoils_lines(db, run, enc)[0]["amount"], int(db.economy["reward_final"]), "final bounty")
	RunFlow.finish_encounter(db, run, enc)
	_eq(run.phase, RunState.Phase.VICTORY, "victory")


func test_market_stock() -> void:
	var db := Fixtures.db()
	for s in 40:
		var run := Fixtures.run("SHOP%03d" % s)
		run.relics.append(RelicInstance.new("RATTLE_DRUM"))
		var shop := ShopState.open(db, run)
		_eq(shop.cards.size(), 2, "two cards")
		_eq(shop.coffers.size(), 2, "two coffers")
		_eq(db.coffers[shop.coffers[0]["id"]]["kind"], "TRINKET", "first visit: a trinket coffer")
		var ids := {}
		for item in shop.cards:
			if item["kind"] == ShopState.KIND_RELIC:
				_check(item["id"] != "RATTLE_DRUM", "owned trinket not offered")
				_check(not ids.has(item["id"]), "no duplicate offers")
				ids[item["id"]] = true
			if item["kind"] == ShopState.KIND_DIE:
				_eq(item["price"], Economy.die_price(db, Die.from_dict(item["die"])), "die price")


func test_reroll_cost() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run()
	run.money = 100
	var shop := ShopState.open(db, run)
	_eq(shop.reroll_cost(db, run), 5, "reroll $5")
	shop.reroll(db, run)
	_eq(shop.reroll_cost(db, run), 6, "then $6")
	_eq(ShopState.open(db, run).reroll_cost(db, run), 5, "resets per visit")
	run.equipment.append("HAGGLER_LANTERN")
	_eq(ShopState.open(db, run).reroll_cost(db, run), 3, "Haggler −$2")


func test_buy_sell_and_room() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run()
	run.money = 100
	var shop := ShopState.new()
	shop.cards = [{"kind": "RELIC", "id": "BONE_PILE", "price": 6, "sold": false},
		{"kind": "GEM", "id": "AMBER", "price": 3, "sold": false},
		{"kind": "DIE", "id": "DIE", "price": 8, "sold": false, "die": Die.standard().to_dict()}]
	_check(shop.buy(db, run, 0), "buy trinket")
	_check(not shop.buy(db, run, 0), "sold slot")
	_eq(run.money, 94, "paid $6")
	_check(ShopState.sell_relic(db, run, 0), "sell trinket")
	_eq(run.money, 97, "sold for floor(6 / 2)")
	run.consumables = PackedStringArray(["OPAL", "GARNET"])
	_check(not shop.can_buy(db, run, 1), "potion / gem slots full")
	_check(shop.buy_use(db, run, 1, Fixtures.no_targets()), "buy & use needs no slot")
	_eq(run.level_of("TRIO"), 2, "amber levelled trio")
	_check(shop.buy(db, run, 2), "buy a die")
	_eq(run.dice.size(), 6, "six dice")
	while run.dice.size() < 8:
		run.dice.append(Die.standard())
	_check(not ShopState.has_room(db, run, ShopState.KIND_DIE), "max 8 dice")


func test_coffer_open_take_skip() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run("COFFER01")
	run.money = 100
	var shop := ShopState.open(db, run)
	shop.coffers[0] = {"id": "COFFER_POTION_MEGA", "price": 8, "sold": false}
	_check(shop.buy_coffer(db, run, 0), "open a mega potion coffer")
	_eq(run.money, 92, "paid $8")
	_eq(shop.open_coffer["choices"].size(), 5, "5 choices")
	_check(not shop.can_buy(db, run, 0), "no card buying while a coffer is open")
	var first: Dictionary = shop.open_coffer["choices"][0]
	var targets: Array[Vector2i] = []
	for t in int(db.consumables[first["id"]]["min_targets"]):
		targets.append(Vector2i(t, 3))
	_check(shop.take(db, run, 0, targets), "take the first potion")
	_check(not shop.can_take(db, run, 0, targets), "taken once")
	_eq(shop.open_coffer["picks_left"], 1, "one pick left")
	_check(shop.skip_coffer(), "skip the rest")
	_check(shop.open_coffer.is_empty(), "closed")
	shop.coffers[1] = {"id": "COFFER_BONE", "price": 4, "sold": false}
	shop.buy_coffer(db, run, 1)
	var dice := run.dice.size()
	_check(shop.take(db, run, 2, Fixtures.no_targets()), "take a die")
	_eq(run.dice.size(), dice + 1, "die added")
	_check(shop.open_coffer.is_empty(), "single pick closes it")


func test_gear_prerequisite() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run("EQUIP001")
	for s in 50:
		run.equipment = PackedStringArray()
		run.rng = RngStreams.create("EQ%03d" % s)
		NightGen.generate(db, run)
		var offer := run.equipment_offer
		var req: Variant = db.equipment[offer]["requires"]
		_check(req == null, "no tier-2 gear without its tier 1 (%s)" % offer)
	run.money = 10
	run.equipment_offer = "GRAVE_BELL"
	run.equipment_sold = false
	_check(ShopState.buy_equipment(db, run), "buy grave bell")
	_eq(run.money, 0, "paid")


func test_save_round_trip() -> void:
	var store := SaveStore.new(SAVE_DIR)
	var db := Fixtures.db()
	var run := Fixtures.run("SAVE0001")
	run.relics.append(RelicInstance.new("OVERGROWTH", 3))
	run.consumables.append("AMBER")
	run.dice[0].faces[2].rune = "GLASS"
	run.levels["TRIO"] = 3
	run.money = 50
	run.shop = ShopState.open(db, run)
	run.shop.buy_coffer(db, run, 0)
	run.phase = RunState.Phase.SHOP
	_check(store.save_run(run), "saved")
	var loaded := store.load_run()
	# JSON has one number type: compare both sides narrowed the way the loader narrows.
	_eq(JSON.stringify(JsonUtil.narrow(loaded.to_dict()), "", true),
		JSON.stringify(JsonUtil.narrow(run.to_dict()), "", true), "round trip")
	_eq(loaded.rng.stream("DICE").randi(), run.rng.stream("DICE").randi(), "RNG state restored")
	_check(not loaded.shop.open_coffer.is_empty(), "the open coffer survives")
	store.delete_run()
	_check(not store.has_run(), "deleted")


func test_determinism_scripted_run() -> void:
	var a := _scripted_run("DETERM01")
	var b := _scripted_run("DETERM01")
	_eq(a, b, "same seed + inputs ⇒ same run")
	_check(a != _scripted_run("DETERM02"), "different seed differs")


func test_number_format() -> void:
	_eq(NumberFormat.format(2520), "2,520", "commas")
	_eq(NumberFormat.format(12345), "12.3K", "12.3K")
	_eq(NumberFormat.format(999600), "1M", "999.6K rounds to 1M")
	_eq(NumberFormat.format(1.23e15), "1.23e15", "scientific")
	_eq(NumberFormat.format(12345678, true), "12,345,678", "full setting")


## Plays 9 battles with a fixed policy (debug HP low) and returns the run hash.
func _scripted_run(seed: String) -> String:
	var db := Fixtures.db()
	var run := RunFlow.new_run(db, seed)
	run.debug_hp_mult = 0.01
	for n in 9:
		if run.phase != RunState.Phase.NIGHT_MAP:
			break
		var enc := RunFlow.start_encounter(db, run)
		enc.begin()
		while enc.phase != EncounterState.Phase.DONE:
			enc.roll()
			if enc.rerolls_left > 0:
				Fixtures.pick_free(enc, 1)
				enc.reroll()
			Fixtures.pick_free(enc, 3)
			if not enc.summon():
				_fail("scripted summon refused")
				return ""
		RunFlow.finish_encounter(db, run, enc)
		if run.phase == RunState.Phase.SHOP:
			run.shop.buy(db, run, 0)
			run.shop.buy_coffer(db, run, 0)
			if not run.shop.open_coffer.is_empty():
				run.shop.skip_coffer()
			RunFlow.leave_shop(run)
	return JSON.stringify(run.to_dict(), "", true).sha256_text()
