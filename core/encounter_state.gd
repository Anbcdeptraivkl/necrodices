class_name EncounterState
extends RefCounted
## One encounter (GAME_SPEC §4.2–§4.4): the summon-turn state machine, its legality table
## (`can`), the player commands, the projected damage and the combat result.
## Pattern: flat FSM + legality table; previews run the same Scorer on a shadow copy of the
## commit, so the projection equals the combat result for the same army.
## Views call commands and read state; every command emits `changed`.

signal changed
signal rolled(indices: PackedInt32Array)

enum Phase { AWAIT_INPUT, DONE }
enum Verb { SELECT, REROLL, BIND, UNBIND, SUMMON, ATTACK, USE_CONSUMABLE }

var db: ContentDb
var run: RunState
var entry: Dictionary
var rules: PackedStringArray = []
var hp := 0.0
var phase: Phase = Phase.AWAIT_INPUT
var summons_left := 0
var rerolls_left := 0
var turn := 0
var tray_size := 0
var top: PackedInt32Array = []        # top face index per tray die
var selected: PackedByteArray = []    # 1 = selected
var bound: PackedInt32Array = []      # pending group index, -1 = free
var shackled := -1
var pending: Array[Group] = []
var army: Array[Group] = []
var result: ScoreResult
var win := false
var summons_used := 0


func _init(p_db: ContentDb, p_run: RunState) -> void:
	db = p_db
	run = p_run
	entry = run.current_encounter()
	rules = NightGen.active_rules(entry)
	hp = maxf(1.0, roundf(float(entry["hp"]) * run.debug_hp_mult))
	var e := db.economy
	var summons := int(e["base_summons"]) + run.equipment_bonus("summons", db)
	if rules.has("INQUISITOR"):
		summons -= 1
	summons_left = maxi(int(e["min_summons"]), summons)
	rerolls_left = int(e["base_rerolls"]) + run.equipment_bonus("rerolls", db)


## Starts turn 1. Separate from _init so the run can be saved before the first roll (§12.1).
func begin() -> void:
	for r in run.relics:
		r.disabled = false
	if rules.has("WITCH_HUNTER") and not run.relics.is_empty():
		run.relics[0].disabled = true
	_turn_start()


func can(verb: Verb, arg: int = -1) -> bool:
	if phase != Phase.AWAIT_INPUT:
		return false
	match verb:
		Verb.SELECT:
			return arg >= 0 and arg < tray_size and bound[arg] == -1 and arg != shackled
		Verb.REROLL:
			return rerolls_left > 0 and selected_count() >= 1
		Verb.BIND:
			var n := selected_count()
			return n >= 2 and n <= 3 and not bind_preview().is_empty()
		Verb.UNBIND:
			return arg >= 0 and arg < pending.size()
		Verb.SUMMON, Verb.USE_CONSUMABLE:
			return true
		Verb.ATTACK:
			return army.size() + pending.size() >= 1
	return false


func face_at(i: int) -> Face:
	return run.dice[i].faces[top[i]]


func selected_count() -> int:
	return selected.count(1)


func selected_indices() -> PackedInt32Array:
	var out: PackedInt32Array = []
	for i in tray_size:
		if selected[i] == 1:
			out.append(i)
	return out


## What BIND would make from the current selection: {unit, elements} or {}.
func bind_preview() -> Dictionary:
	var faces: Array[Face] = []
	for i in selected_indices():
		faces.append(face_at(i))
	return Recipes.resolve(db, faces, run.levels)


func toggle_select(i: int) -> bool:
	if not can(Verb.SELECT, i):
		return false
	selected[i] = 1 - selected[i]
	changed.emit()
	return true


func reroll() -> bool:
	if not can(Verb.REROLL):
		return false
	var idx := selected_indices()
	for i in idx:
		top[i] = run.rng.roll_face()
	rerolls_left -= 1
	_clear_selection()
	_shackle()
	rolled.emit(idx)
	changed.emit()
	return true


func bind() -> bool:
	if not can(Verb.BIND):
		return false
	var idx := selected_indices()
	pending.append(_make_group(idx))
	for i in idx:
		bound[i] = pending.size() - 1
	_clear_selection()
	changed.emit()
	return true


func unbind(k: int) -> bool:
	if not can(Verb.UNBIND, k):
		return false
	pending.remove_at(k)
	_reindex_bound()
	changed.emit()
	return true


## SUMMON (§4.3): commits the pending groups (possibly none — the UI confirms that).
func summon() -> bool:
	if not can(Verb.SUMMON):
		return false
	_commit()
	if summons_left == 0:
		_combat()
	else:
		_turn_start()
	changed.emit()
	return true


## ATTACK NOW: commit as a normal summon, then fight with the summons that remain unused.
func attack_now() -> bool:
	if not can(Verb.ATTACK):
		return false
	_commit()
	_combat()
	changed.emit()
	return true


