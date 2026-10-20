extends Control
## Title screen (GAME_SPEC §8, ART_SPEC §6.5): Continue (if a run is saved), New Run,
## How to Play, Settings. The first click unlocks audio (browser autoplay rule).

const HOW_TO_SCENE := "res://scenes/overlays/how_to_play.tscn"
const SETTINGS_SCENE := "res://scenes/overlays/settings.tscn"

@onready var _continue: Button = %Continue
@onready var _footer: Label = %Footer
@onready var _overlays: OverlayHost = %Overlays


func _ready() -> void:
	var game := get_node_or_null("/root/Game")  # autoloads are not globals under --script tests
	var db: ContentDb = game.db if game != null else null
	var version: String = ProjectSettings.get_setting("application/config/version")
	_footer.text = "v%s" % version
	if db == null:
		return
	_continue.disabled = not game.has_saved_run()
	%Continue.text = db.text("btn_continue")
	%NewRun.text = db.text("btn_new_run")
	%HowToPlay.text = db.text("btn_how_to_play")
	%Settings.text = db.text("btn_settings")
	var last: String = game.profile.get("last_seed", "")
	if last != "":
		_footer.text = db.text("lbl_footer") % [version, last, int(game.profile.get("best_night", 0))]
	%Continue.pressed.connect(func() -> void: _press(func() -> void: game.continue_run()))
	%NewRun.pressed.connect(func() -> void: _press(func() -> void: game.new_run()))
	%HowToPlay.pressed.connect(func() -> void: _press(func() -> void: _open(HOW_TO_SCENE)))
	%Settings.pressed.connect(func() -> void: _press(func() -> void: _open(SETTINGS_SCENE)))
	get_node("/root/Audio").music("night")


func _press(action: Callable) -> void:
	var audio := get_node("/root/Audio")
	audio.unlock()
	audio.play("click")
	action.call()


func _open(path: String) -> void:
	_overlays.push((load(path) as PackedScene).instantiate())
