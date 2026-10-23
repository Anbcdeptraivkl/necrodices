extends TestSuite
## Battle state machine (GAME_SPEC §4.2–§4.6): guards, roll / pick / reroll / summon, auto
## resolve, boss rules, commit effects (luck, glass, counters, money), preview == summon.

const COVERS: Array[String] = ["core/encounter_state.gd", "core/run_flow.gd", "core/night_gen.gd",
	"core/combos.gd", "core/scorer.gd"]


func test_setup_counts() -> void:
	var enc := Fixtures.battle()
	_eq(enc.summons_left, 3, "3 summons")
	_eq(enc.rerolls_left, 2, "2 rerolls")
	_eq(enc.tray_size, 5, "5 dice")
	_eq(enc.phase, EncounterState.Phase.AWAIT_ROLL, "dice start in the cup")
	_eq(Fixtures.battle(["INQUISITOR"]).summons_left, 2, "Inquisitor −1 summon")


func test_roll_pick_guards() -> void:
	var enc := Fixtures.battle()
	_check(not enc.toggle_select(0), "no pick before the roll")
	_check(enc.roll(), "roll")
	_check(not enc.roll(), "no second roll in PICK")
	for i in 5:
		_check(enc.toggle_select(i), "pick %d" % i)
	_eq(Array(enc.picked), [0, 1, 2, 3, 4], "pick order kept")
	_check(enc.toggle_select(2), "unpick")
	_eq(Array(enc.picked), [0, 1, 3, 4], "die 2 left the pick")
	Fixtures.pick(enc, [0, 1])
	_check(not enc.can(EncounterState.Verb.SUMMON), "2 dice cannot summon")
	Fixtures.pick(enc, [0, 1, 2])
	_check(enc.can(EncounterState.Verb.SUMMON), "3 dice can summon")


func test_reroll() -> void:
	var enc := Fixtures.battle()
	enc.roll()
	_check(not enc.reroll(), "no reroll without a pick")
	Fixtures.pick(enc, [0])
	_check(enc.reroll(), "reroll one die")
	_check(enc.picked.is_empty(), "pick cleared")
	Fixtures.pick(enc, [1, 2])
	_check(enc.reroll(), "second reroll")
	Fixtures.pick(enc, [1])
	_check(not enc.can(EncounterState.Verb.REROLL), "no rerolls left")


func test_summon_cycle_and_loss() -> void:
	var enc := Fixtures.battle()
	for n in 3:
		enc.roll()
		Fixtures.pick(enc, [0, 1, 2])
		_check(enc.summon(), "summon %d" % n)
	_eq(enc.squads.size(), 3, "three squads")
	_eq(enc.phase, EncounterState.Phase.DONE, "out of summons resolves")
	_check(not enc.win, "a huge HP is not beaten")
	_eq(enc.resolution.army, enc.squads[0].strength() + enc.squads[1].strength() + enc.squads[2].strength(),
		"army = sum of squads")


func test_auto_resolve_when_hp_reached() -> void:
	var enc := Fixtures.battle([], 1.0)
	enc.roll()
	Fixtures.pick(enc, [0, 1, 2])
	enc.summon()
	_eq(enc.phase, EncounterState.Phase.DONE, "resolved after the first squad")
	_check(enc.win, "won")
	_eq(enc.summons_left, 2, "two summons left unused")
	var enc2 := Fixtures.battle([], 1.0e9)
	enc2.roll()
	Fixtures.pick(enc2, [0, 1, 2])
	enc2.summon()
	_eq(enc2.phase, EncounterState.Phase.AWAIT_ROLL, "back to the cup")
	_check(not enc2.can(EncounterState.Verb.SELECT, 0), "no pick before the next roll")


