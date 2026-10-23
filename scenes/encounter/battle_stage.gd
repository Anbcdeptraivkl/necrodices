class_name BattleStage
extends CombatView
## The centre column of the battle (ART_SPEC §6.2): hunter zone, battlefield with the army,
## the dice tray, banners and number pops — and the CombatView playback hooks (GAME_SPEC §11).
## Shows what it is given; never reads or changes the model.

signal squad_scored(gi: int)

const ENEMY_FPS := 2.0
const POP_TIME := 0.12
const POPUPS := 12
const LUNGE_WAVES := 3

var db: ContentDb
var score_panel: ScorePanel
var top_bar: TopBar
var dice: Array[DieView] = []
var reduce_motion := false
var shake_on := true
var _enemy_id := ""
var _hp := 1.0
var _hurt := false
var _time := 0.0
var _aura_on := false
var _laughing := false
var _popups: Array[Label] = []
var _next_popup := 0
@onready var _enemy: TextureRect = %Enemy
@onready var _aura: TextureRect = %Aura
@onready var _name: Label = %EnemyName
@onready var _hp_bar: HpBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _field: Control = %Battlefield
@onready var _horde: HordeRenderer = %Horde
@onready var _slam: Label = %Slam
@onready var _banner: Label = %Banner
@onready var _mat: ShaderMaterial = _enemy.material


func _ready() -> void:
	var settings := LabelSettings.new()
	settings.font = load("res://assets/fonts/fusion_pixel/fusion_pixel_8px.otf")
	settings.font_size = 8
	settings.outline_size = 2
	settings.outline_color = Art.colour("N0")
	for i in POPUPS:
		var l := Label.new()
		l.label_settings = settings.duplicate()
		l.visible = false
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.z_index = 5
		add_child(l)
		_popups.append(l)


func setup(p_db: ContentDb, entry: Dictionary, hp: float) -> void:
	db = p_db
	_horde.db = p_db
	_enemy_id = entry["enemy"]
	_hp = hp
	var rules: Array = entry["rules"]
	var enraged := rules.has("ENRAGED")
	_name.text = db.text("rule_name_enraged") + " " + db.enemies[_enemy_id]["name"] if enraged \
		else db.enemies[_enemy_id]["name"]
	_mat.set_shader_parameter(&"enraged", 1.0 if enraged else 0.0)
	_mat.set_shader_parameter(&"dissolve", 0.0)
	_mat.set_shader_parameter(&"flash", 0.0)
	_aura_on = enraged
	_aura.visible = enraged
	_hp_bar.max_hp = hp
	_hp_bar.shown_hp = hp
	_set_hp_text(hp)
	_slam.visible = false
	_banner.visible = false
	_field.resized.connect(_fit_field)
	_fit_field()


func set_projected(damage: float) -> void:
	_hp_bar.projected = damage


## The army as the model has it (outside playback): one column per summoned squad.
func show_army(squads: Array[Squad]) -> void:
	_horde.reduce_motion = reduce_motion
	if squads.size() != _horde.groups.size():
		_horde.clear_army()
		for s in squads:
			_horde.add_group(s.unit_id, s.unit_elements, s.result.count)
	for gi in squads.size():
		if not is_equal_approx(float(_horde.groups[gi]["count"]), squads[gi].result.count):
			_horde.set_count(gi, squads[gi].result.count)
	_horde.set_highlight(-1, false)


## Final look after a skip: army, HP, outcome; no transient left over.
func snap(squads: Array[Squad], damage: float, done: bool, win: bool) -> void:
	_horde.reset_pose()
	show_army(squads)
	for d in dice:
		d.stop_roll()
	for p in _popups:
		p.visible = false
	_hurt = false
	_laughing = false
	_mat.set_shader_parameter(&"flash", 0.0)
	position = position.round()
	if done:
		var left := maxf(0.0, _hp - damage)
		_hp_bar.shown_hp = left
		_hp_bar.projected = 0.0
		_set_hp_text(left)
		_mat.set_shader_parameter(&"dissolve", 1.0 if win else 0.0)
		_show_banner(db.text("banner_win") if win else db.text("banner_lose"), win)
		if not win:
			for s in _horde.all_sprites():
				s.modulate.a = 0.0