## Uses a held consumable mid-turn (§4.8); faces already showing update, pending groups whose
## faces changed are re-resolved (or unbound when no longer valid).
func use_consumable(index: int, targets: Array[Vector2i]) -> bool:
	if not can(Verb.USE_CONSUMABLE):
		return false
	if not ConsumableFx.use_held(db, run, index, targets):
		return false
	_refresh_pending()
	changed.emit()
	return true


## Essence per element over army + pending (what the scorer will count).
func preview_essence() -> Dictionary:
	var all: Array[Group] = []
	all.append_array(army)
	all.append_array(pending)
	return ScoreCtx.build(all, 0, 0, 0, 0).essence


## Damage if the pending groups were summoned now and combat followed (§4.3 projected damage).
func projected() -> ScoreResult:
	var shadow_relics: Array[RelicInstance] = []
	for r in run.relics:
		shadow_relics.append(r.copy())
	var shadow_army: Array[Group] = []
	for g in army:
		shadow_army.append(g)
	var money_gain := 0
	for g in pending:
		var c := g.copy()
		c.summon_index = shadow_army.size()
		shadow_army.append(c)
		money_gain += _commit_effects(c, shadow_relics)
	var ctx := ScoreCtx.build(shadow_army, run.money + money_gain, rerolls_left, maxi(0, summons_left - 1),
		run.bosses_defeated)
	return Scorer.score(db, shadow_army, shadow_relics, run.levels, ctx, rules)


func _turn_start() -> void:
	turn += 1
	tray_size = run.dice.size()
	top.resize(tray_size)
	selected.resize(tray_size)
	bound.resize(tray_size)
	pending.clear()
	var all: PackedInt32Array = []
	for i in tray_size:
		top[i] = run.rng.roll_face()
		bound[i] = -1
		all.append(i)
	_clear_selection()
	shackled = -1
	_shackle()
	rolled.emit(all)


## Bell Ringer (§4.3): after every roll / reroll one random free die is shackled for the turn.
func _shackle() -> void:
	if not rules.has("BELL_RINGER"):
		return
	shackled = -1
	var free: Array = []
	for i in tray_size:
		if bound[i] == -1:
			free.append(i)
	if free.is_empty():
		return
	shackled = run.rng.pick("BOSS", free)
	selected[shackled] = 0


func _clear_selection() -> void:
	for i in tray_size:
		selected[i] = 0


func _make_group(idx: PackedInt32Array) -> Group:
	var faces: Array[Face] = []
	for i in idx:
		faces.append(face_at(i).copy())
	var res := Recipes.resolve(db, faces, run.levels)
	var g := Group.new()
	g.unit_id = res["unit"]
	g.faces = faces
	g.elements = res["elements"]
	g.die_indices = idx
	return g


func _reindex_bound() -> void:
	for i in tray_size:
		bound[i] = -1
	for k in pending.size():
		for i in pending[k].die_indices:
			bound[i] = k


func _refresh_pending() -> void:
	var keep: Array[Group] = []
	for g in pending:
		var faces: Array[Face] = []
		for i in g.die_indices:
			faces.append(face_at(i))
		if Recipes.can_bind(db, faces, run.levels):
			keep.append(_make_group(g.die_indices))
	pending = keep
	_reindex_bound()


## Commit-time effects of one group (§4.3 COMMIT): SUMMON relic counters and GOLD faces.
## Mutates `relics` (the run's or a shadow copy); returns the money it pays.
func _commit_effects(g: Group, relics: Array[RelicInstance]) -> int:
	var money := 0
	for f in g.faces:
		if f.modifier == "GOLD":
			money += int(db.economy["modifiers"]["GOLD"]["value"])
	var one: Array[Group] = [g]
	var ctx := ScoreCtx.build(one, run.money, rerolls_left, summons_left, run.bosses_defeated)
	for r in relics:
		if r.disabled:
			continue
		var row: Dictionary = db.relics[r.id]
		if row.has("counter") and RelicEval.cond(row["counter"]["cond"], g, 0, ctx, db):
			r.counter += int(row["counter"]["inc"])
		for block: Dictionary in RulesRegistry.relic_blocks(row):
			if block["trigger"] != "SUMMON" or not RelicEval.cond(block["cond"], g, 0, ctx, db):
				continue
			for effect: Dictionary in block["effects"]:
				if effect["op"] == "add_money":
					money += int(RelicEval.value(effect["value"], r.counter, ctx))
	return money


func _commit() -> void:
	for g in pending:
		g.summon_index = army.size()
		army.append(g)
		run.money += _commit_effects(g, run.relics)
		run.record_summon(g.unit_id)
	pending.clear()
	summons_left -= 1
	summons_used += 1
	_reindex_bound()


func _combat() -> void:
	var ctx := ScoreCtx.build(army, run.money, rerolls_left, summons_left, run.bosses_defeated)
	result = Scorer.score(db, army, run.relics, run.levels, ctx, rules)
	win = result.damage >= hp
	run.stats["best_damage"] = maxf(float(run.stats["best_damage"]), result.damage)
	phase = Phase.DONE
