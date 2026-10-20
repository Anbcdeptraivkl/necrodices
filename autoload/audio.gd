extends Node
## Audio service: pooled SFX players and a two-player music crossfade.
## Browsers block audio until a user gesture, so music() before unlock() only remembers the
## track; the title screen calls unlock() on the first click (any first press also unlocks).
## Streams load lazily on first use to keep cold start light. Volumes come from Settings
## (GAME_SPEC §12.2) and are applied per player, so no extra buses or AudioEffects (web
## Sample playback, D-A10).

const SFX_DIR := "res://assets/audio/sfx/%s.wav"
const MUSIC_PATHS := {
	"night": "res://assets/audio/music/night_loop.wav",
	"shop": "res://assets/audio/music/shop_loop.wav",
}
const SFX_NAMES: Array[String] = [
	"roll", "select", "deselect", "bind", "unbind", "summon", "tick", "clone", "slam", "hit",
	"win", "lose", "coin", "buy", "sell", "click", "error", "reroll_shop", "shackle", "page",
]
const POOL_SIZE := 8
const TICK_MAX_SEMITONES := 12
const CROSSFADE_SEC := 0.5
const SILENT_DB := -80.0

var _unlocked := false
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _sfx_cache: Dictionary = {}       # name -> AudioStream
var _reported: Dictionary = {}        # names already reported by push_error
var _music_players: Array[AudioStreamPlayer] = []
var _music_fade: Array[float] = [0.0, 0.0]  # per-player crossfade factor 0..1
var _active_music := 0
var _track := ""                      # track currently playing (or fading in)
var _requested_track := ""            # last track asked for, started on unlock
var _music_tween: Tween
var _sfx_linear := 1.0
var _music_linear := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_sfx_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.name = "Music%d" % i
		add_child(m)
		_music_players.append(m)
	apply_volumes()


func _input(event: InputEvent) -> void:
	if _unlocked:
		return
	if (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) \
			and event.is_pressed():
		unlock()


## Plays a one-shot SFX, pitched by `semitones`. Ignored before unlock().
func play(sfx_name: String, semitones: float = 0.0) -> void:
	if not _unlocked or _sfx_linear <= 0.001:
		return
	var stream := _sfx_stream(sfx_name)
	if stream == null:
		return
	var p := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = pow(2.0, semitones / 12.0)
	p.volume_db = linear_to_db(_sfx_linear)
	p.play()


## Counter tick for the score count-up: +1 semitone per step, capped (GAME_SPEC §11.4).
func play_tick(step: int) -> void:
	play("tick", float(clampi(step, 0, TICK_MAX_SEMITONES)))


## Switches music to "night", "shop" or "" (stop) with a short crossfade.
func music(track: String) -> void:
	if track != "" and not MUSIC_PATHS.has(track):
		_report("unknown music track '%s'" % track)
		return
	_requested_track = track
	if not _unlocked or track == _track:
		return
	_track = track
	var old := _active_music
	var incoming := 1 - old
	if track != "":
		var stream := _music_stream(track)
		if stream == null:
			_track = ""
			return
		_active_music = incoming
		_set_music_fade(0.0, incoming)
		_music_players[incoming].stream = stream
		_music_players[incoming].play()
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_method(_set_music_fade.bind(old), _music_fade[old], 0.0, CROSSFADE_SEC)
	if track != "":
		_music_tween.tween_method(_set_music_fade.bind(incoming), 0.0, 1.0, CROSSFADE_SEC)
	_music_tween.chain().tween_callback(_stop_faded_players)


## Call on the first user gesture (title screen click). Starts any music requested before.
func unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	set_process_input(false)
	if _requested_track != "":
		music(_requested_track)


## Re-reads music / SFX volume from Settings (after the settings screen changes them).
func apply_volumes() -> void:
	_sfx_linear = clampf(float(Settings.get_value("sfx_volume")), 0.0, 1.0)
	_music_linear = clampf(float(Settings.get_value("music_volume")), 0.0, 1.0)
	for i in _music_players.size():
		_set_music_fade(_music_fade[i], i)


func is_unlocked() -> bool:
	return _unlocked


func _set_music_fade(fade: float, index: int) -> void:
	_music_fade[index] = fade
	var linear := fade * _music_linear
	_music_players[index].volume_db = linear_to_db(linear) if linear > 0.0001 else SILENT_DB


func _stop_faded_players() -> void:
	for i in _music_players.size():
		if i != _active_music or _track == "":
			_music_players[i].stop()
			_music_fade[i] = 0.0


func _sfx_stream(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	if not SFX_NAMES.has(sfx_name):
		_report("unknown sfx '%s'" % sfx_name)
		return null
	var stream := load(SFX_DIR % sfx_name) as AudioStream
	if stream == null:
		_report("sfx '%s' failed to load" % sfx_name)
		return null
	_sfx_cache[sfx_name] = stream
	return stream


func _music_stream(track: String) -> AudioStream:
	var stream := load(MUSIC_PATHS[track]) as AudioStream
	if stream == null:
		_report("music '%s' failed to load" % track)
		return null
	var wav := stream as AudioStreamWAV
	if wav != null and wav.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		# The loop is set here instead of in a hand-written .import; the files are whole bars.
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
	return stream


func _report(message: String) -> void:
	if _reported.has(message):
		return
	_reported[message] = true
	push_error("Audio: " + message)
