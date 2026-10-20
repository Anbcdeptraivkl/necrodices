extends Node
## Player settings (GAME_SPEC §12.2), merged over defaults; persisted inside profile.json by
## Game.save_profile(). Emits `changed` so screens and Audio can re-read.

signal changed

const DEFAULTS := {
	"game_speed": 1,          # 1 / 2 / 4
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"screen_shake": true,
	"reduce_motion": false,
	"number_format": "short", # "short" | "full"
}

var values: Dictionary = DEFAULTS.duplicate()


func load_from(saved: Dictionary) -> void:
	values = DEFAULTS.duplicate()
	for key: String in saved:
		if not DEFAULTS.has(key):
			continue
		var want := typeof(DEFAULTS[key])
		var got := typeof(saved[key])
		if got == want:
			values[key] = saved[key]
		elif want == TYPE_FLOAT and got == TYPE_INT:  # JSON narrowing turns 1.0 into 1
			values[key] = float(saved[key])
	changed.emit()


func get_value(key: String) -> Variant:
	assert(DEFAULTS.has(key), "unknown setting %s" % key)
	return values.get(key, DEFAULTS[key])


func set_value(key: String, value: Variant) -> void:
	assert(DEFAULTS.has(key), "unknown setting %s" % key)
	values[key] = value
	changed.emit()


func speed() -> float:
	return float(get_value("game_speed"))


func full_numbers() -> bool:
	return get_value("number_format") == "full"


func fmt(v: float) -> String:
	return NumberFormat.format(v, full_numbers())
