extends Control
## Crypt Market (GAME_SPEC §7, ART_SPEC §6.3), laid out like Balatro's shop: NEXT BATTLE and
## REROLL top-left, the player's gear and dice under them, the night's gear in the bottom-left
## corner; item cards and coffers in two blocks in the centre; the shopkeeper's alcove right.
## Trinkets and potions / gems owned sit in the top bar (click → SELL / USE). Names and effects
## are tooltips. Every command goes through ShopState / ConsumableFx / RunFlow, then the run is
## saved, so Continue always restores what the player sees.

const CARD_SCENE := "res://ui/components/shop_card.tscn"
const COFFER_SCENE := "res://ui/components/coffer_card.tscn"
const INSPECTOR_SCENE := "res://scenes/overlays/dice_inspector.tscn"
const COFFER_OVERLAY := "res://scenes/overlays/coffer.tscn"
const RUN_INFO_SCENE := "res://scenes/overlays/run_info.tscn"
const SETTINGS_SCENE := "res://scenes/overlays/settings.tscn"

var db: ContentDb
var run: RunState
var shop: ShopState
var _cards: Array[ShopCard] = []
var _coffers: Array[CofferCard] = []
var _time := 0.0
var _coffer_overlay: Control
@onready var _top: TopBar = %TopBar
@onready var _overlays: OverlayHost = %Overlays
@onready var _keeper: TextureRect = %Keeper


func _ready() -> void:
	db = Game.db
	run = Game.run
	shop = run.shop
	_top.setup(db, run, db.text("msg_night") % [run.night, int(db.curve["nights"])])
	_top.allow_use = true
	_top.allow_sell = true
	%Title.text = db.text("title_shop")
	%Reroll.pressed.connect(_on_reroll)
	%Reroll.set_meta(&"tip", db.text("tip_reroll_shop"))
	%EquipHeader.text = db.text("lbl_equipment")
	%GearTitle.text = db.text("lbl_equipment_short")
	%DiceTitle.text = db.text("lbl_dice")
	%Next.text = db.text("btn_next_fight")
	%Next.pressed.connect(func() -> void:
		Audio.play("click")
		Game.leave_shop())
	%EquipBuy.text = db.text("btn_buy")
	%EquipBuy.pressed.connect(_on_buy_equipment)
	_top.codex_pressed.connect(func() -> void: _open(RUN_INFO_SCENE).call(&"setup", db, run))
	_top.settings_pressed.connect(func() -> void: _open(SETTINGS_SCENE))
	_top.reorder_requested.connect(func(a: int, b: int) -> void:
		if RunFlow.reorder_relic(run, a, b):
			Audio.play("click")
			_changed())
	_top.use_requested.connect(_use_held)
	_top.sell_relic_requested.connect(func(i: int) -> void:
		if ShopState.sell_relic(db, run, i):
			Audio.play("sell")
			_changed())
	_top.sell_consumable_requested.connect(func(i: int) -> void:
		if ShopState.sell_consumable(db, run, i):
			Audio.play("sell")
			_changed())
	_build_cards()
	InfoPanel.attach(%Equipment, func() -> Dictionary:
		return InfoText.equipment(db, run.equipment_offer) if run.equipment_offer != "" else {})
	%Dice.set_meta(&"tip", db.text("tip_dice_row"))
	%Dice.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_open(INSPECTOR_SCENE).call(&"setup", db, run, ""))
	Audio.music("shop")
	_refresh()
	if not shop.open_coffer.is_empty():
		_show_coffer.call_deferred()
	var coach := CoachMarks.new()
	coach.setup(self, _overlays)
	coach.show_once("tut_first_shop")


func _build_cards() -> void:
	var card_scene: PackedScene = load(CARD_SCENE)
	for i in shop.cards.size():
		var card: ShopCard = card_scene.instantiate()
		card.slot = i
		card.buy_pressed.connect(_on_buy)
		card.use_pressed.connect(_on_buy_use)
		%Cards.add_child(card)
		_cards.append(card)
	var coffer_scene: PackedScene = load(COFFER_SCENE)
	for i in shop.coffers.size():
		var c: CofferCard = coffer_scene.instantiate()
		c.slot = i
		c.open_pressed.connect(_on_open_coffer)
		%Coffers.add_child(c)
		_coffers.append(c)


