class_name ScorePanel
extends PanelContainer
## The squad being picked / scored: Power × Count = strength, and the army line "ARMY a / HP"
## (ART_SPEC §6.2). Shows numbers it is given; playback tweens the displayed values with a
## bounce on the box that changed (counters tick, ART_SPEC §8).

const PUNCH := Vector2(1.3, 1.3)
const PUNCH_TIME := 0.12

var _p := 0.0
var _c := 0.0
var _army := 0.0
var _hp := 0.0
var _projected := -1.0
@onready var _power: Label = %Power
@onready var _count: Label = %Count
@onready var _total: Label = %Total
@onready var _army_label: Label = %Army
@onready var _power_box: Control = %PowerBox
@onready var _count_box: Control = %CountBox


func show_squad(p: float, c: float) -> void:
	_p = p
	_c = c
	_render()


func show_army(army: float, hp: float, projected: float = -1.0) -> void:
	_army = army
	_hp = hp
	_projected = projected
	_render()


## Ticks P and C to the new values over `dur`; the box whose value changes bounces.
func tween_squad(t: Tween, p: float, c: float, dur: float) -> void:
	if p != _p:
		_punch(t, _power_box)
		t.tween_method(func(v: float) -> void:
			_p = roundf(v)
			_render(), _p, p, dur * 0.6)
	if c != _c:
		_punch(t, _count_box)
		t.tween_method(func(v: float) -> void:
			_c = roundf(v)
			_render(), _c, c, dur * 0.6)


func tween_army(t: Tween, from: float, to: float, dur: float) -> void:
	_projected = -1.0
	_punch(t, _army_label)
	t.tween_method(func(v: float) -> void:
		_army = roundf(v)
		_render(), from, to, dur)


## Rest look after a skipped playback: no box left mid-punch.
func reset_fx() -> void:
	for box: Control in [_power_box, _count_box, _army_label]:
		box.scale = Vector2.ONE


func _punch(t: Tween, box: Control) -> void:
	if Settings.get_value("reduce_motion"):
		return
	box.pivot_offset = (box.size / 2.0).floor()
	t.tween_property(box, "scale", Vector2.ONE, PUNCH_TIME).from(PUNCH).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func _render() -> void:
	_power.text = Settings.fmt(_p)
	_count.text = Settings.fmt(_c)
	_total.text = "= %s" % Settings.fmt(floorf(_p * _c))
	# A preview (the squad being picked) shows in gold; reaching the HP turns it green.
	var preview := _projected > _army
	var shown := _projected if preview else _army
	_army_label.text = "%s / %s" % [Settings.fmt(shown), Settings.fmt(_hp)]
	var colour := Art.colour("G1") if preview else Art.colour("N7")
	if shown >= _hp and _hp > 0:
		colour = Art.colour("L2")
	_army_label.add_theme_color_override(&"font_color", colour)
