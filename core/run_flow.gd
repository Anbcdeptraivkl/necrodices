class_name RunFlow
extends RefCounted
## Run-phase transitions (GAME_SPEC §3, §4.5, §7): the only code that changes RunState.phase.
## Pattern: flat FSM over RunState.Phase — NIGHT_MAP → ENCOUNTER → (win) SHOP → NIGHT_MAP …,
## (lose) GAME_OVER, (Night 8 boss) VICTORY. Screens call these and route on the result.


static func new_run(db: ContentDb, run_seed: String) -> RunState:
	var run := RunState.new()
	run.seed = run_seed
	run.rng = RngStreams.create(run_seed)
	run.money = int(db.economy["start_money"])
	for i in int(db.economy["start_dice"]):
		run.dice.append(Die.standard())
	run.night = 1
	NightGen.generate(db, run)
	run.phase = RunState.Phase.NIGHT_MAP
	return run


## NIGHT_MAP → ENCOUNTER. The caller saves the run, then calls `begin()` on the result.
static func start_encounter(db: ContentDb, run: RunState) -> EncounterState:
	assert(run.phase in [RunState.Phase.NIGHT_MAP, RunState.Phase.ENCOUNTER], "start_encounter from %s" % run.phase)
	run.phase = RunState.Phase.ENCOUNTER
	run.shop = null
	return EncounterState.new(db, run)


## After combat: applies the outcome and moves the run on. Returns the cash-out lines
## (empty on a loss). Win → SHOP (or VICTORY after the Night 8 boss); lose → GAME_OVER.
static func finish_encounter(db: ContentDb, run: RunState, enc: EncounterState) -> Array[Dictionary]:
	assert(enc.phase == EncounterState.Phase.DONE, "encounter not resolved")
	for r in run.relics:
		r.disabled = false
	var lines: Array[Dictionary] = []
	if not enc.win:
		run.phase = RunState.Phase.GAME_OVER
		return lines
	var role: String = enc.entry["role"]
	lines = Economy.cash_out_lines(db, run, role, enc.summons_left)
	run.money += Economy.total(lines)
	run.stats["wins"] = int(run.stats["wins"]) + 1
	if role == "BOSS":
		run.bosses_defeated += 1
		if run.night >= int(db.curve["nights"]):
			run.phase = RunState.Phase.VICTORY
			return lines
		run.night += 1
		NightGen.generate(db, run)
	else:
		run.encounter_index += 1
	run.shop = ShopState.open(db, run)
	run.phase = RunState.Phase.SHOP
	return lines


## SHOP → NIGHT_MAP (Continue / NEXT FIGHT).
static func leave_shop(run: RunState) -> void:
	assert(run.phase == RunState.Phase.SHOP, "leave_shop from %s" % run.phase)
	run.shop = null
	run.phase = RunState.Phase.NIGHT_MAP


## Relic order is the trigger order (§8): one command moves a relic.
static func reorder_relic(run: RunState, from: int, to: int) -> bool:
	if from < 0 or from >= run.relics.size() or to < 0 or to >= run.relics.size() or from == to:
		return false
	var r := run.relics[from]
	run.relics.remove_at(from)
	run.relics.insert(to, r)
	return true
