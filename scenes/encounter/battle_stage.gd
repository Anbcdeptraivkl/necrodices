class_name BattleStage
extends CombatView
## The centre column of the encounter (ART_SPEC §6.2): enemy zone, battlefield with the horde,
## damage slam — and the CombatView playback hooks (GAME_SPEC §11.4, ART_SPEC §10).
## Shows what it is given; never reads or changes the model.

const ENEMY_FPS := 2.0
const LUNGE_WAVES := 4
const POP_TIME := 0.12

var db: ContentDb
var score_panel: ScorePanel
var top_bar: TopBar
var reduce_motion := false
var shake_on := true
var _enemy_id := ""
var _hp := 1.0
var _hurt := false
var _time := 0.0
var _aura_on := false
@onready var _enemy: TextureRect = %Enemy
@onready var _aura: TextureRect = %Aura
@onready var _name: Label = %EnemyName
@onready var _hp_bar: HpBar = %HpBar
@onready var _hp_label: Label = %HpLabel
@onready var _field: Control = %Battlefield
@onready var _horde: HordeRenderer = %Horde
@onready var _slam: Label = %Slam
@onready var _mat: ShaderMaterial = _enemy.material


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
	InfoPanel.attach(_enemy, func() -> Dictionary: return InfoText.enemy(db, entry))
	_field.resized.connect(_fit_field)
	_fit_field()


func set_projected(damage: float) -> void:
	_hp_bar.projected = damage


## Before combat: each summoned group shows its base Count at its level.
func show_army(army: Array[Group], levels: Dictionary) -> void:
	_horde.reduce_motion = reduce_motion
	if army.size() < _horde.groups.size():
		_horde.clear_army()
	for gi in range(_horde.groups.size(), army.size()):
		var g := army[gi]
		var c := db.unit_stats(g.unit_id, levels.get(g.unit_id, 1)).y
		var before := _horde.all_sprites()
		_horde.add_group(g.unit_id, g.elements, c)
		var appeared: Array[Sprite2D] = []
		for s in _horde.all_sprites():
			if not before.has(s):
				appeared.append(s)
		_pop(null, appeared)


func _fit_field() -> void:
	_horde.area = _field.size
	_horde.relayout()


func _process(delta: float) -> void:
	_time += delta
	if _enemy_id == "":
		return
	var f := 2 if _hurt else int(_time * ENEMY_FPS) % 2
	_enemy.texture = Art.enemy(_enemy_id, f)
	if _aura_on:
		_aura.texture = Art.vfx("aura", 40, int(_time * 8.0) % 4)


# --- CombatView -------------------------------------------------------------------------

func tween_score(t: Tween, p: float, c: float, dur: float, step: int) -> void:
	score_panel.tween_values(t, p, c, dur)
	Audio.play_tick(step)


func highlight_group(gi: int) -> void:
	_horde.set_highlight(gi, gi >= 0)


func pulse_relic(relic_id: String, t: Tween) -> void:
	var slot := top_bar.relic_slot_by_id(relic_id)
	if slot == null:
		return
	t.tween_property(slot, "shake", 0.0, 0.12).from(2.0).set_trans(Tween.TRANS_SINE)


func show_counts(t: Tween, counts: Array[float], burst: bool, _dur: float) -> void:
	var appeared: Array[Sprite2D] = []
	for gi in mini(counts.size(), _horde.groups.size()):
		if not is_equal_approx(float(_horde.groups[gi]["count"]), counts[gi]):
			appeared.append_array(_horde.set_count(gi, counts[gi]))
	_pop(t, appeared)
	if burst:
		Audio.play("clone")
		var punched := 0
		for s in _horde.all_sprites():
			if reduce_motion and punched >= _horde.groups.size():
				break
			t.tween_property(s, "scale", Vector2.ONE, POP_TIME).from(Vector2(1.25, 1.25))
			punched += 1


func show_total(t: Tween, p: float, c: float, damage: float, dur: float) -> void:
	var settings := get_node("/root/Settings")
	_slam.text = "%s × %s = %s" % [settings.fmt(p), settings.fmt(c), settings.fmt(damage)]
	_slam.visible = true
	var rest := _slam.position
	t.tween_property(_slam, "position", rest, dur * 0.5).from(rest - Vector2(0, 8)) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Audio.play("slam")
	_shake(t)


