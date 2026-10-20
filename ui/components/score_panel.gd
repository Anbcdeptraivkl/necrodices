class_name ScorePanel
extends PanelContainer
## Power × Count = projected / HP (ART_SPEC §6.2). Shows numbers it is given; playback tweens
## the displayed values (counters tick, ART_SPEC §8).

var _p := 0.0
var _c := 0.0
var _hp := 0.0
var _damage := 0.0
@onready var _power: Label = %Power
@onready var _count: Label = %Count
@onready var _total: Label = %Total


func show_values(p: float, c: float, damage: float, hp: float) -> void:
	_p = p
	_c = c
	_damage = damage
	_hp = hp
	_render()


## Adds tweeners to `t` that tick P and C to the new values over `dur`; the total line shows
## the running product so the player sees the damage build up.
func tween_values(t: Tween, p: float, c: float, dur: float) -> void:
	t.tween_method(func(v: float) -> void:
		_p = roundf(v)
		_damage = floorf(_p * _c)
		_render(), _p, p, dur)
	t.tween_method(func(v: float) -> void:
		_c = roundf(v)
		_damage = floorf(_p * _c)
		_render(), _c, c, dur)


func _render() -> void:
	var settings := get_node("/root/Settings")
	_power.text = settings.fmt(_p)
	_count.text = settings.fmt(_c)
	_total.text = "= %s / %s" % [settings.fmt(_damage), settings.fmt(_hp)]
	_total.add_theme_color_override(&"font_color", Art.colour("L2") if _damage >= _hp and _hp > 0 else Art.colour("N7"))
