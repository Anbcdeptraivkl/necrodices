extends Node
## Player settings (GAME_SPEC §12.2), merged over defaults. Persisted in user://profile.json from M6.

const DEFAULTS := {
	"game_speed": 1,          # 1 / 2 / 4
	"music_volume": 0.8,
	"sfx_volume": 0.8,
	"screen_shake": true,
	"reduce_motion": false,
	"number_format": "short", # "short" | "full"
}

var values: Dictionary = DEFAULTS.duplicate()


func get_value(key: String) -> Variant:
	assert(DEFAULTS.has(key), "unknown setting %s" % key)
	return values.get(key, DEFAULTS[key])


func set_value(key: String, value: Variant) -> void:
	assert(DEFAULTS.has(key), "unknown setting %s" % key)
	values[key] = value