func _process(delta: float) -> void:
	_time += delta
	_keeper.texture = Art.shopkeeper(int(_time * 2.0) % 2)


func _refresh() -> void:
	_top.refresh()
	_top.set_draggable(true)
	var none: Array[Vector2i] = []
	for i in _cards.size():
		var item := shop.cards[i]
		var needs_targets: bool = item["kind"] == ShopState.KIND_POTION and ConsumableFx.target_count(db, item["id"]) > 0
		# Target potions are checked again in the inspector; here: unsold and affordable.
		var can_use: bool = shop.can_buy_use(db, run, i, none) or (needs_targets and not item["sold"]
			and run.money >= int(item["price"]) and shop.open_coffer.is_empty())
		_cards[i].show_item(db, item, shop.can_buy(db, run, i), can_use)
	for i in _coffers.size():
		_coffers[i].show_coffer(db, shop.coffers[i], shop.can_buy_coffer(db, run, i))
	%Reroll.text = db.text("btn_reroll_shop") % shop.reroll_cost(db, run)
	%Reroll.disabled = not shop.can_reroll(db, run)
	_refresh_equipment()
	Loadout.fill_gear(%Gear, db, run)
	Loadout.fill_dice(%Dice, run)


func _refresh_equipment() -> void:
	var id := run.equipment_offer
	%EquipIcon.texture = Art.equipment(id) if id != "" else null
	%EquipPrice.text = "$%d" % int(db.equipment[id]["price"]) if id != "" else db.text("msg_no_equipment")
	%EquipBuy.visible = id != "" and not run.equipment_sold
	%EquipBuy.disabled = not ShopState.can_buy_equipment(db, run)
	%Equipment.modulate = Color(1, 1, 1, 0.5) if run.equipment_sold else Color.WHITE
	if run.equipment_sold:
		%EquipPrice.text = db.text("msg_sold_out")


func _use_held(i: int) -> void:
	if i >= run.consumables.size():
		return
	_with_targets(run.consumables[i], func(targets: Array[Vector2i]) -> void:
		if ConsumableFx.use_held(db, run, i, targets):
			Audio.play("buy")
			_changed()
		else:
			Audio.play("error"))


func _on_buy(slot: int) -> void:
	if shop.buy(db, run, slot):
		Audio.play("buy")
		_changed()
	else:
		Audio.play("error")


func _on_buy_use(slot: int) -> void:
	_with_targets(shop.cards[slot]["id"], func(targets: Array[Vector2i]) -> void:
		if shop.buy_use(db, run, slot, targets):
			Audio.play("buy")
			_changed()
		else:
			Audio.play("error"))


func _on_open_coffer(slot: int) -> void:
	if not shop.buy_coffer(db, run, slot):
		Audio.play("error")
		return
	Audio.play("coin")
	_changed()
	_show_coffer()


func _show_coffer() -> void:
	_coffer_overlay = _open(COFFER_OVERLAY)
	_coffer_overlay.call(&"setup", db, run)
	_coffer_overlay.connect(&"take_requested", _on_take)
	_coffer_overlay.connect(&"skip_requested", func() -> void:
		shop.skip_coffer()
		_changed()
		_coffer_overlay.call(&"refresh"))
	_coffer_overlay.connect(&"closed", func(_r: Variant) -> void: _refresh())


func _on_take(choice: int) -> void:
	var item: Dictionary = shop.open_coffer["choices"][choice]
	var take := func(targets: Array[Vector2i]) -> void:
		if shop.take(db, run, choice, targets):
			Audio.play("buy")
			_changed()
		else:
			Audio.play("error")
		_coffer_overlay.call(&"refresh")
	if item["kind"] in [ShopState.KIND_POTION, ShopState.KIND_GEM]:
		_with_targets(item["id"], take)
	else:
		var none: Array[Vector2i] = []
		take.call(none)


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


## Calls `then(targets)` directly for target-less potions / gems, else after the inspector.
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


func _changed() -> void:
	Game.save_run()
	_refresh.call_deferred()


func _open(path: String) -> Control:
	var overlay: Control = (load(path) as PackedScene).instantiate()
	return _overlays.push(overlay)
