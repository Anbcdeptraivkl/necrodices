class_name ShopCard
extends PanelContainer
## A compact Crypt Market card (ART_SPEC §6.3), Balatro style: price tag, a thin rarity stripe
## for trinkets, the item's art (a die shows its six faces), BUY (+ USE for potions / gems).
## Name and effect live in the tooltip. Also used for coffer choices (TAKE, no price).
## Buttons reflect the market's `can_*`; the screen issues the commands.

signal buy_pressed(slot: int)
signal use_pressed(slot: int)

var slot := -1
@onready var _price: Label = %Price
@onready var _stripe: TextureRect = %Stripe
@onready var _icon: TextureRect = %Icon
@onready var _faces: GridContainer = %Faces
@onready var _buy: Button = %Buy
@onready var _use: Button = %Use
@onready var _sold: Label = %Sold


func _ready() -> void:
	_buy.pressed.connect(func() -> void: buy_pressed.emit(slot))
	_use.pressed.connect(func() -> void: use_pressed.emit(slot))


## `buy_text` "" = the default BUY with a price; a coffer choice passes TAKE.
func show_item(db: ContentDb, item: Dictionary, can_buy: bool, can_use: bool, buy_text: String = "",
		sold_flag: String = "sold") -> void:
	var kind: String = item["kind"]
	var id: String = item["id"]
	var sold: bool = item.get(sold_flag, false)
	_stripe.visible = kind == ShopState.KIND_RELIC
	_icon.visible = kind != ShopState.KIND_DIE
	_faces.visible = kind == ShopState.KIND_DIE
	var info: Callable
	match kind:
		ShopState.KIND_RELIC:
			_stripe.texture = Art.ui("rarity_stripe_" + (db.relics[id]["rarity"] as String).to_lower())
			_icon.texture = Art.relic(id)
			info = func() -> Dictionary: return InfoText.relic_offer(db, id)
		ShopState.KIND_DIE:
			var die := Die.from_dict(item["die"])
			_show_faces(die)
			info = func() -> Dictionary: return InfoText.die(db, die, int(item.get("price", -1)))
		_:
			_icon.texture = Art.consumable(id)
			info = func() -> Dictionary: return InfoText.consumable(db, id)
	_price.text = "$%d" % int(item["price"]) if buy_text == "" else ""
	_price.visible = buy_text == ""
	modulate = Color(1, 1, 1, 0.5) if sold else Color.WHITE
	_sold.visible = sold
	_sold.text = db.text("msg_sold_out") if buy_text == "" else db.text("msg_taken")
	_buy.visible = not sold
	_buy.text = db.text("btn_buy") if buy_text == "" else buy_text
	_buy.disabled = not can_buy
	_use.visible = not sold and buy_text == "" and kind in [ShopState.KIND_POTION, ShopState.KIND_GEM]
	_use.text = db.text("btn_buy_use_short")
	_use.disabled = not can_use
	InfoPanel.attach(self, info)


func _show_faces(die: Die) -> void:
	for c in _faces.get_children():
		_faces.remove_child(c)
		c.queue_free()
	for f in die.faces.size():
		var tile := FaceTile.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.show_face(die.faces[f], -1, f)
		_faces.add_child(tile)
