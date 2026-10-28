class_name EncounterState
extends RefCounted
## One battle (GAME_SPEC §4.2–§4.5): the summon state machine, its legality table (`can`), the
## player commands, the squad preview / projected damage and the resolution.
## Pattern: flat FSM + legality table. Previews run the same Scorer on copies of the trinkets
## (counters applied to copies, no luck), so the preview equals the summon without luck.
## Views call commands and read state; every command emits `changed`.

signal changed
signal rolled(indices: PackedInt32Array)

enum Phase { AWAIT_ROLL, PICK, DONE }
enum Verb { ROLL, SELECT, REROLL, SUMMON, ATTACK, USE_CONSUMABLE }

var db: ContentDb
var run: RunState
var entry: Dictionary
var rules: PackedStringArray = []
var hp := 0.0
var phase: Phase = Phase.AWAIT_ROLL
var summons_left := 0
var rerolls_left := 0
var summons_used := 0
var tray_size := 0
var top: PackedInt32Array = []        # top face index per die, -1 = still in the cup
var picked: PackedInt32Array = []     # tray indices in pick order
var shackled := -1
var squads: Array[Squad] = []
var resolution: ResolveResult
var win := false
var gilded := 0                       # GILDED faces held after the last summon (§4.8)
var started := false
var _seen_units := {}
var _battle_elements := {}


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
	tray_size = run.dice.size()
	top.resize(tray_size)
	top.fill(-1)


## Separate from _init so the run can be saved before anything happens (§13).
func begin() -> void:
	for r in run.relics:
		r.disabled = false
	if rules.has("WITCH_HUNTER") and not run.relics.is_empty():
		run.relics[0].disabled = true
	started = true
	changed.emit()


func can(verb: Verb, arg: int = -1) -> bool:
	if phase == Phase.DONE:
		return false
	match verb:
		Verb.ROLL:
			return phase == Phase.AWAIT_ROLL and summons_left > 0
		Verb.ATTACK:
			return phase == Phase.AWAIT_ROLL and not squads.is_empty()
		Verb.SELECT:
			return phase == Phase.PICK and arg >= 0 and arg < tray_size and arg != shackled \
				and (picked.has(arg) or picked.size() < int(db.economy["pick_max"]))
		Verb.REROLL:
			return phase == Phase.PICK and rerolls_left > 0 and not picked.is_empty()
		Verb.SUMMON:
			return phase == Phase.PICK and picked.size() >= int(db.economy["pick_min"]) \
				and picked.size() <= int(db.economy["pick_max"])
		Verb.USE_CONSUMABLE:
			return true
	return false


## The face showing on die i, or null while the dice are in the cup.
func face_at(i: int) -> Face:
	return run.dice[i].faces[top[i]] if top[i] >= 0 else null


func is_picked(i: int) -> bool:
	return picked.has(i)


func roll() -> bool:
	if not can(Verb.ROLL):
		return false
	var all: PackedInt32Array = []
	for i in tray_size:
		top[i] = run.rng.roll_face()
		all.append(i)
	_roll_trinkets()
	picked.clear()
	_shackle()
	phase = Phase.PICK
	rolled.emit(all)
	changed.emit()
	return true


func toggle_select(i: int) -> bool:
	if not can(Verb.SELECT, i):
		return false
	var at := picked.find(i)
	if at >= 0:
		picked.remove_at(at)
	else:
		picked.append(i)
	changed.emit()
	return true


func reroll() -> bool:
	if not can(Verb.REROLL):
		return false
	var idx := picked.duplicate()
	for i in idx:
		top[i] = run.rng.roll_face()
	rerolls_left -= 1
	picked.clear()
	_shackle()
	rolled.emit(idx)
	changed.emit()
	return true


## SUMMON (§4.5): luck → counters → score → commit → join the army → back to the cup. The
## battle resolves only on ATTACK.
func summon() -> bool:
	if not can(Verb.SUMMON):
		return false
	var squad := make_squad(picked)
	_roll_luck(squad)
	var ctx := _ctx(squad)
	_apply_counters(ctx, run.relics)
	squad.result = Scorer.score_squad(db, squad, run.relics, run.levels, ctx, rules)
	_commit(squad)
	squads.append(squad)
	summons_left -= 1
	summons_used += 1
	_seen_units[squad.unit_id] = true
	for e in squad.scored_elements():
		_battle_elements[e] = true
	picked.clear()
	shackled = -1
	phase = Phase.AWAIT_ROLL
	changed.emit()
	return true


## ATTACK (§4.5): the army charges now; every summon left unused pays at the spoils. Legal
## between summons once a squad exists (and the only move left when the summons run out).
func attack() -> bool:
	if not can(Verb.ATTACK):
		return false
	_finish(army_resolution(), squads[-1])
	changed.emit()
	return true


## Potions / gems mid-battle (§4.5): faces showing update at once; the pick is re-read.
func use_consumable(index: int, targets: Array[Vector2i]) -> bool:
	if not can(Verb.USE_CONSUMABLE):
		return false
	if not ConsumableFx.use_held(db, run, index, targets):
		return false
	changed.emit()
	return true


## The squad the current pick would summon, scored without luck (null when the pick is not
## legal). Counters are applied to trinket copies, so the run never changes.
func preview() -> Squad:
	if not can(Verb.SUMMON):
		return null
	var squad := make_squad(picked)
	var shadow: Array[RelicInstance] = []
	for r in run.relics:
		shadow.append(r.copy())
	var ctx := _ctx(squad)
	_apply_counters(ctx, shadow)
	squad.result = Scorer.score_squad(db, squad, shadow, run.levels, ctx, rules)
	return squad


