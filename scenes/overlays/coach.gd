extends Overlay
## One tutorial coach mark: a short line and OK.

@onready var _text: Label = %Text
@onready var _ok: Button = %Ok


func setup(text: String, ok: String) -> void:
	_text.text = text
	_ok.text = ok


func _ready() -> void:
	_ok.pressed.connect(func() -> void:
		Audio.play("click")
		close(true))
