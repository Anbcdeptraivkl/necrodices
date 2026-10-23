extends Control
## Battle screen (GAME_SPEC §4.5, ART_SPEC §6.2): wires the player's input to EncounterState
## commands and shows its state. Buttons only reflect `can()`; the commands re-check.
## Every command resolves the model at once; the BattleStage then plays it back (roll → each
## summon's trace → the resolve) through the presentation queue. Tapping skips; while the queue
## plays, input other than skip is off.

const DIE_SCENE := "res://ui/components/die_view.tscn"
const CHIP_SCENE := "res://ui/components/squad_chip.tscn"
const PIP_SCENE := "res://ui/components/essence_pip.tscn"
const SPOILS_SCENE := "res://scenes/overlays/spoils.tscn"
const INSPECTOR_SCENE := "res://scenes/overlays/dice_inspector.tscn"
const RUN_INFO_SCENE := "res://scenes/overlays/run_info.tscn"
const SETTINGS_SCENE := "res://scenes/overlays/settings.tscn"

var db: ContentDb
var run: RunState
var enc: EncounterState
var _dice: Array[DieView] = []
var _pick_slots: Array[DieView] = []
var _pips: Array[Control] = []
var _spoils: Array[Dictionary] = []
var _refresh_queued := false
var _shown_squads := 0     # squads whose playback has finished (chips shown)
@onready var _top: TopBar = %TopBar
@onready var _stage: BattleStage = %Stage
@onready var _score: ScorePanel = %ScorePanel
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
	_queue.drained.connect(_on_drained)
	_stage.reduce_motion = Settings.get_value("reduce_motion")
	_stage.shake_on = Settings.get_value("screen_shake")
	_stage.squad_scored.connect(_on_squad_scored)
	Audio.music("night")
	if not enc.started:
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
	var names: PackedStringArray = []
	for r: String in NightGen.active_rules(enc.entry):
		names.append(db.text("rule_short_" + r.to_lower()))
	%RuleText.text = "\n".join(names) if not names.is_empty() else db.text("rule_none")
	%RuleText.theme_type_variation = &"RuleLabel" if not names.is_empty() else &"MutedLabel"
	%Bounty.text = db.text("lbl_bounty") % Economy.bounty(db, run, role)
	var die_scene: PackedScene = load(DIE_SCENE)
	for i in enc.tray_size:
		var d: DieView = die_scene.instantiate()
		d.index = i
		d.pressed.connect(_on_die_pressed)
		# Only rune faces explain themselves on hover; element and points are on the die.
		InfoPanel.attach(d, func() -> Dictionary:
			var f := enc.face_at(i)
			return InfoText.face(db, f) if f != null and f.rune != "" else {})
		_tray.add_child(d)
		_dice.append(d)
	_stage.dice = _dice
	for k in int(db.economy["pick_max"]):
		var d: DieView = die_scene.instantiate()
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		%PickSlots.add_child(d)
		_pick_slots.append(d)
	var pip_scene: PackedScene = load(PIP_SCENE)
	for e: String in RulesRegistry.ELEMENTS:
		var pip: Control = pip_scene.instantiate()
		(pip.get_node("Pip") as TextureRect).texture = Art.pip(e)
		%Essence.add_child(pip)
		_pips.append(pip)
	%Essence.set_meta(&"tip", db.text("tip_essence"))
	%GearTitle.text = db.text("lbl_equipment_short")
	%DiceTitle.text = db.text("lbl_dice")
	Loadout.fill_gear(%Gear, db, run)
	%Dice.set_meta(&"tip", db.text("tip_dice_row"))
	%Dice.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and not _queue.is_busy():
			_open(INSPECTOR_SCENE).call(&"setup", db, run, ""))
	%Reroll.text = db.text("btn_reroll")
	%Header.text = db.text("lbl_squads")
	%ArmyCaption.text = db.text("lbl_army")
	%Reroll.set_meta(&"tip", db.text("tip_reroll"))


func _connect_input() -> void:
	%Reroll.pressed.connect(_on_reroll)
	%Main.pressed.connect(_on_main)
	_top.codex_pressed.connect(func() -> void: _open(RUN_INFO_SCENE).call(&"setup", db, run))
	_top.settings_pressed.connect(func() -> void: _open(SETTINGS_SCENE))
	_top.reorder_requested.connect(func(a: int, b: int) -> void:
		if not _queue.is_busy() and RunFlow.reorder_relic(run, a, b):
			Audio.play("click")
			_refresh())
	_top.use_requested.connect(_use_consumable)
	_skip.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_skip_playback())


## Model changes are coalesced into one refresh per frame (a bot or a burst of commands must
## not rebuild the chips once per command), and the refresh never runs inside the handler of
## a control it rebuilds.
func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree():
		return
	var busy := _queue.is_busy()
	_skip.visible = busy
	for i in _dice.size():
		_dice[i].show_state(enc.face_at(i), enc.is_picked(i), enc.shackled == i,
			not busy and enc.can(EncounterState.Verb.SELECT, i))
	_refresh_pick(busy)
	_refresh_chips()
	(%Summons.get_node("Label") as Label).text = db.text("lbl_summons") % enc.summons_left
	(%Rerolls.get_node("Label") as Label).text = db.text("lbl_rerolls") % enc.rerolls_left
	%Reroll.disabled = busy or not enc.can(EncounterState.Verb.REROLL)
	var rolling := enc.phase == EncounterState.Phase.AWAIT_ROLL
	%Main.text = db.text("btn_roll") if rolling else db.text("btn_summon")
	%Main.disabled = busy or not (enc.can(EncounterState.Verb.ROLL) or enc.can(EncounterState.Verb.SUMMON))
	if not busy:
		_stage.show_army(enc.squads)
		var army := enc.army_resolution().damage if not enc.squads.is_empty() else 0.0
		var projected := enc.projected().damage
		_score.show_army(army, enc.hp, projected)
		_stage.set_projected(projected)
		_refresh_pips()
	Loadout.fill_dice(%Dice, run)
	_top.allow_use = not busy and enc.can(EncounterState.Verb.USE_CONSUMABLE)
	_top.refresh()
	_top.set_draggable(not busy)


