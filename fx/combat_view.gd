class_name CombatView
extends Control
## What combat playback may do to a screen (GAME_SPEC §11.4). The encounter screen extends
## this; CombatPlayer's states call these with a Tween to add their tweeners to, so skipping a
## state kills one tween and `snap_*` applies the final look. Implementations never compute
## rules: every number comes from the ScoreTrace.


## Running Power / Count labels tick to these values over `dur`.
func tween_score(_t: Tween, _p: float, _c: float, _dur: float, _step: int) -> void:
	pass


## Highlight the group chip / badge being resolved (-1 = none).
func highlight_group(_gi: int) -> void:
	pass


## Shake the relic icon that fired.
func pulse_relic(_relic_id: String, _t: Tween) -> void:
	pass


## Per-group true Counts after a step; `burst` = a × step (clone burst).
func show_counts(_t: Tween, _counts: Array[float], _burst: bool, _dur: float) -> void:
	pass


func show_total(_t: Tween, _p: float, _c: float, _damage: float, _dur: float) -> void:
	pass


func charge(_t: Tween, _damage: float, _dur: float) -> void:
	pass


func show_result(_t: Tween, _win: bool, _dur: float) -> void:
	pass


## Final look after a skip: totals, counts, HP and the outcome.
func snap_final(_p: float, _c: float, _counts: Array[float], _damage: float, _win: bool) -> void:
	pass
