class_name Scorer
extends RefCounted
## The one scorer (GAME_SPEC §5.3). Previews, combat, bots and tests all call `score`.
## Order: groups in summon order → base stats → face modifiers in tray order → GROUP relics
## left to right; then FINAL relics left to right; damage = floor(P × C).
## Pure: no RNG, no side effects; commit-time effects (counters, GOLD money) live in
## EncounterState, so a preview can never change the run.


static func score(db: ContentDb, army: Array[Group], relics: Array[RelicInstance], levels: Dictionary,
		ctx: ScoreCtx, rules: PackedStringArray) -> ScoreResult:
	var result := ScoreResult.new()
	var trace := result.trace
	for gi in army.size():
		var g := army[gi]
		_resolve_group(db, g, gi, relics, levels, ctx, rules, trace)
		ctx.seen_units[g.unit_id] = true
	for r in relics:
		if r.disabled:
			continue
		var row: Dictionary = db.relics[r.id]
		for block: Dictionary in RulesRegistry.relic_blocks(row):
			if block["trigger"] == "FINAL" and RelicEval.cond(block["cond"], null, -1, ctx, db):
				_apply_effects(db, block["effects"], r, -1, ctx, trace)
	result.power = ctx.p
	result.count = ctx.c
	result.damage = floorf(ctx.p * ctx.c)
	trace.append(TraceStep.make(TraceStep.Kind.TOTAL, -1, "TOTAL", "none", result.damage, ctx.p, ctx.c,
		db.text("lbl_total") % [RelicEval.fmt(ctx.p), RelicEval.fmt(ctx.c), RelicEval.fmt(result.damage)]))
	return result


static func _resolve_group(db: ContentDb, g: Group, gi: int, relics: Array[RelicInstance], levels: Dictionary,
		ctx: ScoreCtx, rules: PackedStringArray, trace: Array[TraceStep]) -> void:
	var stats := db.unit_stats(g.unit_id, levels.get(g.unit_id, 1))
	var bp := stats.x
	if rules.has("EXORCIST") and g.has_element("BONE"):
		bp = floorf(bp * 0.5)
		trace.append(TraceStep.make(TraceStep.Kind.BOSS, gi, "EXORCIST", "none", 0.0, ctx.p, ctx.c,
			db.text("lbl_exorcist_step")))
	ctx.p += bp
	ctx.c += stats.y
	trace.append(TraceStep.make(TraceStep.Kind.GROUP_BASE, gi, g.unit_id, "none", bp, ctx.p, ctx.c,
		db.text("lbl_group_base") % [RelicEval.fmt(bp), RelicEval.fmt(stats.y)]))
	for f in g.faces:
		if f.modifier == "" or f.modifier == "WILD" or f.modifier == "GOLD":
			continue
		var mod: Dictionary = db.economy["modifiers"][f.modifier]
		var v := float(mod["value"])
		var op := RelicEval.apply(mod["op"], v, ctx)
		trace.append(TraceStep.make(TraceStep.Kind.FACE_MOD, gi, f.modifier, op, v, ctx.p, ctx.c,
			RelicEval.label(db, mod["op"], v)))
	for r in relics:
		if r.disabled:
			continue
		for block: Dictionary in RulesRegistry.relic_blocks(db.relics[r.id]):
			if block["trigger"] == "GROUP" and RelicEval.cond(block["cond"], g, gi, ctx, db):
				_apply_effects(db, block["effects"], r, gi, ctx, trace)


static func _apply_effects(db: ContentDb, effects: Array, r: RelicInstance, gi: int, ctx: ScoreCtx,
		trace: Array[TraceStep]) -> void:
	for effect: Dictionary in effects:
		var v := RelicEval.value(effect["value"], r.counter, ctx)
		var op := RelicEval.apply(effect["op"], v, ctx)
		trace.append(TraceStep.make(TraceStep.Kind.RELIC, gi, r.id, op, v, ctx.p, ctx.c,
			RelicEval.label(db, effect["op"], v)))
