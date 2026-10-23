class_name CofferCard
extends PanelContainer
## A coffer for sale (ART_SPEC §6.3): price tag, coffin icon ×2, OPEN (or "Opened"). What it
## holds is in the tooltip. The screen buys and opens it through ShopState.

signal open_pressed(slot: int)

var slot := -1
@onready var _price: Label = %Price
@onready var _icon: TextureRect = %Icon
@onready var _open: Button = %Open


func _ready() -> void:
	_open.pressed.connect(func() -> void: open_pressed.emit(slot))


func show_coffer(db: ContentDb, item: Dictionary, can_open: bool) -> void:
	var id: String = item["id"]
	_price.text = "$%d" % int(item["price"])
	_icon.texture = Art.coffer(id)
	modulate = Color(1, 1, 1, 0.5) if item["sold"] else Color.WHITE
	_open.text = db.text("msg_opened") if item["sold"] else db.text("btn_open")
	_open.disabled = item["sold"] or not can_open
	InfoPanel.attach(self, func() -> Dictionary: return InfoText.coffer(db, id))
