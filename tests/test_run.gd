extends TestSuite
## Run loop, economy, shop, consumables, save and determinism (GAME_SPEC §4.5–§4.8, §7, §12, §14).

const COVERS: Array[String] = ["core/run_state.gd", "core/run_flow.gd", "core/economy.gd",
	"core/shop_state.gd", "core/consumable_fx.gd", "core/save_store.gd", "core/rng_streams.gd",
	"core/night_gen.gd", "core/number_format.gd", "data/economy.json", "data/curve.json"]

const SAVE_DIR := "user://sav_test"


func test_new_run_setup() -> void:
	var run := Fixtures.run()
	_eq(run.money, 4, "start money")
	_eq(run.dice.size(), 4, "start dice")
	_eq(run.night_plan.size(), 3, "three encounters")
	var db := Fixtures.db()
	var base: float = db.curve["night_base"][0]
	_eq(run.night_plan[0]["hp"], roundf(base * db.curve["role_mult"]["MOB"]), "night 1 mob HP")
	_eq(run.night_plan[1]["hp"], roundf(base * db.curve["role_mult"]["CHAMPION"]), "night 1 champion HP")
	var rule: String = run.night_plan[2]["rules"][0]
	_check(rule in ["EXORCIST", "BELL_RINGER"], "night 1 boss pool")


func test_hp_curve_and_inquisitor() -> void:
	# The numbers are tunable (data); the rule is: base × role mult, bosses × product of rule mults.
	var db := Fixtures.db()
	var nb: Array = db.curve["night_base"]
	var m := func(r: String) -> float: return float(db.boss_rules[r]["hp_mult"])
	_eq(Economy.hp_for(db, 8, "BOSS", ["ENRAGED", "EXORCIST", "INQUISITOR"]),
		roundf(float(nb[7]) * m.call("ENRAGED") * m.call("EXORCIST") * m.call("INQUISITOR")), "enraged = product")
	_eq(Economy.hp_for(db, 3, "BOSS", ["INQUISITOR"]), roundf(float(nb[2]) * m.call("INQUISITOR")), "inquisitor")
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
			_check(rules[1] != rules[2], "two distinct rules")
		else:
			_check(rules[0] != last, "night %d boss differs from the previous" % night)
			last = rules[0]


func test_cash_out_lines() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run()
	run.money = 12
	run.relics.append(RelicInstance.new("GRAVE_ROBBER"))
	var lines := Economy.cash_out_lines(db, run, "CHAMPION", 1)
	var by_key := {}
	for l in lines:
		by_key[l["key"]] = l["amount"]
	_eq(by_key, {"cashout_enemy_reward": 4, "cashout_unused_summons": 1, "cashout_interest": 2,
		"cashout_relics": 2}, "reward, unused, interest on $12, Grave Robber")
	run.money = 40
	_eq(Economy.interest(db, run.money), 5, "interest cap")


func test_shop_rules() -> void:
	var db := Fixtures.db()
	for s in 40:
		var run := Fixtures.run("SHOP%03d" % s)
		run.relics.append(RelicInstance.new("RATTLE_DRUM"))
		var shop := ShopState.open(db, run)
		var ids := {}
		for item in shop.items:
			if item["kind"] == ShopState.KIND_RELIC:
				_check(item["id"] != "RATTLE_DRUM", "owned relic not offered")
				_check(not ids.has(item["id"]), "no duplicate relic offers")
				ids[item["id"]] = true
	var run := Fixtures.run()
	run.money = 100
	var shop := ShopState.open(db, run)
	_eq(shop.reroll_cost(db, run), 4, "reroll $4")
	shop.reroll(db, run)
	_eq(shop.reroll_cost(db, run), 5, "then $5")
	_eq(ShopState.open(db, run).reroll_cost(db, run), 4, "resets per visit")
	run.equipment.append("HAGGLER_LANTERN")
	_eq(ShopState.open(db, run).reroll_cost(db, run), 2, "Haggler −$2")


func test_buy_sell_and_slots() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run()
	run.money = 100
	var shop := ShopState.new()
	shop.items = [{"kind": "RELIC", "id": "BONE_PILE", "price": 6, "sold": false},
		{"kind": "CONSUMABLE", "id": "TOME_BONE", "price": 3, "sold": false},
		{"kind": "CONSUMABLE", "id": "SIGIL_FIRE", "price": 3, "sold": false}]
	_check(shop.buy(db, run, 0), "buy relic")
	_check(not shop.buy(db, run, 0), "sold slot")
	_eq(run.money, 94, "paid $6")
	_check(ShopState.sell_relic(db, run, 0), "sell relic")
	_eq(run.money, 97, "sold for floor(6/2)")
	run.consumables = PackedStringArray(["INK_SHARP", "INK_HEX"])
	_check(not shop.can_buy(db, run, 1), "consumable slots full")
	var none: Array[Vector2i] = []
	_check(shop.buy_use(db, run, 1, none), "buy & use needs no slot")
	_eq(run.level_of("SKELETON_WARRIOR"), 2, "tome levelled bone units")
	_eq(run.level_of("WISP"), 2, "and wisp")
	_eq(run.level_of("FIRE_IMP"), 1, "not fire imp")


