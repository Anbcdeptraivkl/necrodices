class_name TopBar
extends PanelContainer
## Top bar shared by Night Map, Battle and Market (ART_SPEC §6.1): label left; the player's
## loadout centred like Balatro's — a trinket block (drag to reorder when allowed) and a
## potion / gem block; money, Codex and Settings right. Hovering an item shows its tooltip;
## clicking one opens a small menu (USE / SELL $n) when the screen allows those actions.
## Emits intents only; the screen applies them through commands.

signal reorder_requested(from: int, to: int)
signal settings_pressed
signal codex_pressed
signal use_requested(index: int)
signal sell_relic_requested(index: int)
signal sell_consumable_requested(index: int)

const SLOT_SCENE := "res://ui/components/item_slot.tscn"

enum Pick { NONE, RELIC, CONSUMABLE }

## What the screen lets the menu offer.
var allow_use := false
var allow_sell := false
var _relic_slots: Array[ItemSlot] = []
var _held_slots: Array[ItemSlot] = []
var _db: ContentDb
var _run: RunState
var _pick: Pick = Pick.NONE
var _pick_index := -1
@onready var _label: Label = %Label
@onready var _relics: HBoxContainer = %Relics
@onready var _consumables: HBoxContainer = %Consumables
@onready var _money: Label = %Money
@onready var _coin: TextureRect = %Coin
@onready var _settings: Button = %Settings
@onready var _codex: Button = %Codex
@onready var _menu: PanelContainer = %Menu
@onready var _use: Button = %MenuUse
@onready var _sell: Button = %MenuSell


func _ready() -> void:
	_coin.texture = Art.stat("coin")
	_settings.icon = Art.stat("gear")
	_settings.pressed.connect(func() -> void: settings_pressed.emit())
	_codex.icon = Art.stat("book")
	_codex.pressed.connect(func() -> void: codex_pressed.emit())
	_use.pressed.connect(func() -> void:
		var i := _pick_index
		close_menu()
		use_requested.emit(i))
	_sell.pressed.connect(func() -> void:
		var kind := _pick
		var i := _pick_index
		close_menu()
		if kind == Pick.RELIC:
			sell_relic_requested.emit(i)
		else:
			sell_consumable_requested.emit(i))


func setup(db: ContentDb, run: RunState, label: String) -> void:
	_db = db
	_run = run
	_label.text = label
	_codex.set_meta(&"tip", db.text("tip_codex"))
	_settings.set_meta(&"tip", db.text("tip_settings"))
	refresh()


func set_draggable(on: bool) -> void:
	for s in _relic_slots:
		s.draggable = on and s.icon != null


func relic_slot_by_id(relic_id: String) -> ItemSlot:
	for i in mini(_run.relics.size(), _relic_slots.size()):
		if _run.relics[i].id == relic_id:
			return _relic_slots[i]
	return null


func refresh() -> void:
	_grow(_relic_slots, _relics, _run.relic_slots(_db), Pick.RELIC)
	_grow(_held_slots, _consumables, _run.consumable_slots(_db), Pick.CONSUMABLE)
	for i in _relic_slots.size():
		var s := _relic_slots[i]
		var has := i < _run.relics.size()
		s.icon = Art.relic(_run.relics[i].id) if has else null
		s.dimmed = has and _run.relics[i].disabled
		s.selected = _pick == Pick.RELIC and _pick_index == i
	for i in _held_slots.size():
		var s := _held_slots[i]
		s.icon = Art.consumable(_run.consumables[i]) if i < _run.consumables.size() else null
		s.selected = _pick == Pick.CONSUMABLE and _pick_index == i
	_money.text = "$%d" % _run.money


func close_menu() -> void:
	_menu.visible = false
	_pick = Pick.NONE
	_pick_index = -1
	refresh()


func _grow(slots: Array[ItemSlot], box: HBoxContainer, count: int, kind: Pick) -> void:
	var packed: PackedScene = load(SLOT_SCENE)
	while slots.size() < count:
		var s: ItemSlot = packed.instantiate()
		var i := slots.size()
		s.index = i
		s.pressed.connect(func(_k: int) -> void: _on_slot(kind, i))
		if kind == Pick.RELIC:
			s.reorder_requested.connect(func(a: int, b: int) -> void: reorder_requested.emit(a, b))
			InfoPanel.attach(s, func() -> Dictionary:
				return InfoText.relic(_db, _run.relics[i], _run.bosses_defeated) if i < _run.relics.size() else {})
		else:
			InfoPanel.attach(s, func() -> Dictionary:
				return InfoText.consumable(_db, _run.consumables[i]) if i < _run.consumables.size() else {})
		box.add_child(s)
		slots.append(s)
	for i in slots.size():
		slots[i].visible = i < count


## Click on an item: a menu under it with the actions the screen allows (none = no menu).
func _on_slot(kind: Pick, i: int) -> void:
	var owned := _run.relics.size() if kind == Pick.RELIC else _run.consumables.size()
	var can_use := kind == Pick.CONSUMABLE and allow_use
	if i >= owned or not (can_use or allow_sell) or (_pick == kind and _pick_index == i):
		close_menu()
		return
	_pick = kind
	_pick_index = i
	_use.visible = can_use
	_use.text = _db.text("btn_use")
	_sell.visible = allow_sell
	var price := Economy.sell_price_relic(_db, _run.relics[i].id) if kind == Pick.RELIC \
		else Economy.sell_price_consumable(_db)
	_sell.text = _db.text("btn_sell_price") % price
	var slot := (_relic_slots if kind == Pick.RELIC else _held_slots)[i]
	_menu.reset_size()
	var at := slot.global_position + Vector2(slot.size.x / 2.0 - _menu.get_combined_minimum_size().x / 2.0, slot.size.y + 2)
	_menu.global_position = at.round()
	_menu.visible = true
	refresh()


func _input(event: InputEvent) -> void:
	if not _menu.visible or not (event is InputEventMouseButton and event.pressed):
		return
	var at := get_global_mouse_position()
	if _menu.get_global_rect().has_point(at):
		return
	for s in _relic_slots + _held_slots:
		if s.get_global_rect().has_point(at):
			return  # the slot's own click toggles / moves the menu
	close_menu()
