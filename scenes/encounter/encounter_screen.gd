extends Control
## Encounter screen (GAME_SPEC §4.3, ART_SPEC §6.2): wires the player's input to EncounterState
## commands and shows its state. Buttons only reflect `can()`; the commands re-check.
## After the last summon the model is resolved at once (Game.finish_encounter) and the
## BattleStage plays the trace back; tapping skips it.

const DIE_SCENE := "res://ui/components/die_view.tscn"
const CHIP_SCENE := "res://ui/components/group_chip.tscn"
const SLOT_SCENE := "res://ui/components/item_slot.tscn"
const PIP_SCENE := "res://ui/components/essence_pip.tscn"
const CONFIRM_SCENE := "res://scenes/overlays/confirm.tscn"
const CASH_OUT_SCENE := "res://scenes/overlays/cash_out.tscn"
const INSPECTOR_SCENE := "res://scenes/overlays/dice_inspector.tscn"
const RUN_INFO_SCENE := "res://scenes/overlays/run_info.tscn"
const SETTINGS_SCENE := "res://scenes/overlays/settings.tscn"
const ROLL_TIME := 0.2

var db: ContentDb
var run: RunState
var enc: EncounterState
var _dice: Array[DieView] = []
var _pips: Array[Control] = []
var _consumable_slots: Array[ItemSlot] = []
var _selected_consumable := -1
var _playing := false
var _cash_lines: Array[Dictionary] = []
var _refresh_queued := false
@onready var _top: TopBar = %TopBar
@onready var _stage: BattleStage = %Stage
@onready var _score: ScorePanel = %ScorePanel
@onready var _info: InfoPanel = %InfoPanel
@onready var _tray: HBoxContainer = %Tray
@onready var _chips: VBoxContainer = %Chips
@onready var _overlays: OverlayHost = %Overlays
@onready var _queue: PresentationQueue = %Queue
@onready var _skip: Control = %SkipCatcher
@onready var _coach: CoachMarks = CoachMarks.new()


func _ready() -> void:
	db = Game.db
	run = Game.run
	enc = Game.encounter
	_coach.setup(self, _overlays)
	_build_static()
	_connect_input()
	enc.changed.connect(_queue_refresh)
	enc.rolled.connect(_on_rolled)
	_queue.speed = Settings.speed()
	_stage.reduce_motion = Settings.get_value("reduce_motion")
	_stage.shake_on = Settings.get_value("screen_shake")
	Audio.music("night")
	if enc.turn == 0:
		enc.begin()
	_refresh()
	_coach.show_once("tut_first_roll")


func _build_static() -> void:
	var role: String = enc.entry["role"]
	_top.setup(db, run, db.text("lbl_night_role") % [run.night, db.text("role_" + role.to_lower())])
	_stage.score_panel = _score
	_stage.top_bar = _top
	_stage.setup(db, enc.entry, enc.hp)
	%RuleTitle.text = db.text("role_" + role.to_lower())
	var rules: Array = enc.entry["rules"]
	if rules.is_empty():
		%RuleText.text = db.text("rule_none") % int(db.economy["reward_" + role.to_lower()])
	else:
		var names: PackedStringArray = []
		for r: String in NightGen.active_rules(enc.entry):
			names.append(db.text("rule_short_" + r.to_lower()))
		%RuleText.text = "\n".join(names)
		InfoPanel.attach(%RulePanel, func() -> Dictionary: return InfoText.enemy(db, enc.entry))
	var die_scene: PackedScene = load(DIE_SCENE)
	for i in int(db.economy["max_dice"]):
		var d: DieView = die_scene.instantiate()
		d.index = i
		d.pressed.connect(_on_die_pressed)
		InfoPanel.attach(d, func() -> Dictionary:
			return InfoText.face(db, enc.face_at(i)) if i < enc.tray_size else {})
		_tray.add_child(d)
		_dice.append(d)
	var pip_scene: PackedScene = load(PIP_SCENE)
	for e: String in RulesRegistry.ELEMENTS:
		var pip: Control = pip_scene.instantiate()
		(pip.get_node("Pip") as TextureRect).texture = Art.pip(e)
		%Essence.add_child(pip)
		_pips.append(pip)
	var slot_scene: PackedScene = load(SLOT_SCENE)
	for i in run.consumable_slots(db):
		var s: ItemSlot = slot_scene.instantiate()
		s.index = i
		s.pressed.connect(_on_consumable_pressed)
		InfoPanel.attach(s, func() -> Dictionary:
			return InfoText.consumable(db, run.consumables[i]) if i < run.consumables.size() else {})
		%Consumables.add_child(s)
		_consumable_slots.append(s)
	%Reroll.text = db.text("btn_reroll")
	%Bind.text = db.text("btn_bind")
	%Summon.text = db.text("btn_summon")
	%Attack.text = db.text("btn_attack")
	%Header.text = db.text("lbl_groups")


