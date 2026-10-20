class_name RelicEval
extends RefCounted
## Interpreter of the relic DSL (GAME_SPEC §9.1). Conditions read the group and the ScoreCtx;
## values may scale with a source; ops change the running totals. Every × rounds half up at
## once (§5.3) so totals stay integer-valued and reproducible by hand.


static func round_half_up(x: float) -> float:
	return floorf(x + 0.5)


## group may be null for FINAL / FIGHT_END; group_index is its index in the army (-1 if none).
static func cond(c: Dictionary, group: Group, group_index: int, ctx: ScoreCtx, db: ContentDb) -> bool:
	match c["type"]:
		"always":
			return true
		"group_has_element":
			return group != null and group.has_element(c["element"])
		"group_tier":
			return group != null and db.unit_tier(group.unit_id) == c["tier"]
		"group_unit":
			return group != null and group.unit_id == c["unit"]
		"group_is_first":
			return group_index == 0
		"group_unit_repeated":
			return group != null and ctx.seen_units.has(group.unit_id)
		"essence_gte":
			return ctx.essence[c["element"]] >= c["n"]
		"essence_eq":
			return ctx.essence[c["element"]] == c["n"]
		"distinct_elements_gte":
			return ctx.distinct_elements() >= c["n"]
		"all_elements_present":
			return ctx.distinct_elements() == RulesRegistry.ELEMENTS.size()
		"groups_gte":
			return ctx.groups >= c["n"]
	push_error("unknown condition %s" % c["type"])
	return false


static func value(v: Variant, counter: int, ctx: ScoreCtx) -> float:
	if typeof(v) == TYPE_DICTIONARY:
		return v["base"] + v["step"] * ctx.source(v["per"], counter)
	return float(v)


## Applies a scoring op to ctx.p / ctx.c; returns the trace op name of GAME_SPEC §5.4.
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
	push_error("op %s is not a scoring op" % op)
	return "none"


## Number as shown in labels: whole values without decimals, others trimmed ("1.5").
static func fmt(v: float) -> String:
	if v == floorf(v):
		return str(int(v))
	return String.num(v, 2).rstrip("0").rstrip(".")


static func label(db: ContentDb, op: String, v: float) -> String:
	return db.text("op_" + op) % fmt(v)