func _fit_field() -> void:
	_horde.area = _field.size
	_horde.relayout()


func _process(delta: float) -> void:
	_time += delta
	if _enemy_id == "":
		return
	var f := 2 if _hurt else int(_time * ENEMY_FPS * (3.0 if _laughing else 1.0)) % 2
	_enemy.texture = Art.enemy(_enemy_id, f)
	if _aura_on:
		_aura.texture = Art.vfx("aura", 40, int(_time * 8.0) % 4)


# --- CombatView -------------------------------------------------------------------------

func roll(t: Tween, indices: PackedInt32Array, lands: Array[float]) -> void:
	Audio.play("roll")
	_slam.visible = false
	_banner.visible = false
	for k in indices.size():
		var i := indices[k]
		if i >= dice.size():
			continue
		var die := dice[i]
		die.play_roll()
		t.tween_callback(func() -> void:
			die.land()
			Audio.play("select", float(k) * 1.5)).set_delay(lands[k])


func show_combo(t: Tween, gi: int, squad: Squad, step: TraceStep, dur: float) -> void:
	_slam.visible = false
	_show_banner(db.text("banner_combo") % [db.combos[squad.combo]["name"], _level_of(step)], true)
	_punch_label(t, _banner)
	score_panel.show_squad(0.0, 0.0)
	score_panel.tween_squad(t, step.p_after, step.c_after, dur)
	var appeared := _horde.add_group(squad.unit_id, squad.unit_elements, step.c_after)
	_horde.set_highlight(gi, true)
	_pop(t, appeared)
	for i in squad.dice:
		if i < dice.size():
			dice[i].bounce(t, 2.0)
	Audio.play("summon")


func show_step(t: Tween, gi: int, step: TraceStep, dur: float, n: int) -> void:
	var at := _anchor_for(step)
	var colour := Art.colour("I1") if step.op.ends_with("_p") else Art.colour("R1")
	if step.kind == TraceStep.Kind.BOSS:
		colour = Art.colour("M1")
	_popup(t, step.label, at, colour, dur)
	if step.die >= 0 and step.die < dice.size():
		dice[step.die].bounce(t)
	if step.kind == TraceStep.Kind.TRINKET:
		_pulse_relic(step.source_id, t)
	score_panel.tween_squad(t, step.p_after, step.c_after, dur)
	if gi < _horde.groups.size() and not is_equal_approx(float(_horde.groups[gi]["count"]), step.c_after):
		var appeared := _horde.set_count(gi, step.c_after)
		_pop(t, appeared)
		if step.op == "mul_c":
			_clone_burst(t, gi)
			Audio.play("clone")
			return
	Audio.play_tick(n)


func show_strength(t: Tween, gi: int, squad: Squad, army_before: float, army_after: float, dur: float) -> void:
	var r := squad.result
	_slam.text = "%s × %s = %s" % [Settings.fmt(r.power), Settings.fmt(r.count), Settings.fmt(r.strength)]
	_slam.visible = true
	_banner.visible = false
	var rest := _slam.position
	t.tween_property(_slam, "position", rest, dur * 0.6).from(rest - Vector2(0, 8)) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	score_panel.tween_army(t, army_before, army_after, dur)
	t.tween_callback(func() -> void:
		_horde.set_highlight(-1, false)
		squad_scored.emit(gi)).set_delay(dur * 0.5)
	Audio.play("slam")
	_shake(t, 2)


