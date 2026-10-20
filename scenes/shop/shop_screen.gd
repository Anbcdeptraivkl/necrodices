extends Control
## Crypt Market (GAME_SPEC §4.6, ART_SPEC §6.3): buy / buy & use / sell / reroll / equipment,
## reorder relics, use held consumables. Every command goes through ShopState / ConsumableFx /
## RunFlow, then the run is saved, so Continue always restores what the player sees.

const CARD_SCENE := "res://ui/components/shop_card.tscn"
const SLOT_SCENE := "res://ui/components/item_slot.tscn"
const DIE_SCENE := "res://ui/components/die_view.tscn"
const INSPECTOR_SCENE := "res://scenes/overlays/dice_inspector.tscn"
const RUN_INFO_SCENE := "res://scenes/overlays/run_info.tscn"
const SETTINGS_SCENE := "res://scenes/overlays/settings.tscn"

enum Pick { NONE, RELIC, CONSUMABLE }

var db: ContentDb
var run: RunState
var shop: ShopState
var _cards: Array[ShopCard] = []
var _held: Array[ItemSlot] = []
var _dice: Array[DieView] = []
var _pick: Pick = Pick.NONE
var _pick_index := -1
var _time := 0.0
@onready var _top: TopBar = %TopBar
@onready var _info: InfoPanel = %InfoPanel
@onready var _overlays: OverlayHost = %Overlays
@onready var _keeper: TextureRect = %Keeper


func _ready() -> void:
	db = Game.db
	run = Game.run
	shop = run.shop
	_top.setup(db, run, db.text("msg_night") % [run.night, int(db.curve["nights"])])
	%Title.text = db.text("title_shop")
	%Reroll.pressed.connect(_on_reroll)
	%Recipes.text = db.text("btn_recipes")
	%Recipes.pressed.connect(func() -> void: _open(RUN_INFO_SCENE).call(&"setup", db, run))
	%Next.text = db.text("btn_next_fight")
	%Next.pressed.connect(func() -> void:
		Audio.play("click")
		Game.leave_shop())
	%EquipBuy.text = db.text("btn_buy")
	%EquipBuy.pressed.connect(_on_buy_equipment)
	%DiceLabel.text = db.text("lbl_your_dice")
	_top.settings_pressed.connect(func() -> void: _open(SETTINGS_SCENE))
	_top.relic_pressed.connect(func(i: int) -> void: _select(Pick.RELIC, i))
	_top.reorder_requested.connect(func(a: int, b: int) -> void:
		if RunFlow.reorder_relic(run, a, b):
			Audio.play("click")
			_changed())
	_info.action_pressed.connect(_on_info_action)
	var card_scene: PackedScene = load(CARD_SCENE)
	for i in shop.items.size():
		var card: ShopCard = card_scene.instantiate()
		card.slot = i
		card.buy_pressed.connect(_on_buy)
		card.use_pressed.connect(_on_buy_use)
		%Cards.add_child(card)
		_cards.append(card)
	var slot_scene: PackedScene = load(SLOT_SCENE)
	for i in run.consumable_slots(db):
		var s: ItemSlot = slot_scene.instantiate()
		s.index = i
		s.pressed.connect(func(k: int) -> void: _select(Pick.CONSUMABLE, k))
		InfoPanel.attach(s, func() -> Dictionary:
			return InfoText.consumable(db, run.consumables[i]) if i < run.consumables.size() else {})
		%Held.add_child(s)
		_held.append(s)
	InfoPanel.attach(%Equipment, func() -> Dictionary:
		return InfoText.equipment(db, run.equipment_offer) if run.equipment_offer != "" else {})
	%DiceStrip.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_open(INSPECTOR_SCENE).call(&"setup", db, run, ""))
	Audio.music("shop")
	_refresh()
	var coach := CoachMarks.new()
	coach.setup(self, _overlays)
	coach.show_once("tut_first_shop")


func _process(delta: float) -> void:
	_time += delta
	_keeper.texture = Art.shopkeeper(int(_time * 2.0) % 2)


func _refresh() -> void:
	_top.refresh()
	_top.set_draggable(true)
	var none: Array[Vector2i] = []
	for i in _cards.size():
		var item := shop.items[i]
		var needs_targets: bool = item["kind"] == ShopState.KIND_CONSUMABLE \
			and ConsumableFx.target_count(db, item["id"]) > 0
		# Target consumables are checked again in the inspector; here: unsold and affordable.
		var can_use: bool = shop.can_buy_use(db, run, i, none) or (needs_targets and not item["sold"]
			and run.money >= int(item["price"]))
		_cards[i].show_item(db, item, shop.can_buy(db, run, i), can_use)
	%Reroll.text = db.text("btn_reroll_shop") % shop.reroll_cost(db, run)
	%Reroll.disabled = not shop.can_reroll(db, run)
	_refresh_equipment()
	for i in _held.size():
		_held[i].icon = Art.consumable(run.consumables[i]) if i < run.consumables.size() else null
		_held[i].selected = _pick == Pick.CONSUMABLE and _pick_index == i
	_refresh_dice()
	_refresh_actions()


