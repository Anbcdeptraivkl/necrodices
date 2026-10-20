class_name ShopCard
extends PanelContainer
## Shop item card (ART_SPEC §6.3): rarity stripe, icon ×2, name, price, BUY (+ USE for
## consumables), "Sold out" once bought. Buttons reflect the shop's `can_*`; the screen issues
## the commands.

signal buy_pressed(slot: int)
signal use_pressed(slot: int)

var slot := -1
@onready var _stripe: TextureRect = %Stripe
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _price: Label = %Price
@onready var _buy: Button = %Buy
@onready var _use: Button = %Use
@onready var _sold: Label = %Sold


func _ready() -> void:
	_buy.pressed.connect(func() -> void: buy_pressed.emit(slot))
	_use.pressed.connect(func() -> void: use_pressed.emit(slot))


func show_item(db: ContentDb, item: Dictionary, can_buy: bool, can_use: bool) -> void:
	var id: String = item["id"]
	var is_relic: bool = item["kind"] == ShopState.KIND_RELIC
	_icon.texture = Art.relic(id) if is_relic else Art.consumable(id)
	_name.text = db.relics[id]["name"] if is_relic else db.consumables[id]["name"]
	_price.text = "$%d" % int(item["price"])
	var stripe := "common"
	if is_relic:
		stripe = (db.relics[id]["rarity"] as String).to_lower()
	_stripe.texture = Art.ui("rarity_stripe_" + stripe)
	_stripe.visible = is_relic
	var sold: bool = item["sold"]
	_sold.visible = sold
	_sold.text = db.text("msg_sold_out")
	_buy.visible = not sold
	_use.visible = not sold and not is_relic
	_buy.text = db.text("btn_buy")
	_use.text = db.text("btn_buy_use")
	_buy.disabled = not can_buy
	_use.disabled = not can_use
	InfoPanel.attach(self, func() -> Dictionary:
		return InfoText.relic_offer(db, id) if is_relic else InfoText.consumable(db, id))
