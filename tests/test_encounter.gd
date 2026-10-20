extends TestSuite
## Encounter state machine (GAME_SPEC §4.2–§4.4, §14): guards, binding, boss rules, commit
## effects, Attack Now, projected == final.

const COVERS: Array[String] = ["core/encounter_state.gd", "core/run_flow.gd", "core/night_gen.gd"]


func _enc(rules: Array = [], hp: float = 1000.0) -> EncounterState:
	var run := Fixtures.run_with_rules(rules, hp)
	var enc := RunFlow.start_encounter(Fixtures.db(), run)
	enc.begin()
	return enc


func test_setup_counts() -> void:
	var enc := _enc()
	_eq(enc.summons_left, 3, "3 summons")
	_eq(enc.rerolls_left, 2, "2 rerolls")
	_eq(enc.tray_size, 4, "4 dice rolled")
	_eq(_enc(["INQUISITOR"]).summons_left, 2, "Inquisitor −1 summon")


func test_reroll_guards() -> void:
	var enc := _enc()
	_check(not enc.reroll(), "no reroll without selection")
	enc.toggle_select(0)
	_check(enc.reroll(), "reroll one die")
	enc.toggle_select(1)
	_check(enc.reroll(), "second reroll")
	enc.toggle_select(1)
	_check(not enc.can(EncounterState.Verb.REROLL), "no rerolls left")
	_eq(enc.rerolls_left, 0, "rerolls spent")


func test_bind_and_unbind() -> void:
	var enc := _enc()
	Fixtures.set_tray(enc, ["BONE", "FIRE", "ICE", "LEAF"])
	enc.toggle_select(0)
	enc.toggle_select(1)
	_check(enc.bind(), "BONE+FIRE binds")
	_eq(enc.pending[0].unit_id, "FLAME_SKULL", "flame skull pending")
	_check(not enc.can(EncounterState.Verb.SELECT, 0), "bound die cannot be selected")
	enc.toggle_select(2)
	enc.toggle_select(3)
	_check(enc.bind(), "ICE+LEAF binds")
	_check(enc.unbind(0), "unbind first group")
	_eq(enc.pending.size(), 1, "one group left")
	_eq(enc.bound[2], 0, "second group re-indexed")
	_eq(enc.bound[0], -1, "dice of the removed group are free")


func test_invalid_triple_cannot_bind() -> void:
	var enc := _enc()
	Fixtures.set_tray(enc, ["FIRE", "FIRE", "FIRE", "ICE"])
	for i in 3:
		enc.toggle_select(i)
	_check(not enc.can(EncounterState.Verb.BIND), "FIRE×3 has no recipe")
	enc.toggle_select(2)
	_check(enc.can(EncounterState.Verb.BIND), "a pair always binds")


func test_bell_ringer_shackles_one_die() -> void:
	var enc := _enc(["BELL_RINGER"])
	_check(enc.shackled >= 0 and enc.shackled < enc.tray_size, "a die is shackled")
	_check(not enc.toggle_select(enc.shackled), "shackled die cannot be selected")
	var free := 0 if enc.shackled != 0 else 1
	enc.toggle_select(free)
	enc.reroll()
	_check(enc.shackled >= 0, "re-shackled after reroll")


func test_witch_hunter_disables_leftmost() -> void:
	var run := Fixtures.run_with_rules(["WITCH_HUNTER"])
	run.relics.append(RelicInstance.new("RATTLE_DRUM"))
	run.relics.append(RelicInstance.new("GRAVEDIGGER_LAMP"))
	var enc := RunFlow.start_encounter(Fixtures.db(), run)
	enc.begin()
	_check(run.relics[0].disabled and not run.relics[1].disabled, "leftmost relic disabled")


func test_summon_cycle_to_combat() -> void:
	var enc := _enc([], 1.0)
	for t in 3:
		Fixtures.set_tray(enc, ["BONE", "BONE", "ICE", "ICE"])
		enc.toggle_select(0)
		enc.toggle_select(1)
		enc.bind()
		_check(enc.summon(), "summon turn %d" % t)
	_eq(enc.phase, EncounterState.Phase.DONE, "combat after the last summon")
	_eq(enc.army.size(), 3, "three skeleton groups")
	_check(enc.win, "beats 1 HP")


func test_attack_now_counts_unused_summons() -> void:
	var enc := _enc([], 1.0)
	_check(not enc.can(EncounterState.Verb.ATTACK), "no attack with an empty army")
	Fixtures.set_tray(enc, ["BONE", "BONE", "ICE", "ICE"])
	enc.toggle_select(0)
	enc.toggle_select(1)
	enc.bind()
	_check(enc.attack_now(), "attack now")
	_eq(enc.summons_left, 2, "one summon used, two unused")
	var lines := RunFlow.finish_encounter(Fixtures.db(), enc.run, enc)
	var unused: Array = lines.filter(func(l: Dictionary) -> bool: return l["key"] == "cashout_unused_summons")
	_eq(unused[0]["amount"], 2, "$1 per unused summon")


func test_projected_equals_final() -> void:
	for s in 30:
		var run := Fixtures.run("PROJ%03d" % s)
		run.relics.append(RelicInstance.new("OVERGROWTH"))
		run.relics.append(RelicInstance.new("PIGGY_COFFIN"))
		run.relics.append(RelicInstance.new("THRIFTY_GHOST"))
		run.dice[0].faces[3].modifier = "GOLD"
		run.dice[1].faces[0].modifier = "HEX"
		var enc := RunFlow.start_encounter(Fixtures.db(), run)
		enc.begin()
		var projected := -1.0
		while enc.phase == EncounterState.Phase.AWAIT_INPUT:
			_bind_greedy(enc)
			if enc.summons_left == 1 or s % 3 == 0:
				projected = enc.projected().damage
				if enc.summons_left > 1:
					enc.attack_now() if enc.can(EncounterState.Verb.ATTACK) else enc.summon()
				else:
					enc.summon()
			else:
				enc.summon()
		if projected >= 0.0:
			_eq(enc.result.damage, projected, "seed %d projected == final" % s)


func test_gold_and_counter_commit_effects() -> void:
	var run := Fixtures.run_with_rules([])
	run.relics.append(RelicInstance.new("OVERGROWTH"))
	run.dice[0].faces[3].modifier = "GOLD"   # LEAF face with GOLD
	var enc := RunFlow.start_encounter(Fixtures.db(), run)
	enc.begin()
	Fixtures.set_tray(enc, ["LEAF", "LEAF", "ICE", "ICE"])
	var money := run.money
	var before := enc.projected().damage
	enc.toggle_select(0)
	enc.toggle_select(1)
	enc.bind()
	enc.projected()
	_eq(run.relics[0].counter, 0, "preview never increments counters")
	enc.summon()
	_eq(run.relics[0].counter, 1, "LEAF group increments Overgrowth")
	_eq(run.money, money + 2, "GOLD face pays $2 at commit")
	_check(before >= 0.0, "empty preview scores")


func _bind_greedy(enc: EncounterState) -> void:
	for i in enc.tray_size:
		for j in range(i + 1, enc.tray_size):
			if enc.bound[i] != -1 or enc.bound[j] != -1 or i == enc.shackled or j == enc.shackled:
				continue
			enc.toggle_select(i)
			enc.toggle_select(j)
			if not enc.bind():
				enc.toggle_select(i)
				enc.toggle_select(j)