## Combo the current pick forms (for the pick panel before it is legal): {} when empty.
func pick_combo() -> Dictionary:
	if picked.is_empty():
		return {}
	var faces: Array[Face] = []
	for i in picked:
		faces.append(face_at(i))
	return Combos.detect(db, faces)


## Army damage so far, plus the previewed squad when the pick is legal (§5.4).
func projected() -> ResolveResult:
	var strengths := _strengths()
	var p := preview()
	if p != null:
		strengths.append(p.result.strength)
	return Scorer.resolve(db, strengths, run.relics, _resolve_ctx())


func army_resolution() -> ResolveResult:
	return Scorer.resolve(db, _strengths(), run.relics, _resolve_ctx())


func make_squad(idx: PackedInt32Array) -> Squad:
	var squad := Squad.new()
	squad.dice = idx.duplicate()
	for i in idx:
		squad.faces.append(face_at(i).copy())
	var m := Combos.detect(db, squad.faces)
	squad.combo = m["combo"]
	squad.unit_id = m["unit"]
	squad.unit_elements = m["unit_elements"]
	squad.elements = m["elements"]
	squad.scored = m["scored"]
	for i in tray_size:
		if not idx.has(i) and top[i] >= 0:
			squad.held.append(i)
			squad.held_faces.append(face_at(i).copy())
	return squad


func _strengths() -> Array[float]:
	var out: Array[float] = []
	for s in squads:
		out.append(s.result.strength)
	return out


func _ctx(squad: Squad) -> ScoreCtx:
	var ctx := ScoreCtx.new()
	ctx.money = run.money
	ctx.rerolls_left = rerolls_left
	ctx.summons_left = summons_left - 1
	ctx.squads_before = squads.size()
	ctx.bosses_defeated = run.bosses_defeated
	ctx.seen_units = _seen_units.duplicate()
	ctx.battle_elements = _battle_elements.duplicate()
	ctx.squad = squad
	return ctx


func _resolve_ctx() -> ScoreCtx:
	var ctx := ScoreCtx.new()
	ctx.money = run.money
	ctx.rerolls_left = rerolls_left
	ctx.summons_left = summons_left
	ctx.squads_before = squads.size()
	ctx.bosses_defeated = run.bosses_defeated
	return ctx


## ROLL trinkets (Loaded Bone): after a roll with no `element` showing, one die that has such a
## face (ROLL stream) turns to it.
func _roll_trinkets() -> void:
	for r in run.relics:
		if r.disabled:
			continue
		for block: Dictionary in RulesRegistry.relic_blocks(db.relics[r.id]):
			if block["trigger"] != "ROLL":
				continue
			for effect: Dictionary in block["effects"]:
				if effect["op"] == "ensure_face":
					_ensure_face(effect["element"])


func _ensure_face(element: String) -> void:
	var candidates: Array = []
	for i in tray_size:
		var f := face_at(i)
		if f.element == element and not f.is_tomb():
			return
		if run.dice[i].face_of(element) >= 0:
			candidates.append(i)
	if candidates.is_empty():
		return
	var i: int = run.rng.pick("ROLL", candidates)
	top[i] = run.dice[i].face_of(element)


## Bell Ringer (§6.11): after every roll / reroll one random die is shackled.
func _shackle() -> void:
	shackled = -1
	if rules.has("BELL_RINGER"):
		var all: Array = []
		for i in tray_size:
			all.append(i)
		shackled = run.rng.pick("BOSS", all)


## LUCKY faces roll their luck before scoring (LUCK stream; previews never do).
func _roll_luck(squad: Squad) -> void:
	var row: Dictionary = db.economy["runes"]["LUCKY"]
	for k in squad.scored:
		if squad.faces[k].rune == "LUCKY":
			squad.luck[k] = {"count": run.rng.one_in("LUCK", int(row["one_in"])),
				"money": run.rng.one_in("LUCK", int(row["money_one_in"]))}


## SUMMON counters (Overgrowth) before scoring, so the squad being summoned counts.
func _apply_counters(ctx: ScoreCtx, relics: Array[RelicInstance]) -> void:
	for r in relics:
		if r.disabled:
			continue
		var row: Dictionary = db.relics[r.id]
		if row.has("counter") and RelicEval.cond(row["counter"]["cond"], ctx):
			r.counter += int(row["counter"]["inc"])


## Commit effects (§5.3): SUMMON trinket money, lucky money, glass breaks, stats.
func _commit(squad: Squad) -> void:
	var ctx := _ctx(squad)
	var money := 0
	for r in run.relics:
		if r.disabled:
			continue
		for block: Dictionary in RulesRegistry.relic_blocks(db.relics[r.id]):
			if block["trigger"] != "SUMMON" or not RelicEval.cond(block["cond"], ctx):
				continue
			for effect: Dictionary in block["effects"]:
				money += int(RelicEval.value(effect["value"], r.counter, ctx))
	var runes: Dictionary = db.economy["runes"]
	for k: int in squad.luck:
		if squad.luck[k]["money"]:
			money += int(runes["LUCKY"]["money"])
	for k in squad.scored:
		if squad.faces[k].rune != "GLASS" or not run.rng.one_in("LUCK", int(runes["GLASS"]["break_one_in"])):
			continue
		var tray := squad.dice[k]
		var face := face_at(tray)
		if face.rune == "GLASS":
			face.rune = ""
			squad.broken.append(tray)
	squad.money = money
	run.money += money
	run.record_summon(squad.unit_id, squad.result.strength)


func _finish(res: ResolveResult, last: Squad) -> void:
	resolution = res
	win = res.damage >= hp
	gilded = 0
	for f in last.held_faces:
		if f.rune == "GILDED":
			gilded += 1
	run.stats["best_damage"] = maxf(float(run.stats["best_damage"]), res.damage)
	phase = Phase.DONE