func show_commit(t: Tween, squad: Squad, dur: float) -> void:
	if squad.money > 0:
		_popup(t, "+$%d" % squad.money, _money_anchor(), Art.colour("G1"), dur)
		Audio.play("coin")
	for i in squad.broken:
		if i < dice.size():
			dice[i].flash(t, Art.colour("I2"))
			_popup(t, db.text("pop_shatter"), _die_anchor(i), Art.colour("I2"), dur)


func show_resolve_step(t: Tween, step: TraceStep, dur: float) -> void:
	_pulse_relic(step.source_id, t)
	_popup(t, step.label, _relic_anchor(step.source_id), Art.colour("G1"), dur)
	score_panel.tween_army(t, step.p_after / maxf(step.value, 1.0) if step.op == "mul_d" else step.p_after - step.value,
		step.p_after, dur)
	Audio.play("clone")


func charge(t: Tween, gi: int, share: float, hp_before: float, hp_after: float, dur: float) -> void:
	_slam.visible = false
	_banner.visible = false
	var sprites := _horde.group_sprites(gi)
	sprites.append_array(_horde.group_auras(gi))
	_horde.set_lunging(true)
	# The hunter in battlefield coordinates (the horde draws there).
	var target := (_enemy.position + Vector2(8, 8) - _field.position).round()
	var wave_gap := minf(0.06, dur * 0.1)
	var hit_time := dur * 0.35
	for i in sprites.size():
		var s := sprites[i]
		var rest := s.position
		var delay := (i % LUNGE_WAVES) * wave_gap
		var hit := rest.lerp(target, 0.85).round()
		t.tween_property(s, "position", hit, dur * 0.3).set_delay(delay).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
		t.tween_property(s, "position", rest, dur * 0.35).set_delay(delay + dur * 0.35).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		_hurt = true
		Audio.play("hit")).set_delay(hit_time)
	t.tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"flash", v), 1.0, 0.0, dur * 0.25) \
		.set_delay(hit_time)
	_popup(t, "-" + Settings.fmt(share), _enemy_anchor(), Art.colour("R1"), dur, hit_time)
	t.tween_property(_hp_bar, "shown_hp", hp_after, dur * 0.5).from(hp_before).set_delay(hit_time)
	t.tween_method(_set_hp_text, hp_before, hp_after, dur * 0.5).set_delay(hit_time)
	t.tween_property(_hp_bar, "projected", 0.0, 0.01)
	_shake(t, 3, hit_time)
	t.tween_callback(func() -> void:
		_horde.set_lunging(false)
		_hurt = false).set_delay(dur)


func show_result(t: Tween, win: bool, dur: float) -> void:
	if win:
		Audio.play("win")
		t.tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"dissolve", v), 0.0, 1.0, dur * 0.6)
		for k in 6:
			_popup(t, "$", _enemy_anchor() + Vector2((k - 3) * 9, 0), Art.colour("G1"), dur * 0.8, k * 0.05)
		_show_banner(db.text("banner_win"), true)
	else:
		Audio.play("lose")
		_laughing = true
		var rest := _enemy.position
		t.tween_property(_enemy, "position", rest, dur * 0.3).from(rest - Vector2(0, 3))
		for s in _horde.all_sprites():
			var drift := Vector2(float((s.get_index() % 5) - 2) * 6.0, 4.0)
			t.tween_property(s, "position", s.position + drift, dur * 0.6)
			t.tween_property(s, "modulate:a", 0.0, dur * 0.6)
		_show_banner(db.text("banner_lose"), false)
	_punch_label(t, _banner)


# --- helpers ----------------------------------------------------------------------------

func _level_of(step: TraceStep) -> int:
	# The COMBO step label is "<name> Lv<n> ..."; the level is read from the trace, not the run.
	var m := RegEx.create_from_string(r"Lv(\d+)").search(step.label)
	return int(m.get_string(1)) if m != null else 1


