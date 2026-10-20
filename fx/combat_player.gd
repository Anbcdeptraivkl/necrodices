class_name CombatPlayer
extends RefCounted
## Turns a ScoreResult into presentation states (GAME_SPEC §11.4): one state per trace step,
## then the total slam, the charge and the result. Durations: 0.25 s per group step, 0.3 s per
## final step, 0.6 s total, 0.8 s charge, 0.8 s result; when that exceeds 6 s at ×1 the steps
## are compressed uniformly to fit; then everything is divided by the game speed.
## Skipping is owned by the screen: it skips the queue, then calls CombatView.snap_final.
## Group Counts shown on the battlefield are each group's share of the running Count; a final
## step rescales every group so the badges always sum to the real Count.

const STEP_TIME := 0.25
const FINAL_TIME := 0.3
const TOTAL_TIME := 0.6
const CHARGE_TIME := 0.8
const RESULT_TIME := 0.8
const BUDGET := 6.0


static func build(view: CombatView, result: ScoreResult, groups: int, win: bool, speed: float) -> Array[PresentationState]:
	var steps: Array[TraceStep] = []
	for s in result.trace:
		if s.kind != TraceStep.Kind.TOTAL:
			steps.append(s)
	var raw := 0.0
	for s in steps:
		raw += FINAL_TIME if s.group_index < 0 else STEP_TIME
	var fixed := TOTAL_TIME + CHARGE_TIME + RESULT_TIME
	var squeeze := 1.0
	if raw + fixed > BUDGET and raw > 0.0:
		squeeze = maxf(0.05, (BUDGET - fixed) / raw)
	var out: Array[PresentationState] = []
	var counts: Array[float] = []
	counts.resize(groups)
	counts.fill(0.0)
	var c_before_group := 0.0
	var current_group := -1
	var c_prev := 0.0
	var n := 0
	for s in steps:
		if s.group_index >= 0 and s.group_index != current_group:
			current_group = s.group_index
			c_before_group = c_prev
		if s.group_index >= 0:
			counts[s.group_index] = s.c_after - c_before_group
		elif c_prev > 0.0:
			for gi in groups:
				counts[gi] = counts[gi] * s.c_after / c_prev
		var dur := (FINAL_TIME if s.group_index < 0 else STEP_TIME) * squeeze / speed
		out.append(StepState.new(view, s, counts.duplicate(), dur, n))
		c_prev = s.c_after
		n += 1
	out.append(TotalState.new(view, result.power, result.count, result.damage, TOTAL_TIME / speed))
	out.append(ChargeState.new(view, result.damage, CHARGE_TIME / speed))
	out.append(ResultState.new(view, win, RESULT_TIME / speed, result, counts.duplicate()))
	return out


static func final_counts(result: ScoreResult, groups: int) -> Array[float]:
	var states := build(null, result, groups, true, 1.0)
	var last: ResultState = states[-1]
	return last.counts


class StepState extends PresentationState:
	var view: CombatView
	var step: TraceStep
	var counts: Array[float]
	var index := 0

	func _init(p_view: CombatView, p_step: TraceStep, p_counts: Array[float], dur: float, p_index: int) -> void:
		view = p_view
		step = p_step
		counts = p_counts
		duration = dur
		index = p_index

	func _start(host: Node, _speed: float) -> void:
		var t := tween(host, true).set_parallel(true)
		view.highlight_group(step.group_index)
		if step.kind == TraceStep.Kind.RELIC:
			view.pulse_relic(step.source_id, t)
		view.tween_score(t, step.p_after, step.c_after, duration, index)
		view.show_counts(t, counts, step.op == "mul_c", duration)
		t.tween_interval(duration)

class TotalState extends PresentationState:
	var view: CombatView
	var p := 0.0
	var c := 0.0
	var damage := 0.0

	func _init(p_view: CombatView, p_p: float, p_c: float, dmg: float, dur: float) -> void:
		view = p_view
		p = p_p
		c = p_c
		damage = dmg
		duration = dur

	func _start(host: Node, _speed: float) -> void:
		view.highlight_group(-1)
		var t := tween(host, true).set_parallel(true)
		view.show_total(t, p, c, damage, duration)
		t.tween_interval(duration)


class ChargeState extends PresentationState:
	var view: CombatView
	var damage := 0.0

	func _init(p_view: CombatView, dmg: float, dur: float) -> void:
		view = p_view
		damage = dmg
		duration = dur

	func _start(host: Node, _speed: float) -> void:
		var t := tween(host, true).set_parallel(true)
		view.charge(t, damage, duration)
		t.tween_interval(duration)


class ResultState extends PresentationState:
	var view: CombatView
	var win := false
	var result: ScoreResult
	var counts: Array[float]

	func _init(p_view: CombatView, p_win: bool, dur: float, p_result: ScoreResult, p_counts: Array[float]) -> void:
		view = p_view
		win = p_win
		duration = dur
		result = p_result
		counts = p_counts

	func _start(host: Node, _speed: float) -> void:
		var t := tween(host, true).set_parallel(true)
		view.show_result(t, win, duration)
		t.tween_interval(duration)
