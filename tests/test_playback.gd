extends TestSuite
## Summon playback timing (GAME_SPEC §11, D-P01): within each stage (combo shakes, dice,
## trinkets) every step is 5 % shorter than the one before, never below half its base length.

const COVERS: Array[String] = ["fx/battle_player.gd"]


func _steps(kinds: Array) -> Array[TraceStep]:
	var out: Array[TraceStep] = [TraceStep.make(TraceStep.Kind.COMBO, -1, "TRIO", "none", 0, 0, 0, "")]
	for kind: TraceStep.Kind in kinds:
		out.append(TraceStep.make(kind, 0, "X", "add_p", 1, 0, 0, ""))
	out.append(TraceStep.make(TraceStep.Kind.STRENGTH, -1, "STRENGTH", "none", 0, 0, 0, ""))
	return out


func test_each_step_five_percent_shorter() -> void:
	var die := TraceStep.Kind.DIE
	var times := BattlePlayer.step_times(_steps([die, die, die, die]))
	_eq(times.size(), 4, "one time per step between COMBO and STRENGTH")
	_eq(times[0], BattlePlayer.STEP_TIME, "the first step plays at full length")
	for k in range(1, times.size()):
		_check(is_equal_approx(times[k], times[k - 1] * 0.95), "step %d is 5 %% shorter than step %d" % [k, k - 1])


func test_floor_is_half() -> void:
	var kinds: Array = []
	kinds.resize(40)
	kinds.fill(TraceStep.Kind.TRINKET)
	var times := BattlePlayer.step_times(_steps(kinds))
	_check(times[-1] >= BattlePlayer.TRINKET_TIME * 0.5 - 0.0001, "never faster than twice the base speed")
	_eq(times[-1], BattlePlayer.TRINKET_TIME * 0.5, "a long chain settles at half length")
	_check(times[10] < BattlePlayer.TRINKET_TIME * 0.62, "about ten steps in, close to the floor")


func test_stages_restart() -> void:
	var die := TraceStep.Kind.DIE
	var trinket := TraceStep.Kind.TRINKET
	var times := BattlePlayer.step_times(_steps([die, die, die, trinket, trinket]))
	_eq(times[3], BattlePlayer.TRINKET_TIME, "the trinket stage starts at full length")
	_eq(times[4], BattlePlayer.TRINKET_TIME * 0.95, "and speeds up on its own")
	var shakes := BattlePlayer.combo_shakes(3)
	_eq(shakes, [0.0, BattlePlayer.COMBO_GAP, BattlePlayer.COMBO_GAP * 1.95], "combo shakes come 5 % sooner each")
