class_name BattlePlayer
extends RefCounted
## Turns what the battle model already decided into presentation beats (GAME_SPEC §11): the
## staggered roll, a summon's trace (combo → dice / runes / trinkets → strength → commit) and
## the resolve (RESOLVE trinkets → one charge per squad → result). Durations are nominal at ×1;
## within each stage of a summon (combo shakes, dice, trinkets) every step is SPEEDUP shorter
## than the one before, never below SPEEDUP_FLOOR — so a long chain plays at most twice as
## fast (D-P01). A resolve is compressed to ≤ RESOLVE_BUDGET. Everything is then divided by the
## game speed. Skipping is owned by the screen: it skips the queue, then snaps the view
## to the model.

const LAND_MIN := 0.35
const LAND_MAX := 0.9
const COMBO_TIME := 0.3        # banner + base soldiers, plus one COMBO_GAP per scoring die shake
const COMBO_GAP := 0.14
const STEP_TIME := 0.26
const TRINKET_TIME := 0.32
const SPEEDUP := 0.95
const SPEEDUP_FLOOR := 0.5
const STRENGTH_TIME := 0.35
const COMMIT_TIME := 0.3
const RESOLVE_STEP_TIME := 0.3
const CHARGE_TIME := 0.6
const RESULT_TIME := 1.0
const RESOLVE_BUDGET := 5.0


## Landing times for `n` dice: random in [LAND_MIN, LAND_MAX] from a presentation-only RNG,
## the last die always the slowest (anticipation).
static func land_times(n: int, seed: int, speed: float) -> Array[float]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out: Array[float] = []
	var slowest := 0.0
	for k in n:
		var v := rng.randf_range(LAND_MIN, LAND_MAX - 0.1)
		out.append(v / speed)
		slowest = maxf(slowest, v)
	if n > 0:
		out[rng.randi_range(0, n - 1)] = LAND_MAX / speed
	return out


static func roll(view: CombatView, indices: PackedInt32Array, seed: int, speed: float) -> Array[PresentationState]:
	var lands := land_times(indices.size(), seed, speed)
	var out: Array[PresentationState] = []
	out.append(Beat.new(func(t: Tween, _d: float) -> void: view.roll(t, indices, lands), LAND_MAX / speed + 0.05))
	return out


## The chain factor of the `n`-th step (0-based) within one stage: SPEEDUP^n, floored.
static func speedup(n: int) -> float:
	return maxf(SPEEDUP_FLOOR, pow(SPEEDUP, n))


## Nominal ×1 delays of the combo beat's dice shakes (one per scoring die), sped up like a stage.
static func combo_shakes(n: int) -> Array[float]:
	var out: Array[float] = []
	var at := 0.0
	for k in n:
		out.append(at)
		at += COMBO_GAP * speedup(k)
	return out


static func combo_time(n: int) -> float:
	var shakes := combo_shakes(n)
	return COMBO_TIME + (shakes[-1] if not shakes.is_empty() else 0.0)


## Nominal ×1 seconds of the steps between COMBO and STRENGTH. The dice stage (points, runes,
## held runes, boss rules) and the trinket stage each start at full length and speed up on their
## own.
static func step_times(steps: Array[TraceStep]) -> Array[float]:
	var out: Array[float] = []
	var dice_n := 0
	var relic_n := 0
	for k in range(1, steps.size() - 1):
		if steps[k].kind == TraceStep.Kind.TRINKET:
			out.append(TRINKET_TIME * speedup(relic_n))
			relic_n += 1
		else:
			out.append(STEP_TIME * speedup(dice_n))
			dice_n += 1
	return out


static func summon(view: CombatView, gi: int, squad: Squad, army_before: float, speed: float) -> Array[PresentationState]:
	var steps := squad.result.trace
	var times := step_times(steps)
	var out: Array[PresentationState] = []
	var first := steps[0]
	out.append(Beat.new(func(t: Tween, d: float) -> void: view.show_combo(t, gi, squad, first, d),
		combo_time(squad.scored.size()) / speed))
	for k in range(1, steps.size() - 1):
		var s := steps[k]
		var n := k
		out.append(Beat.new(func(t: Tween, d: float) -> void: view.show_step(t, gi, s, d, n), times[k - 1] / speed))
	var after := army_before + squad.result.strength
	out.append(Beat.new(func(t: Tween, d: float) -> void: view.show_strength(t, gi, squad, army_before, after, d),
		STRENGTH_TIME / speed))
	if squad.money > 0 or not squad.broken.is_empty():
		out.append(Beat.new(func(t: Tween, d: float) -> void: view.show_commit(t, squad, d), COMMIT_TIME / speed))
	return out


static func resolve(view: CombatView, res: ResolveResult, hp: float, win: bool, speed: float) -> Array[PresentationState]:
	var out: Array[PresentationState] = []
	var n_steps := res.trace.size() - 1
	var n_squads := res.shares.size()
	var raw := n_steps * RESOLVE_STEP_TIME + n_squads * CHARGE_TIME
	var squeeze := 1.0
	if raw + RESULT_TIME > RESOLVE_BUDGET and raw > 0.0:
		squeeze = maxf(0.1, (RESOLVE_BUDGET - RESULT_TIME) / raw)
	for k in n_steps:
		var s := res.trace[k]
		out.append(Beat.new(func(t: Tween, d: float) -> void: view.show_resolve_step(t, s, d),
			RESOLVE_STEP_TIME * squeeze / speed))
	var left := hp
	for gi in n_squads:
		var before := left
		left = maxf(0.0, left - res.shares[gi])
		var after := left
		var share := res.shares[gi]
		out.append(Beat.new(func(t: Tween, d: float) -> void: view.charge(t, gi, share, before, after, d),
			CHARGE_TIME * squeeze / speed))
	out.append(Beat.new(func(t: Tween, d: float) -> void: view.show_result(t, win, d), RESULT_TIME / speed))
	return out


## One beat: a parallel tween the view fills through `body(tween, duration)`; it finishes
## after `duration` at the latest (the view's tweeners may be shorter).
class Beat extends PresentationState:
	var body: Callable

	func _init(p_body: Callable, dur: float) -> void:
		body = p_body
		duration = dur

	func _start(host: Node, _speed: float) -> void:
		var t := tween(host, true).set_parallel(true)
		body.call(t, duration)
		t.tween_interval(maxf(0.01, duration))
