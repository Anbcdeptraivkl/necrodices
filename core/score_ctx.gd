class_name ScoreCtx
extends RefCounted
## Facts the relic conditions and value sources read (GAME_SPEC §5.3), built once before
## resolution, plus the running Power / Count totals. Never reads nodes or the live run.

var essence := {}           # element -> count over the whole army
var groups := 0
var money := 0
var rerolls_left := 0
var summons_left := 0
var bosses_defeated := 0
var p := 0.0
var c := 0.0
var seen_units := {}         # unit ids resolved earlier this combat (Copycat Coffin)


static func build(army: Array[Group], money_now: int, rerolls: int, summons: int, bosses: int) -> ScoreCtx:
	var ctx := ScoreCtx.new()
	for e: String in RulesRegistry.ELEMENTS:
		ctx.essence[e] = 0
	for g in army:
		for e in g.elements:
			ctx.essence[e] += 1
	ctx.groups = army.size()
	ctx.money = money_now
	ctx.rerolls_left = rerolls
	ctx.summons_left = summons
	ctx.bosses_defeated = bosses
	return ctx


func distinct_elements() -> int:
	var n := 0
	for e: String in essence:
		if essence[e] > 0:
			n += 1
	return n


func source(name: String, counter: int) -> float:
	if name.begins_with(RulesRegistry.ESSENCE_SOURCE_PREFIX):
		return essence[name.trim_prefix(RulesRegistry.ESSENCE_SOURCE_PREFIX)]
	match name:
		"money": return money
		"rerolls_left": return rerolls_left
		"summons_left": return summons_left
		"groups": return groups
		"bosses_defeated": return bosses_defeated
		"counter": return counter
	push_error("unknown value source %s" % name)
	return 0.0
