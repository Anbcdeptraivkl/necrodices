class_name ShopCard
extends PanelContainer
## The one Crypt Market card (ART_SPEC §6.3), Balatro style and always the same size: price tag,
## a thin rarity stripe (trinkets), the art (a die shows its six faces), BUY, and a second row
## that is BUY+USE for potions / gems and an empty slot otherwise. Used for trinkets, potions,
## gems, dice, the night's gear, coffers (OPEN) and coffer choices (TAKE, no price). Name and
## effect live in the tooltip. Buttons reflect the market's `can_*`; the screen issues commands.

signal buy_pressed(slot: int)
signal use_pressed(slot: int)

const KIND_GEAR := "GEAR"
const KIND_COFFER := "COFFER"

var slot := -1
@onready var _price: Label = %Price
@onready var _stripe: TextureRect = %Stripe
@onready var _icon: TextureRect = %Icon
@onready var _faces: GridContainer = %Faces
@onready var _buy: Button = %Buy
@onready var _use: Button = %Use


func _ready() -> void:
	_buy.pressed.connect(func() -> void: buy_pressed.emit(slot))
	_use.pressed.connect(func() -> void: use_pressed.emit(slot))


## item = {kind, id, price, sold?, die?}. `buy_text` "" = BUY with the price shown; coffers pass
## OPEN, coffer choices TAKE (price hidden). `sold_flag` names the "already bought" key.
func show_item(db: ContentDb, item: Dictionary, can_buy: bool, can_use: bool, buy_text: String = "",
		sold_flag: String = "sold") -> void:
	var kind: String = item["kind"]
	var id: String = item["id"]
	var sold: bool = item.get(sold_flag, false)
	_stripe.modulate.a = 1.0 if kind == ShopState.KIND_RELIC else 0.0
	_icon.visible = kind != ShopState.KIND_DIE
	_faces.visible = kind == ShopState.KIND_DIE
	InfoPanel.attach(self, _show_art(db, item, kind, id))
	var priced := buy_text == "" or kind == KIND_COFFER
	_price.text = "$%d" % int(item["price"]) if priced else ""
	modulate = Color(1, 1, 1, 0.45) if sold else Color.WHITE
	_buy.text = (db.text("msg_sold_out") if buy_text == "" else db.text("msg_taken")) if sold \
		else (db.text("btn_buy") if buy_text == "" else buy_text)
	_buy.disabled = sold or not can_buy
	# The second row keeps its space on every card so all cards line up.
	var usable := not sold and buy_text == "" and kind in [ShopState.KIND_POTION, ShopState.KIND_GEM]
	_use.text = db.text("btn_buy_use_short")
	_use.modulate.a = 1.0 if usable else 0.0
	_use.disabled = not (usable and can_use)
	_use.mouse_filter = Control.MOUSE_FILTER_STOP if usable else Control.MOUSE_FILTER_IGNORE


## Sets the art for the item kind and returns its tooltip callable.
func _show_art(db: ContentDb, item: Dictionary, kind: String, id: String) -> Callable:
	match kind:
		ShopState.KIND_RELIC:
			_stripe.texture = Art.ui("rarity_stripe_" + (db.relics[id]["rarity"] as String).to_lower())
			_icon.texture = Art.relic(id)
			return func() -> Dictionary: return InfoText.relic_offer(db, id)
		ShopState.KIND_DIE:
			var die := Die.from_dict(item["die"])
			_show_faces(die)
			return func() -> Dictionary: return InfoText.die(db, die, int(item.get("price", -1)))
		KIND_GEAR:
			_icon.texture = Art.equipment(id)
			return func() -> Dictionary: return InfoText.equipment(db, id)
		KIND_COFFER:
			_icon.texture = Art.coffer(id)
			return func() -> Dictionary: return InfoText.coffer(db, id)
	_icon.texture = Art.consumable(id)
	return func() -> Dictionary: return InfoText.consumable(db, id)


func _show_faces(die: Die) -> void:
	for c in _faces.get_children():
		_faces.remove_child(c)
		c.queue_free()
	for f in die.faces.size():
		var tile := FaceTile.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.show_face(die.faces[f], -1, f)
		_faces.add_child(tile)