func _refresh_equipment() -> void:
	var id := run.equipment_offer
	%EquipIcon.texture = Art.equipment(id) if id != "" else null
	if id == "":
		%EquipName.text = db.text("msg_no_equipment")
		%EquipText.text = ""
		%EquipBuy.visible = false
		return
	%EquipName.text = "%s  $%d" % [db.equipment[id]["name"], int(db.equipment[id]["price"])]
	%EquipText.text = db.text("msg_sold_out") if run.equipment_sold else db.equipment[id]["text"]
	%EquipBuy.visible = not run.equipment_sold
	%EquipBuy.disabled = not ShopState.can_buy_equipment(db, run)


func _refresh_dice() -> void:
	var packed: PackedScene = load(DIE_SCENE)
	while _dice.size() < run.dice.size():
		var d: DieView = packed.instantiate()
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		%Dice.add_child(d)
		_dice.append(d)
	for i in _dice.size():
		_dice[i].show_state(run.dice[i].faces[_featured_face(run.dice[i])], false, -1, false)


## The face worth showing in the strip: the first modified or re-elemented face.
func _featured_face(die: Die) -> int:
	for f in die.faces.size():
		if die.faces[f].modifier != "" or die.faces[f].element != RulesRegistry.ELEMENTS[f]:
			return f
	return 0


func _refresh_actions() -> void:
	match _pick:
		Pick.RELIC:
			if _pick_index < run.relics.size():
				_info.set_action("", db.text("btn_sell_price") % Economy.sell_price_relic(db, run.relics[_pick_index].id))
				return
		Pick.CONSUMABLE:
			if _pick_index < run.consumables.size():
				_info.set_action(db.text("btn_use"), db.text("btn_sell_price") % Economy.sell_price_consumable(db))
				return
	_info.set_action("")


func _select(kind: Pick, index: int) -> void:
	_pick = kind
	_pick_index = index
	_refresh()


func _on_info_action(which: int) -> void:
	if _pick == Pick.RELIC and which == 1:
		if ShopState.sell_relic(db, run, _pick_index):
			Audio.play("sell")
			_deselect()
	elif _pick == Pick.CONSUMABLE and which == 1:
		if ShopState.sell_consumable(db, run, _pick_index):
			Audio.play("sell")
			_deselect()
	elif _pick == Pick.CONSUMABLE and which == 0:
		_use_held(_pick_index)


func _use_held(i: int) -> void:
	if i >= run.consumables.size():
		return
	_with_targets(run.consumables[i], func(targets: Array[Vector2i]) -> void:
		if ConsumableFx.use_held(db, run, i, targets):
			Audio.play("buy")
			_deselect()
		else:
			Audio.play("error"))


func _on_buy(slot: int) -> void:
	if shop.buy(db, run, slot):
		Audio.play("buy")
		_changed()
	else:
		Audio.play("error")


func _on_buy_use(slot: int) -> void:
	_with_targets(shop.items[slot]["id"], func(targets: Array[Vector2i]) -> void:
		if shop.buy_use(db, run, slot, targets):
			Audio.play("buy")
			_changed()
		else:
			Audio.play("error"))


func _on_buy_equipment() -> void:
	if ShopState.buy_equipment(db, run):
		Audio.play("buy")
		_changed()
	else:
		Audio.play("error")


func _on_reroll() -> void:
	if shop.reroll(db, run):
		Audio.play("reroll_shop")
		_changed()
	else:
		Audio.play("error")


## Calls `then(targets)` directly for target-less consumables, else after the inspector.
func _with_targets(consumable: String, then: Callable) -> void:
	if ConsumableFx.target_count(db, consumable) == 0:
		var none: Array[Vector2i] = []
		then.call(none)
		return
	var inspector := _open(INSPECTOR_SCENE)
	inspector.call(&"setup", db, run, consumable)
	inspector.connect(&"closed", func(result: Variant) -> void:
		if result != null:
			var targets: Array[Vector2i] = []
			targets.assign(result)
			then.call(targets))


func _deselect() -> void:
	_pick = Pick.NONE
	_pick_index = -1
	_info.clear()
	_changed()


func _changed() -> void:
	Game.save_run()
	_refresh.call_deferred()


func _open(path: String) -> Control:
	var overlay: Control = (load(path) as PackedScene).instantiate()
	return _overlays.push(overlay)