## Pick tray: the picked dice in order, the combo they form and the squad preview.
func _refresh_pick(busy: bool) -> void:
	for k in _pick_slots.size():
		var slot := _pick_slots[k]
		var has := k < enc.picked.size()
		slot.modulate.a = 1.0 if has else 0.0
		if has:
			slot.show_state(enc.face_at(enc.picked[k]), false, false, false)
	if busy:
		return
	var preview := enc.preview()
	if preview != null:
		var r := preview.result
		%PickTitle.text = db.text("lbl_pick_combo") % [db.combos[preview.combo]["name"], run.level_of(preview.combo)]
		%PickPreview.text = "%s × %s = %s" % [Settings.fmt(r.power), Settings.fmt(r.count), Settings.fmt(r.strength)]
		_score.show_squad(r.power, r.count)
	else:
		%PickTitle.text = db.text("lbl_pick_hint") % [int(db.economy["pick_min"]), int(db.economy["pick_max"])]
		%PickPreview.text = ""
		_score.show_squad(0.0, 0.0)


func _refresh_chips() -> void:
	var shown := mini(_shown_squads, enc.squads.size())
	if _chips.get_child_count() == shown:
		return
	for c in _chips.get_children():
		_chips.remove_child(c)
		c.queue_free()
	var chip_scene: PackedScene = load(CHIP_SCENE)
	for k in shown:
		var chip: SquadChip = chip_scene.instantiate()
		_chips.add_child(chip)
		chip.show_squad(db, enc.squads[k])


## Element pips: scored dice per element this battle, plus the squad being picked.
func _refresh_pips() -> void:
	var tally := {}
	var all: Array[Squad] = enc.squads.duplicate()
	var p := enc.preview()
	if p != null:
		all.append(p)
	for s in all:
		for k in s.scored:
			if s.elements[k] != "":
				tally[s.elements[k]] = tally.get(s.elements[k], 0) + 1
	for k in _pips.size():
		var n: int = tally.get(RulesRegistry.ELEMENTS[k], 0)
		(_pips[k].get_node("Count") as Label).text = str(n)
		_pips[k].modulate = Color.WHITE if n > 0 else Color(1, 1, 1, 0.35)


# --- input ------------------------------------------------------------------------------

func _on_main() -> void:
	if _queue.is_busy():
		return
	if enc.phase == EncounterState.Phase.AWAIT_ROLL:
		if not enc.roll():
			Audio.play("error")
		return
	_on_summon()


func _on_die_pressed(i: int) -> void:
	if _queue.is_busy():
		return
	var was := enc.is_picked(i)
	if enc.toggle_select(i):
		Audio.play("deselect" if was else "select")
	else:
		Audio.play("error")


func _on_reroll() -> void:
	if _queue.is_busy() or not enc.reroll():
		Audio.play("error")


func _on_rolled(indices: PackedInt32Array) -> void:
	for s in BattlePlayer.roll(_stage, indices, Time.get_ticks_msec(), Settings.speed()):
		_queue.push(s)
	if enc.shackled >= 0:
		Audio.play("shackle")
	_queue_refresh()


func _on_summon() -> void:
	var army_before := enc.army_resolution().damage if not enc.squads.is_empty() else 0.0
	var gi := enc.squads.size()
	if not enc.summon():
		Audio.play("error")
		return
	_coach.show_once("tut_first_summon")
	var speed := Settings.speed()
	for s in BattlePlayer.summon(_stage, gi, enc.squads[gi], army_before, speed):
		_queue.push(s)
	if enc.phase == EncounterState.Phase.DONE:
		_spoils = Game.finish_encounter()
		for s in BattlePlayer.resolve(_stage, enc.resolution, enc.hp, enc.win, speed):
			_queue.push(s)
	_queue_refresh()


func _on_squad_scored(gi: int) -> void:
	_shown_squads = maxi(_shown_squads, gi + 1)
	_refresh_chips()


func _skip_playback() -> void:
	_queue.skip_all()


func _on_drained() -> void:
	_shown_squads = enc.squads.size()
	var damage := enc.resolution.damage if enc.resolution != null else 0.0
	_stage.snap(enc.squads, damage, enc.phase == EncounterState.Phase.DONE, enc.win)
	_refresh()
	if enc.phase != EncounterState.Phase.DONE:
		return
	if not enc.win:
		get_tree().create_timer(0.8).timeout.connect(func() -> void: Game.goto("end"))
		return
	var spoils := _open(SPOILS_SCENE)
	spoils.call(&"setup", db, _spoils)
	spoils.connect(&"closed", func(_r: Variant) -> void:
		Game.goto("end" if run.phase == RunState.Phase.VICTORY else "shop"))


func _use_consumable(i: int) -> void:
	if i < 0 or i >= run.consumables.size() or _queue.is_busy():
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
	else:
		Audio.play("error")


func _open(path: String) -> Control:
	var packed: PackedScene = load(path)
	var overlay: Control = packed.instantiate()
	return _overlays.push(overlay)