func charge(t: Tween, damage: float, dur: float) -> void:
	_horde.set_lunging(true)
	var target := Vector2(_field.size.x / 2.0 - 8.0, -24.0)
	var sprites := _horde.all_sprites()
	var wave_gap := minf(0.1, dur * 0.12)
	for i in sprites.size():
		var s := sprites[i]
		var rest := _horde.rest_position(s)
		var delay := (i % LUNGE_WAVES) * wave_gap
		var hit := rest.lerp(target, 0.45).round()
		t.tween_property(s, "position", hit, dur * 0.22).set_delay(delay).set_ease(Tween.EASE_IN)
		t.tween_property(s, "position", rest, dur * 0.28).set_delay(delay + dur * 0.22).set_ease(Tween.EASE_OUT)
	var hit_time := dur * 0.25
	t.tween_callback(func() -> void:
		_hurt = true
		Audio.play("hit")).set_delay(hit_time)
	t.tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"flash", v), 1.0, 0.0, 0.05).set_delay(hit_time)
	var left := maxf(0.0, _hp - damage)
	t.tween_property(_hp_bar, "shown_hp", left, dur * 0.5).set_delay(hit_time)
	t.tween_method(_set_hp_text, _hp, left, dur * 0.5).set_delay(hit_time)
	t.tween_property(_hp_bar, "projected", 0.0, 0.01)
	t.tween_callback(func() -> void:
		_horde.set_lunging(false)
		_hurt = false).set_delay(dur)


func show_result(t: Tween, win: bool, dur: float) -> void:
	if win:
		Audio.play("win")
		t.tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"dissolve", v), 0.0, 1.0, dur * 0.6)
	else:
		Audio.play("lose")
		var rest := _enemy.position
		t.tween_property(_enemy, "position", rest, dur * 0.3).from(rest - Vector2(0, 2))
		for s in _horde.all_sprites():
			t.tween_property(s, "modulate:a", 0.0, dur * 0.6)


func snap_final(p: float, c: float, counts: Array[float], damage: float, win: bool) -> void:
	_horde.reset_pose()
	for gi in mini(counts.size(), _horde.groups.size()):
		_horde.set_count(gi, counts[gi])
	_horde.set_highlight(-1, false)
	score_panel.show_values(p, c, damage, _hp)
	var settings := get_node("/root/Settings")
	_slam.text = "%s × %s = %s" % [settings.fmt(p), settings.fmt(c), settings.fmt(damage)]
	_slam.visible = true
	var left := maxf(0.0, _hp - damage)
	_hp_bar.shown_hp = left
	_hp_bar.projected = 0.0
	_set_hp_text(left)
	_hurt = false
	_mat.set_shader_parameter(&"flash", 0.0)
	_mat.set_shader_parameter(&"dissolve", 1.0 if win else 0.0)
	if not win:
		for s in _horde.all_sprites():
			s.modulate.a = 0.0


func _set_hp_text(v: float) -> void:
	_hp_label.text = db.text("lbl_hp") % get_node("/root/Settings").fmt(v)


## Summon pop (ART_SPEC §10): 0 → 1.25 → 1 over 120 ms; `t` null = own tween.
func _pop(t: Tween, sprites: Array[Sprite2D]) -> void:
	if sprites.is_empty():
		return
	var tw := t if t != null else create_tween().set_parallel(true)
	for s in sprites.slice(0, 80):
		tw.tween_property(s, "scale", Vector2.ONE, POP_TIME).from(Vector2(0.25, 0.25)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(t: Tween) -> void:
	if not shake_on or reduce_motion:
		return
	var rest := position
	for k in 6:
		var off := Vector2((k % 2) * 2 - 1, ((k / 2) % 2) * 2 - 1) * (3 - k / 2)
		t.tween_property(self, "position", rest + off, 0.033).set_delay(k * 0.033)
	t.tween_property(self, "position", rest, 0.033).set_delay(0.2)
