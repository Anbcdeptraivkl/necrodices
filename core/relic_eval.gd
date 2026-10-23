class_name RelicEval
extends RefCounted
## Interpreter of the trinket DSL (GAME_SPEC §9.1). Conditions read the squad, the die being
## scored (DIE trigger) and the ScoreCtx; values may scale with a source; ops change the
## running totals. Every × rounds half up at once (§5.1) so totals stay integer-valued and
## reproducible by hand.


static func round_half_up(x: float) -> float:
	return floorf(x + 0.5)


## `k` = the scored position for DIE blocks (-1 otherwise). `squads` = army size for RESOLVE.
static func cond(c: Dictionary, ctx: ScoreCtx, k: int = -1, squads: int = 0) -> bool:
	var sq := ctx.squad
	match c["type"]:
		"always":
			return true
		"die_element":
			return k >= 0 and sq.elements[k] == c["element"]
		"die_points_lte":
			return k >= 0 and not sq.faces[k].is_tomb() and sq.faces[k].points <= int(c["n"])
		"squad_combo":
			return sq != null and sq.combo == c["combo"]
		"squad_combo_in":
			return sq != null and (c["combos"] as Array).has(sq.combo)
		"squad_has_element":
			return sq != null and sq.has_element(c["element"])
		"squad_element_count_gte":
			return sq != null and sq.scored_count(c["element"]) >= int(c["n"])
		"squad_all_points_gte":
			return sq != null and _all_points_gte(sq, int(c["n"]))
		"squad_is_first":
			return ctx.squads_before == 0
		"squad_is_last":
			return ctx.summons_left == 0
		"squad_unit_repeated":
			return sq != null and ctx.seen_units.has(sq.unit_id)
		"battle_distinct_elements_gte":
			return ctx.distinct_elements() >= int(c["n"])
		"squads_gte":
			return squads >= int(c["n"])
	push_error("unknown condition %s" % c["type"])
	return false


static func _all_points_gte(sq: Squad, n: int) -> bool:
	for k in sq.scored:
		if sq.faces[k].is_tomb() or sq.faces[k].points < n:
			return false
	return not sq.scored.is_empty()


static func value(v: Variant, counter: int, ctx: ScoreCtx) -> float:
	if typeof(v) == TYPE_DICTIONARY:
		return v["base"] + v["step"] * ctx.source(v["per"], counter)
	return float(v)


## Applies a squad scoring op to ctx.p / ctx.c; returns the trace op name (§5.5).
static func apply(op: String, v: float, ctx: ScoreCtx) -> String:
	match op:
		"add_power":
			ctx.p += v
			return "add_p"
		"add_count":
			ctx.c += v
			return "add_c"
		"mul_power":
			ctx.p = round_half_up(ctx.p * v)
			return "mul_p"
		"mul_count":
			ctx.c = round_half_up(ctx.c * v)
			return "mul_c"
	push_error("op %s is not a squad scoring op" % op)
	return "none"


## Number as shown in labels: whole values without decimals, others trimmed ("1.5").
static func fmt(v: float) -> String:
	if v == floorf(v):
		return str(int(v))
	return String.num(v, 2).rstrip("0").rstrip(".")


static func label(db: ContentDb, op: String, v: float) -> String:
	return db.text("op_" + op) % fmt(v)