func _connect_input() -> void:
	%Reroll.pressed.connect(_on_reroll)
	%Bind.pressed.connect(_on_bind)
	%Summon.pressed.connect(_on_summon)
	%Attack.pressed.connect(_on_attack)
	_top.codex_pressed.connect(func() -> void: _open(RUN_INFO_SCENE).call(&"setup", db, run))
	_top.settings_pressed.connect(func() -> void: _open(SETTINGS_SCENE))
	_top.reorder_requested.connect(func(a: int, b: int) -> void:
		if not _playing and RunFlow.reorder_relic(run, a, b):
			Audio.play("click")
			_refresh())
	_info.action_pressed.connect(_use_selected_consumable)
	_skip.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_queue.skip_all())


## Model changes are coalesced into one refresh per frame (a bot or a burst of commands
## must not rebuild the chips once per command), and the refresh never runs inside the
## handler of a control it rebuilds.
func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree():
		return
	var playing := _playing
	for i in _dice.size():
		var d := _dice[i]
		d.visible = i < enc.tray_size
		if i < enc.tray_size:
			d.show_state(enc.face_at(i), enc.selected[i] == 1, enc.bound[i], enc.shackled == i)
	_refresh_chips()
	(%Summons.get_node("Label") as Label).text = db.text("lbl_summons") % enc.summons_left
	(%Rerolls.get_node("Label") as Label).text = db.text("lbl_rerolls") % enc.rerolls_left
	%Reroll.disabled = playing or not enc.can(EncounterState.Verb.REROLL)
	%Bind.disabled = playing or not enc.can(EncounterState.Verb.BIND)
	%Summon.disabled = playing or not enc.can(EncounterState.Verb.SUMMON)
	%Attack.disabled = playing or not enc.can(EncounterState.Verb.ATTACK)
	if not playing:
		var res := enc.projected()
		_score.show_values(res.power, res.count, res.damage, enc.hp)
		_stage.set_projected(res.damage)
		var essence := enc.preview_essence()
		for k in _pips.size():
			var n: int = essence[RulesRegistry.ELEMENTS[k]]
			(_pips[k].get_node("Count") as Label).text = str(n)
			_pips[k].modulate = Color.WHITE if n > 0 else Color(1, 1, 1, 0.35)
		_stage.show_army(enc.army, run.levels)
	%HintLabel.text = _hint()
	_top.refresh()
	_top.set_draggable(not playing)
	for i in _consumable_slots.size():
		var s := _consumable_slots[i]
		s.icon = Art.consumable(run.consumables[i]) if i < run.consumables.size() else null
		s.selected = i == _selected_consumable


func _refresh_chips() -> void:
	for c in _chips.get_children():
		_chips.remove_child(c)
		c.queue_free()
	var chip_scene: PackedScene = load(CHIP_SCENE)
	for k in enc.pending.size():
		var chip: GroupChip = chip_scene.instantiate()
		_chips.add_child(chip)
		chip.show_group(db, enc.pending[k], k)
		chip.pressed.connect(_on_chip_pressed)
		var g := enc.pending[k]
		InfoPanel.attach(chip, func() -> Dictionary:
			return InfoText.unit(db, g.unit_id, run.level_of(g.unit_id), g.elements))


func _hint() -> String:
	if _playing:
		return db.text("hint_skip")
	var n := enc.selected_count()
	if n >= 2 and n <= 3:
		var preview := enc.bind_preview()
		if preview.is_empty():
			return db.text("msg_no_recipe")
		return db.text("hint_bind_preview") % [db.units[preview["unit"]]["name"],
			db.text("tier_" + db.unit_tier(preview["unit"]).to_lower())]
	if n == 1:
		return db.text("hint_select_more")
	if enc.pending.is_empty():
		return db.text("hint_start")
	return db.text("hint_summon")


