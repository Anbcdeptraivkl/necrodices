class_name TopBar
extends PanelContainer
## Top bar shared by Night Map, Encounter and Shop (ART_SPEC §6.2): label left, relic bar
## centred (drag to reorder when allowed), money, the recipe codex and settings right. Emits intents; the screen
## applies them through commands.

signal relic_pressed(index: int)
signal reorder_requested(from: int, to: int)
signal settings_pressed
signal codex_pressed

const SLOT_SCENE := "res://ui/components/item_slot.tscn"

var _slots: Array[ItemSlot] = []
var _db: ContentDb
var _run: RunState
@onready var _label: Label = %Label
@onready var _relics: HBoxContainer = %Relics
@onready var _money: Label = %Money
@onready var _coin: TextureRect = %Coin
@onready var _settings: Button = %Settings
@onready var _codex: Button = %Codex


func _ready() -> void:
	_coin.texture = Art.stat("coin")
	_settings.icon = Art.stat("gear")
	_settings.pressed.connect(func() -> void: settings_pressed.emit())
	_codex.icon = Art.stat("book")
	_codex.pressed.connect(func() -> void: codex_pressed.emit())


func setup(db: ContentDb, run: RunState, label: String) -> void:
	_db = db
	_run = run
	_label.text = label
	_codex.set_meta(&"tip", db.text("tip_codex"))
	_settings.set_meta(&"tip", db.text("tip_settings"))
	refresh()


func set_draggable(on: bool) -> void:
	for s in _slots:
		s.draggable = on and s.icon != null


func slot_for(relic_index: int) -> ItemSlot:
	return _slots[relic_index] if relic_index >= 0 and relic_index < _slots.size() else null


func relic_slot_by_id(relic_id: String) -> ItemSlot:
	for i in _run.relics.size():
		if _run.relics[i].id == relic_id:
			return _slots[i]
	return null


func refresh() -> void:
	var count := _run.relic_slots(_db)
	var packed: PackedScene = load(SLOT_SCENE)
	while _slots.size() < count:
		var s: ItemSlot = packed.instantiate()
		s.index = _slots.size()
		s.pressed.connect(func(i: int) -> void: relic_pressed.emit(i))
		s.reorder_requested.connect(func(a: int, b: int) -> void: reorder_requested.emit(a, b))
		_relics.add_child(s)
		_slots.append(s)
	for i in _slots.size():
		var s := _slots[i]
		s.visible = i < count
		if i < _run.relics.size():
			var r := _run.relics[i]
			s.icon = Art.relic(r.id)
			s.dimmed = r.disabled
			InfoPanel.attach(s, func() -> Dictionary:
				return InfoText.relic(_db, _run.relics[i], _run.bosses_defeated) if i < _run.relics.size() else {})
		else:
			s.icon = null
			s.dimmed = false
			InfoPanel.attach(s, func() -> Dictionary: return {})
	_money.text = "$%d" % _run.money