func test_equipment_prerequisite() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run("EQUIP001")
	for s in 50:
		run.equipment = PackedStringArray()
		run.rng = RngStreams.create("EQ%03d" % s)
		NightGen.generate(db, run)
		_check(run.equipment_offer != "BONE_SATCHEL" and run.equipment_offer != "SECOND_CUP",
			"no equipment without its prerequisite")
	run.money = 10
	run.equipment_offer = "BONE_POUCH"
	run.equipment_sold = false
	_check(ShopState.buy_equipment(db, run), "buy bone pouch")
	_eq(run.dice.size(), 5, "+1 die")


func test_consumable_targets() -> void:
	var db := Fixtures.db()
	var run := Fixtures.run()
	var two: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 2)]
	_check(ConsumableFx.apply(db, run, "SIGIL_FIRE", two), "sigil on 2 faces")
	_eq(run.dice[1].faces[2].element, "FIRE", "face changed")
	var three: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 2), Vector2i(2, 2)]
	_check(not ConsumableFx.apply(db, run, "SIGIL_ICE", three), "sigil max 2")
	var one: Array[Vector2i] = [Vector2i(3, 5)]
	_check(ConsumableFx.apply(db, run, "INK_WILD", one), "ink 1 face")
	_eq(run.dice[3].faces[5].modifier, "WILD", "modifier set")
	var none: Array[Vector2i] = []
	for i in 4:
		ConsumableFx.apply(db, run, "SPARE_DIE", none)
	_eq(run.dice.size(), 8, "max 8 dice")
	_check(not ConsumableFx.can_apply(db, run, "SPARE_DIE", none), "no 9th die")


func test_save_round_trip() -> void:
	var store := SaveStore.new(SAVE_DIR)
	var run := Fixtures.run("SAVE0001")
	run.relics.append(RelicInstance.new("OVERGROWTH", 3))
	run.consumables.append("TOME_ICE")
	run.dice[0].faces[0].modifier = "HEX"
	run.levels["LICH"] = 3
	run.shop = ShopState.open(Fixtures.db(), run)
	run.phase = RunState.Phase.SHOP
	_check(store.save_run(run), "saved")
	var loaded := store.load_run()
	# JSON has one number type: compare both sides narrowed the way the loader narrows.
	_eq(JSON.stringify(JsonUtil.narrow(loaded.to_dict()), "", true),
		JSON.stringify(JsonUtil.narrow(run.to_dict()), "", true), "round trip")
	_eq(loaded.rng.stream("ROLL").randi(), run.rng.stream("ROLL").randi(), "RNG state restored")
	store.delete_run()
	_check(not store.has_run(), "deleted")


func test_determinism_scripted_run() -> void:
	var a := _scripted_run("DETERM01")
	var b := _scripted_run("DETERM01")
	_eq(a, b, "same seed + inputs ⇒ same run")
	_check(a != _scripted_run("DETERM02"), "different seed differs")


func test_number_format() -> void:
	_eq(NumberFormat.format(2520), "2,520", "commas")
	_eq(NumberFormat.format(9999), "9,999", "below 10k")
	_eq(NumberFormat.format(12345), "12.3K", "12.3K")
	_eq(NumberFormat.format(4560000), "4.56M", "4.56M")
	_eq(NumberFormat.format(999600), "1M", "999.6K rounds to 1M")
	_eq(NumberFormat.format(99960), "100K", "99.96K → 100K")
	_eq(NumberFormat.format(1.23e15), "1.23e15", "scientific")
	_eq(NumberFormat.format(12345678, true), "12,345,678", "full setting")


## Plays 9 encounters with a fixed greedy policy (debug HP low) and returns the run hash.
func _scripted_run(seed: String) -> String:
	var db := Fixtures.db()
	var run := RunFlow.new_run(db, seed)
	run.debug_hp_mult = 0.01
	for n in 9:
		if run.phase != RunState.Phase.NIGHT_MAP:
			break
		var enc := RunFlow.start_encounter(db, run)
		enc.begin()
		while enc.phase == EncounterState.Phase.AWAIT_INPUT:
			if enc.rerolls_left > 0 and enc.turn == 1:
				enc.toggle_select(0)
				enc.reroll()
			for i in range(0, enc.tray_size - 1, 2):
				if enc.can(EncounterState.Verb.SELECT, i) and enc.can(EncounterState.Verb.SELECT, i + 1):
					enc.toggle_select(i)
					enc.toggle_select(i + 1)
					if not enc.bind():
						enc.toggle_select(i)
						enc.toggle_select(i + 1)
			enc.summon()
		RunFlow.finish_encounter(db, run, enc)
		if run.phase == RunState.Phase.SHOP:
			run.shop.buy(db, run, 0)
			RunFlow.leave_shop(run)
	return JSON.stringify(run.to_dict(), "", true).sha256_text()
