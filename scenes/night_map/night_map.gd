extends Control
## Night Map (GAME_SPEC §7.1, ART_SPEC §6.4): the night's three encounters and FIGHT.

const CARD_SCENE := "res://ui/components/encounter_card.tscn"
const SETTINGS_SCENE := "res://scenes/overlays/settings.tscn"
const RUN_INFO_SCENE := "res://scenes/overlays/run_info.tscn"

@onready var _top: TopBar = %TopBar
@onready var _cards: HBoxContainer = %Cards
@onready var _fight: Button = %Fight
@onready var _overlays: OverlayHost = %Overlays


func _ready() -> void:
	var db: ContentDb = Game.db
	var run: RunState = Game.run
	_top.setup(db, run, db.text("msg_night") % [run.night, int(db.curve["nights"])])
	_top.settings_pressed.connect(func() -> void: _overlays.push((load(SETTINGS_SCENE) as PackedScene).instantiate()))
	_top.reorder_requested.connect(func(a: int, b: int) -> void:
		if RunFlow.reorder_relic(run, a, b):
			Game.save_run()
			_top.refresh())
	_top.set_draggable(true)
	var packed: PackedScene = load(CARD_SCENE)
	for i in run.night_plan.size():
		var card: EncounterCard = packed.instantiate()
		_cards.add_child(card)
		card.show_entry(db, run, run.night_plan[i], signi(i - run.encounter_index))
	_fight.text = db.text("btn_fight")
	_fight.pressed.connect(func() -> void:
		Audio.play("click")
		Game.start_encounter())
	_top.codex_pressed.connect(func() -> void:
		var o: Control = (load(RUN_INFO_SCENE) as PackedScene).instantiate()
		_overlays.push(o)
		o.call(&"setup", db, run))
	Audio.music("night")
