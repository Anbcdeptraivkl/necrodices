extends Overlay
## How to Play (GAME_SPEC §12.3): four pages, image + text, Prev / Next / Close.

const PAGES := 4

var _page := 0
@onready var _image: TextureRect = %Image
@onready var _text: Label = %Text
@onready var _prev: Button = %Prev
@onready var _next: Button = %Next
@onready var _close: Button = %Close


func _ready() -> void:
	var db: ContentDb = Game.db
	%Title.text = db.text("title_how_to_play")
	_prev.text = db.text("btn_prev")
	_next.text = db.text("btn_next")
	_close.text = db.text("btn_close")
	_prev.pressed.connect(func() -> void: _go(_page - 1))
	_next.pressed.connect(func() -> void: _go(_page + 1))
	_close.pressed.connect(func() -> void:
		Audio.play("click")
		close(null))
	_go(0)


func _go(page: int) -> void:
	_page = clampi(page, 0, PAGES - 1)
	Audio.play("page")
	_image.texture = Art.ui("howto_%d" % (_page + 1))
	_text.text = Game.db.text("howto_%d" % (_page + 1))
	_prev.disabled = _page == 0
	_next.disabled = _page == PAGES - 1
