class_name CombatView
extends Control
## What battle playback may do to a screen (GAME_SPEC §11). BattleStage implements it;
## BattlePlayer's beats call these with a Tween to add their tweeners to, so skipping a beat
## kills one tween and `snap` applies the final look. Implementations never compute rules:
## every number comes from a trace or a resolved squad.


## Dice `indices` tumble; die indices[k] lands at lands[k] seconds into the tween.
func roll(_t: Tween, _indices: PackedInt32Array, _lands: Array[float]) -> void:
	pass


## A squad starts: combo banner, base Power / Count, its column joins the field.
func show_combo(_t: Tween, _gi: int, _squad: Squad, _step: TraceStep, _dur: float) -> void:
	pass


## One squad trace step (die, rune, held die, trinket, boss rule).
func show_step(_t: Tween, _gi: int, _step: TraceStep, _dur: float, _n: int) -> void:
	pass


## The squad's strength slam; the army total ticks from `army_before` to `army_after`.
func show_strength(_t: Tween, _gi: int, _squad: Squad, _army_before: float, _army_after: float, _dur: float) -> void:
	pass


## Commit effects: money earned, glass runes shattering.
func show_commit(_t: Tween, _squad: Squad, _dur: float) -> void:
	pass


## A RESOLVE trinket multiplies the army.
func show_resolve_step(_t: Tween, _step: TraceStep, _dur: float) -> void:
	pass


## Squad gi charges the hunter, dealing `share`; HP drains from hp_before to hp_after.
func charge(_t: Tween, _gi: int, _share: float, _hp_before: float, _hp_after: float, _dur: float) -> void:
	pass


func show_result(_t: Tween, _win: bool, _dur: float) -> void:
	pass