func _show_banner(text: String, good: bool) -> void:
	_banner.text = text
	_banner.add_theme_color_override(&"font_shadow_color", Art.colour("G0") if good else Art.colour("R0"))
	_banner.visible = true


func _punch_label(t: Tween, l: Label) -> void:
	if reduce_motion:
		return
	l.pivot_offset = (l.size / 2.0).floor()
	t.tween_property(l, "scale", Vector2.ONE, 0.2).from(Vector2(1.5, 1.5)).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func _anchor_for(step: TraceStep) -> Vector2:
	if step.kind == TraceStep.Kind.TRINKET and step.die < 0:
		return _relic_anchor(step.source_id)
	if step.die >= 0:
		return _die_anchor(step.die)
	return _enemy_anchor()


func _die_anchor(i: int) -> Vector2:
	if i >= dice.size():
		return _enemy_anchor()
	return (dice[i].global_position - global_position + Vector2(10, -10)).round()


func _relic_anchor(id: String) -> Vector2:
	var slot := top_bar.relic_slot_by_id(id) if top_bar != null else null
	if slot == null:
		return _enemy_anchor()
	return (slot.global_position - global_position + Vector2(10, 22)).round()


func _money_anchor() -> Vector2:
	return Vector2(size.x - 20, 2)


func _enemy_anchor() -> Vector2:
	return (_enemy.position + Vector2(16, 8)).round()


## A number that pops above `at`, rises 10 px and fades (pool of labels; skip hides them).
func _popup(t: Tween, text: String, at: Vector2, colour: Color, dur: float, delay: float = 0.0) -> void:
	var l := _popups[_next_popup]
	_next_popup = (_next_popup + 1) % _popups.size()
	l.text = text
	l.label_settings.font_color = colour
	l.reset_size()
	var start := (at - Vector2(l.size.x / 2.0, 0)).round()
	l.position = start
	l.modulate.a = 1.0
	var rise := maxf(0.2, dur)
	t.tween_callback(func() -> void: l.visible = true).set_delay(delay)
	t.tween_property(l, "position", start - Vector2(0, 10), rise).from(start).set_delay(delay) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, rise * 0.4).set_delay(delay + rise * 0.6)
	t.tween_callback(func() -> void: l.visible = false).set_delay(delay + rise)


func _pulse_relic(relic_id: String, t: Tween) -> void:
	var slot := top_bar.relic_slot_by_id(relic_id) if top_bar != null else null
	if slot == null:
		return
	t.tween_property(slot, "shake", 0.0, 0.16).from(2.0).set_trans(Tween.TRANS_SINE)


func _clone_burst(t: Tween, gi: int) -> void:
	var punched := 0
	for s in _horde.group_sprites(gi) + _horde.group_auras(gi):
		if reduce_motion and punched >= 1:
			break
		t.tween_property(s, "scale", s.scale, POP_TIME).from(s.scale * 1.3)
		punched += 1


func _set_hp_text(v: float) -> void:
	_hp_label.text = db.text("lbl_hp") % Settings.fmt(v)


## Summon pop (ART_SPEC §10): 0.25 → 1 over 120 ms; `t` null = own tween.
func _pop(t: Tween, sprites: Array[Sprite2D]) -> void:
	if sprites.is_empty():
		return
	var tw := t if t != null else create_tween().set_parallel(true)
	for s in sprites.slice(0, 80):
		tw.tween_property(s, "scale", Vector2.ONE, POP_TIME).from(Vector2(0.25, 0.25)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(t: Tween, amount: int, delay: float = 0.0) -> void:
	if not shake_on or reduce_motion:
		return
	var rest := position.round()
	for k in 6:
		var off := Vector2((k % 2) * 2 - 1, ((k / 2) % 2) * 2 - 1) * maxi(1, amount - k / 2)
		t.tween_property(self, "position", rest + off, 0.033).set_delay(delay + k * 0.033)
	t.tween_property(self, "position", rest, 0.033).set_delay(delay + 0.2)
