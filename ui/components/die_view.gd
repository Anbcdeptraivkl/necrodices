class_name DieView
extends Control
## One die (ART_SPEC §4.6): body (the rune's material while that face is up), element glyph at
## (4, 3), points badge at (13, 11), pick ring (raised 3 px), shackle overlay. Shows state;
## clicking emits `pressed(index)` — the screen decides what it means.
## Rolling: `play_roll(duration)` tumbles until `land()`; the battle playback times each
## die's landing, so dice land one by one.

signal pressed(index: int)

const RAISE := 3
const ROLL_FRAME_TIME := 0.05

var index := -1
var hovered := false:
	set(v):
		hovered = v
		_place_face()
var _face_data: Face
var _rolling := false
var _roll_time := 0.0
var _selected := false
var _locked := false   # shackled or not clickable: no hover lift
@onready var _face: Control = %Face
@onready var _body: TextureRect = %Body
@onready var _glyph: TextureRect = %Glyph
@onready var _points: TextureRect = %Points
@onready var _select: TextureRect = %Select
@onready var _shackle: TextureRect = %Shackle


func _ready() -> void:
	_body.texture = Art.dice("die_body")
	_select.texture = Art.dice("die_select")
	_shackle.texture = Art.dice("die_shackle")
	set_process(false)
	set_meta(&"press_fx", true)
	set_meta(&"hover_fx", true)


## `face` null = still in the cup (blank die).
func show_state(face: Face, selected: bool, shackled: bool, clickable: bool = true) -> void:
	_face_data = face
	_select.visible = selected
	_shackle.visible = shackled
	_selected = selected
	_locked = shackled or not clickable
	if not _rolling:
		_show_face()
	_place_face()
	mouse_default_cursor_shape = Control.CURSOR_ARROW if _locked else Control.CURSOR_POINTING_HAND


func _show_face() -> void:
	_body.texture = Art.die_body(_face_data)
	_glyph.texture = Art.face_glyph(_face_data) if _face_data != null else null
	_points.texture = Art.points_badge(_face_data)


## Picked: raised fully; hovered (free die): lifted 1 px; otherwise at rest.
func _place_face() -> void:
	if _face == null:
		return
	if _selected:
		_face.position.y = 0
	elif hovered and not _locked and mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_face.position.y = RAISE - 1
	else:
		_face.position.y = RAISE


## Tumble frames until `land()` (or `duration` seconds when > 0).
func play_roll(duration: float = 0.0) -> void:
	_rolling = true
	_roll_time = duration if duration > 0.0 else INF
	_glyph.texture = null
	_points.texture = null
	set_process(true)


## The die stops on its face with a small bounce (`t` = the playback tween, null = own).
func land(t: Tween = null) -> void:
	_rolling = false
	set_process(false)
	_show_face()
	bounce(t, 2.0)


## Skip: stop tumbling and show the face at rest (no bounce, no flash).
func stop_roll() -> void:
	if _rolling:
		_rolling = false
		set_process(false)
		_show_face()
	_body.modulate = Color.WHITE
	_place_face()


## Transient hop of the die body (pixel offsets only; rest position restored).
func bounce(t: Tween = null, height: float = 3.0) -> void:
	if _face == null:
		return
	var tw := t if t != null else create_tween()
	var rest := float(RAISE if not _selected else 0)
	tw.tween_method(func(v: float) -> void: _face.position.y = roundf(rest - v), height, 0.0, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## A white flash on the body (glass rune shattering, a rune firing).
func flash(t: Tween, colour: Color) -> void:
	t.tween_property(_body, "modulate", Color.WHITE, 0.2).from(colour)


func _process(delta: float) -> void:
	_roll_time -= delta
	if _roll_time <= 0.0:
		land()
		return
	var f := int(Time.get_ticks_msec() / (ROLL_FRAME_TIME * 1000.0) + index) % 4
	_body.texture = Art.frame("res://assets/sprites/dice/die_roll.png", 20, f)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(index)
		accept_event()
