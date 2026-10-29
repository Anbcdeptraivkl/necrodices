class_name Scorer
extends RefCounted
## The one scorer (GAME_SPEC §5). Previews, the battle, bots and tests all call it.
## Squad order (D-09): combo base → each scored die in pick order (points, rune) → IRON runes on
## held dice → each trinket left to right takes its turn: its DIE blocks over the scored dice in
## pick order, then its SQUAD blocks → strength = floor(P × C). Trinket-major, like Balatro's
## jokers after the cards, so the playback can show one trinket at a time.
## Resolve: army = Σ strength → RESOLVE trinkets left to right → damage.
## Pure: no RNG (luck arrives on the squad), no side effects; commit-time effects (counters,
## money, glass breaks) live in EncounterState, so a preview can never change the run.


static func score_squad(db: ContentDb, squad: Squad, relics: Array[RelicInstance], levels: Dictionary,
		ctx: ScoreCtx, rules: PackedStringArray) -> ScoreResult:
	ctx.squad = squad
	var result := ScoreResult.new()
	var trace := result.trace
	var level: int = levels.get(squad.combo, 1)
	var base := db.combo_stats(squad.combo, level)
	ctx.p = base.x
	ctx.c = base.y
	trace.append(TraceStep.make(TraceStep.Kind.COMBO, -1, squad.combo, "none", base.x, ctx.p, ctx.c,
		db.text("lbl_combo_step") % [db.combos[squad.combo]["name"], level, RelicEval.fmt(base.x), RelicEval.fmt(base.y)]))
	for k in squad.scored:
		_score_die(db, squad, k, relics, ctx, rules, trace)
	var iron: Dictionary = db.economy["runes"]["IRON"]
	for h in squad.held.size():
		if squad.held_faces[h].rune == "IRON":
			var op := RelicEval.apply(iron["op"], float(iron["value"]), ctx)
			trace.append(TraceStep.make(TraceStep.Kind.HELD, squad.held[h], "IRON", op, float(iron["value"]),
				ctx.p, ctx.c, RelicEval.label(db, iron["op"], float(iron["value"]))))
	for r in relics:
		if r.disabled:
			continue
		for k in squad.scored:
			_fire_relic(db, "DIE", r, ctx, k, trace)
		_fire_relic(db, "SQUAD", r, ctx, -1, trace)
	result.power = ctx.p
	result.count = ctx.c
	result.strength = floorf(ctx.p * ctx.c)
	trace.append(TraceStep.make(TraceStep.Kind.STRENGTH, -1, "STRENGTH", "none", result.strength, ctx.p, ctx.c,
		db.text("lbl_total") % [RelicEval.fmt(ctx.p), RelicEval.fmt(ctx.c), RelicEval.fmt(result.strength)]))
	return result


static func _score_die(db: ContentDb, squad: Squad, k: int, relics: Array[RelicInstance], ctx: ScoreCtx,
		rules: PackedStringArray, trace: Array[TraceStep]) -> void:
	var f := squad.faces[k]
	var tray := squad.dice[k]
	if not f.is_tomb():
		var pts := float(f.points)
		if rules.has("EXORCIST") and f.element == "BONE":
			pts = 0.0
			trace.append(TraceStep.make(TraceStep.Kind.BOSS, tray, "EXORCIST", "none", 0.0, ctx.p, ctx.c,
				db.text("lbl_exorcist_step")))
		ctx.p += pts
		trace.append(TraceStep.make(TraceStep.Kind.DIE, tray, squad.elements[k], "add_p", pts, ctx.p, ctx.c,
			db.text("op_add_power") % RelicEval.fmt(pts)))
	if f.rune != "":
		var row: Dictionary = db.economy["runes"][f.rune]
		var fires: bool = row["when"] == "SCORED"
		if f.rune == "LUCKY":
			fires = squad.luck.get(k, {}).get("count", false)
		if fires:
			var v := float(row["value"])
			var op := RelicEval.apply(row["op"], v, ctx)
			trace.append(TraceStep.make(TraceStep.Kind.RUNE, tray, f.rune, op, v, ctx.p, ctx.c,
				RelicEval.label(db, row["op"], v)))


## The trinket's blocks of `trigger` whose condition holds (`k` = scored position, -1 = squad).
static func _fire_relic(db: ContentDb, trigger: String, r: RelicInstance, ctx: ScoreCtx, k: int,
		trace: Array[TraceStep]) -> void:
	var tray := ctx.squad.dice[k] if k >= 0 else -1
	for block: Dictionary in RulesRegistry.relic_blocks(db.relics[r.id]):
		if block["trigger"] != trigger or not RelicEval.cond(block["cond"], ctx, k):
			continue
		for effect: Dictionary in block["effects"]:
			var v := RelicEval.value(effect["value"], r.counter, ctx)
			var op := RelicEval.apply(effect["op"], v, ctx)
			trace.append(TraceStep.make(TraceStep.Kind.TRINKET, tray, r.id, op, v, ctx.p, ctx.c,
				RelicEval.label(db, effect["op"], v)))


## Army damage (§5.2). `strengths` in summon order; ctx.squad stays null.
static func resolve(db: ContentDb, strengths: Array[float], relics: Array[RelicInstance], ctx: ScoreCtx) -> ResolveResult:
	ctx.squad = null
	var out := ResolveResult.new()
	for s in strengths:
		out.army += s
	var dmg := out.army
	for r in relics:
		if r.disabled:
			continue
		for block: Dictionary in RulesRegistry.relic_blocks(db.relics[r.id]):
			if block["trigger"] != "RESOLVE" or not RelicEval.cond(block["cond"], ctx, -1, strengths.size()):
				continue
			for effect: Dictionary in block["effects"]:
				var v := RelicEval.value(effect["value"], r.counter, ctx)
				var op := "mul_d"
				if effect["op"] == "mul_damage":
					dmg = RelicEval.round_half_up(dmg * v)
				else:
					dmg += v
					op = "add_d"
				out.trace.append(TraceStep.make(TraceStep.Kind.RESOLVE, -1, r.id, op, v, dmg, 0.0,
					RelicEval.label(db, effect["op"], v)))
	out.damage = dmg
	for s in strengths:
		out.shares.append(s * dmg / out.army if out.army > 0.0 else 0.0)
	out.trace.append(TraceStep.make(TraceStep.Kind.TOTAL, -1, "TOTAL", "none", dmg, dmg, 0.0,
		db.text("lbl_army_total") % RelicEval.fmt(dmg)))
	return out