func test_preview_equals_summon() -> void:
	for s in 30:
		var run := Fixtures.run("PREV%02d" % s)
		run.relics.append(RelicInstance.new("OVERGROWTH"))
		run.relics.append(RelicInstance.new("GRAND_PROCESSION"))
		run.night_plan[0]["hp"] = 1.0e9
		var enc := RunFlow.start_encounter(Fixtures.db(), run)
		enc.begin()
		for n in 2:
			enc.roll()
			Fixtures.pick(enc, [0, 2, 4])
			var p := enc.preview()
			var projected := enc.projected().damage
			var counter := run.relics[0].counter
			enc.summon()
			_eq(enc.squads[-1].strength(), p.result.strength, "seed %d summon %d: preview = result" % [s, n])
			_eq(enc.army_resolution().damage, projected, "projected = army after the summon")
			_check(run.relics[0].counter >= counter, "counter only moves on summon")


func test_bell_ringer_shackles() -> void:
	var enc := Fixtures.battle(["BELL_RINGER"])
	enc.roll()
	_check(enc.shackled >= 0, "a die is shackled after the roll")
	_check(not enc.toggle_select(enc.shackled), "shackled die cannot be picked")


func test_witch_hunter_disables_leftmost() -> void:
	var enc := Fixtures.battle(["WITCH_HUNTER"], 1.0e9, ["GRAVEDIGGER_LAMP", "TRIO_TOTEM"])
	_check(enc.run.relics[0].disabled, "leftmost disabled")
	_check(not enc.run.relics[1].disabled, "others work")
	Fixtures.set_tray(enc, ["FIRE1", "FIRE1", "FIRE1"])
	Fixtures.pick(enc, [0, 1, 2])
	_eq(enc.preview().result.count, 11.0, "only Trio Totem: 3 + 8")


func test_glass_breaks_and_lucky_pays_sometimes() -> void:
	var broke := 0
	var paid := 0
	for s in 60:
		var enc := Fixtures.battle()
		enc.run.rng = RngStreams.create("LUCK%02d" % s)
		Fixtures.set_tray(enc, ["FIRE1+GLASS", "FIRE1+LUCKY", "FIRE1"])
		Fixtures.pick(enc, [0, 1, 2])
		var money := enc.run.money
		enc.summon()
		var sq := enc.squads[0]
		if not sq.broken.is_empty():
			broke += 1
			_eq(enc.run.dice[0].faces[enc.top[0]].rune, "", "the shattered rune is gone")
		if sq.money > 0:
			paid += 1
			_eq(enc.run.money, money + 20, "lucky money")
	_check(broke > 5 and broke < 30, "glass breaks about 1 in 4 (%d / 60)" % broke)
	_check(paid >= 1 and paid < 15, "lucky money about 1 in 15 (%d / 60)" % paid)


func test_loaded_bone_and_gilded() -> void:
	for s in 20:
		var enc := Fixtures.battle([], 1.0, ["LOADED_BONE"])
		enc.run.rng = RngStreams.create("BONE%02d" % s)
		enc.roll()
		var bones := 0
		for i in enc.tray_size:
			if enc.face_at(i).element == "BONE":
				bones += 1
		_check(bones >= 1, "seed %d: a BONE face is showing" % s)
	var enc := Fixtures.battle([], 1.0)
	Fixtures.set_tray(enc, ["FIRE1", "FIRE1", "FIRE1", "ICE2+GILDED", "LEAF3+GILDED"])
	Fixtures.pick(enc, [0, 1, 2])
	enc.summon()
	_eq(enc.gilded, 2, "two gilded faces held at the end")


func test_overgrowth_counts_the_current_squad() -> void:
	var enc := Fixtures.battle([], 1.0e9, ["OVERGROWTH"])
	Fixtures.set_tray(enc, ["LEAF1", "LEAF1", "LEAF1"])
	Fixtures.pick(enc, [0, 1, 2])
	_eq(enc.preview().result.count, 4.0, "preview: 3 + 1")
	_eq(enc.run.relics[0].counter, 0, "preview leaves the counter")
	enc.summon()
	_eq(enc.run.relics[0].counter, 1, "summon moves it")
	_eq(enc.squads[0].result.count, 4.0, "summoned squad counted itself")
