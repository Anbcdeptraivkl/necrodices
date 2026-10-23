extends Overlay
## An opened coffer (GAME_SPEC §6.9, §7): its choices as cards with TAKE, how many picks are
## left, SKIP. It only shows the market's open coffer and emits intents; the market screen
## runs the commands (and the Dice Inspector for potions), then calls `refresh`. It closes
## itself when the coffer is done.

signal take_requested(choice: int)
signal skip_requested

const CARD_SCENE := "res://ui/components/shop_card.tscn"

var _db: ContentDb
var _run: RunState
var _cards: Array[ShopCard] = []
@onready var _choices: HBoxContainer = %Choices
@onready var _skip: Button = %Skip


func setup(db: ContentDb, run: RunState) -> void:
	_db = db
	_run = run
	dismissable = false
	var open: Dictionary = run.shop.open_coffer
	%Title.text = db.coffers[open["id"]]["name"]
	_skip.text = db.text("btn_skip")
	var packed: PackedScene = load(CARD_SCENE)
	for c in (open["choices"] as Array).size():
		var card: ShopCard = packed.instantiate()
		card.slot = c
		card.buy_pressed.connect(func(i: int) -> void: take_requested.emit(i))
		_choices.add_child(card)
		_cards.append(card)
	refresh()


func _ready() -> void:
	_skip.pressed.connect(func() -> void:
		Audio.play("click")
		skip_requested.emit())


func refresh() -> void:
	var open: Dictionary = _run.shop.open_coffer
	if open.is_empty():
		close(true)
		return
	%Hint.text = _db.text("hint_coffer_picks") % int(open["picks_left"])
	var none: Array[Vector2i] = []
	for c in _cards.size():
		var item: Dictionary = open["choices"][c]
		var needs_targets: bool = item["kind"] == ShopState.KIND_POTION and ConsumableFx.target_count(_db, item["id"]) > 0
		var can := needs_targets or _run.shop.can_take(_db, _run, c, none)
		_cards[c].show_item(_db, item, can and not item["taken"], false, _db.text("btn_take"), "taken")