func _on_rolled(indices: PackedInt32Array) -> void:
	Audio.play("roll")
	for i in indices:
		if i < _dice.size():
			_dice[i].play_roll(ROLL_TIME / Settings.speed())
	if enc.shackled >= 0:
		Audio.play("shackle")


func _on_die_pressed(i: int) -> void:
	if _playing:
		return
	var was := enc.selected[i] == 1 if i < enc.tray_size else false
	if enc.toggle_select(i):
		Audio.play("deselect" if was else "select")
	else:
		Audio.play("error")


func _on_chip_pressed(k: int) -> void:
	if enc.unbind(k):
		Audio.play("unbind")


func _on_reroll() -> void:
	if not enc.reroll():
		Audio.play("error")


func _on_bind() -> void:
	if enc.bind():
		Audio.play("bind")
		_coach.show_once("tut_first_bind")
	else:
		Audio.play("error")


func _on_summon() -> void:
	if enc.pending.is_empty():
		var c := _open(CONFIRM_SCENE)
		c.call(&"setup", db.text("msg_confirm_empty_summon"), db.text("btn_summon"), db.text("btn_cancel"))
		c.connect(&"closed", func(result: Variant) -> void:
			if result == true:
				_do_summon())
		return
	if not _coach.seen("tut_before_summon") and enc.selected_count() == 0 and _has_free_dice():
		_coach.show_once("tut_before_summon")
	_do_summon()


func _do_summon() -> void:
	if enc.summon():
		Audio.play("summon")
		_after_commit()


func _on_attack() -> void:
	if enc.attack_now():
		Audio.play("summon")
		_after_commit()


func _has_free_dice() -> bool:
	for i in enc.tray_size:
		if enc.bound[i] == -1:
			return true
	return false


func _after_commit() -> void:
	if enc.phase == EncounterState.Phase.DONE:
		_start_combat()


func _on_consumable_pressed(i: int) -> void:
	if _playing or i >= run.consumables.size():
		return
	_selected_consumable = i
	_info.set_action(db.text("btn_use"))
	_refresh()


func _use_selected_consumable(_which: int) -> void:
	var i := _selected_consumable
	if i < 0 or i >= run.consumables.size() or _playing:
		return
	var id := run.consumables[i]
	if ConsumableFx.target_count(db, id) == 0:
		var none: Array[Vector2i] = []
		_apply_consumable(i, none)
		return
	var inspector := _open(INSPECTOR_SCENE)
	inspector.call(&"setup", db, run, id)
	inspector.connect(&"closed", func(result: Variant) -> void:
		if result != null:
			var targets: Array[Vector2i] = []
			targets.assign(result)
			_apply_consumable(i, targets))


func _apply_consumable(i: int, targets: Array[Vector2i]) -> void:
	if enc.use_consumable(i, targets):
		Audio.play("buy")
		_selected_consumable = -1
		_info.set_action("")
		_info.clear()
	else:
		Audio.play("error")


func _start_combat() -> void:
	_playing = true
	_info.set_action("")
	_overlays.close_all()
	_cash_lines = Game.finish_encounter()
	_refresh()
	_coach.show_once("tut_first_combat")
	_stage.show_army(enc.army, run.levels)  # the last commit's groups join before playback
	_score.show_values(0, 0, 0, enc.hp)
	_skip.visible = true
	for s in CombatPlayer.build(_stage, enc.result, enc.army.size(), enc.win, Settings.speed()):
		_queue.push(s)
	_queue.drained.connect(_on_playback_done, CONNECT_ONE_SHOT)


func _on_playback_done() -> void:
	_skip.visible = false
	%HintLabel.text = ""
	var res := enc.result
	_stage.snap_final(res.power, res.count, CombatPlayer.final_counts(res, enc.army.size()), res.damage, enc.win)
	if not enc.win:
		get_tree().create_timer(0.6).timeout.connect(func() -> void: Game.goto("end"))
		return
	var cash := _open(CASH_OUT_SCENE)
	cash.call(&"setup", db, _cash_lines)
	cash.connect(&"closed", func(_r: Variant) -> void:
		Game.goto("end" if run.phase == RunState.Phase.VICTORY else "shop"))


func _open(path: String) -> Control:
	var packed: PackedScene = load(path)
	var overlay: Control = packed.instantiate()
	return _overlays.push(overlay)
