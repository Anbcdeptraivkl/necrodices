extends Overlay
## Yes / no question (e.g. "Summon nothing?"). Result: true on confirm, null otherwise.

@onready var _message: Label = %Message
@onready var _yes: Button = %Yes
@onready var _no: Button = %No


func setup(message: String, yes_text: String, no_text: String) -> void:
	_message.text = message
	_yes.text = yes_text
	_no.text = no_text


func _ready() -> void:
	_yes.pressed.connect(func() -> void:
		Audio.play("click")
		close(true))
	_no.pressed.connect(func() -> void:
		Audio.play("click")
		close(null))
