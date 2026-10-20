extends Control
## Title screen (GAME_SPEC §8, ART_SPEC §6.5). Buttons call Game; no rules here.
## New Run / How to Play / Settings open their screens from M3 / M6.

@onready var _continue: Button = %Continue
@onready var _footer: Label = %Footer


func _ready() -> void:
	_continue.disabled = not FileAccess.file_exists("user://run.json")
	_footer.text = "v%s" % ProjectSettings.get_setting("application/config/version")
	var game := get_node_or_null("/root/Game")  # autoloads are not globals under --script tests
	var db: ContentDb = game.db if game != null else null
	if db != null:
		%Continue.text = db.text("btn_continue")
		%NewRun.text = db.text("btn_new_run")
		%HowToPlay.text = db.text("btn_how_to_play")
		%Settings.text = db.text("btn_settings")
