extends Overlay
## Settings (GAME_SPEC §12.2, ART_SPEC §6.6): game speed, music / SFX volume, screen shake,
## reduce motion, number format. Each button cycles its value; changes save to the profile.

const SPEEDS := [1, 2, 4]
const VOLUMES := [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]

@onready var _rows: GridContainer = %Rows
@onready var _close: Button = %Close
@onready var _quit: Button = %Quit
var _buttons := {}


func _ready() -> void:
	var db: ContentDb = Game.db
	%Title.text = db.text("title_settings")
	_close.text = db.text("btn_close")
	_quit.text = db.text("btn_title")
	_quit.visible = get_tree().current_scene.scene_file_path != Game.TITLE_SCENE
	for key: String in ["game_speed", "music_volume", "sfx_volume", "screen_shake", "reduce_motion", "number_format"]:
		var label := Label.new()
		label.text = db.text("set_" + key)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := Button.new()
		button.theme_type_variation = &"SecondaryButton"
		button.custom_minimum_size = Vector2(70, 18)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_cycle.bind(key))
		_rows.add_child(label)
		_rows.add_child(button)
		_buttons[key] = button
	_render()
	_close.pressed.connect(func() -> void:
		Audio.play("click")
		close(null))
	_quit.pressed.connect(func() -> void:
		Audio.play("click")
		close(null)
		Game.abandon_to_title())


func _cycle(key: String) -> void:
	var v: Variant = Settings.get_value(key)
	match key:
		"game_speed":
			v = SPEEDS[(SPEEDS.find(v) + 1) % SPEEDS.size()]
		"music_volume", "sfx_volume":
			var i := 0
			for k in VOLUMES.size():
				if is_equal_approx(VOLUMES[k], v):
					i = k
			v = VOLUMES[(i + 1) % VOLUMES.size()]
		"screen_shake", "reduce_motion":
			v = not v
		"number_format":
			v = "full" if v == "short" else "short"
	Settings.set_value(key, v)
	Audio.apply_volumes()
	Audio.play("click")
	Game.save_profile()
	_render()


func _render() -> void:
	var db: ContentDb = Game.db
	for key: String in _buttons:
		var v: Variant = Settings.get_value(key)
		var text: String
		match key:
			"game_speed":
				text = "×%d" % v
			"music_volume", "sfx_volume":
				text = "%d%%" % roundi(float(v) * 100.0)
			"screen_shake", "reduce_motion":
				text = db.text("set_on") if v else db.text("set_off")
			"number_format":
				text = db.text("set_" + str(v))
		(_buttons[key] as Button).text = text
