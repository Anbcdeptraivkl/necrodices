class_name HordeRenderer
extends Node2D
## Draws the army on the battlefield (GAME_SPEC §11): per-group visible counts from the true
## Count (linear to 12, log beyond, cap 40), render tiers by total visible (≤60 full 16×16
## sprites, ≤240 8×8 minis, else 240 minis + LEGION banners), groups in columns left→right,
## jittered grid seeded by group index (never the game RNG), idle bob ±1 px at 1.5 Hz.
## A pool of POOL Sprite2Ds is allocated once; nothing is instantiated during playback.
## Pure view: it shows counts it is given and never reads the model.

const POOL := 260
const FULL_LIMIT := 60
const MINI_LIMIT := 240
const BOB_HZ := 1.5
const IDLE_FPS := 3.0

var db: ContentDb
var area := Vector2(224, 140)
## Per group: {unit, elements, count (true), visible, highlight}
var groups: Array[Dictionary] = []
var reduce_motion := false

var _sprites: Array[Sprite2D] = []
var _assign: Array = []          # group index -> Array[int] sprite indices
var _base_pos: PackedVector2Array = []
var _phase: PackedFloat32Array = []
var _sprite_group: PackedInt32Array = []
var _tier := 0                   # 0 full, 1 minis, 2 legion
var _time := 0.0
var _font: Font
var _lunging := false


func _ready() -> void:
	_font = load("res://assets/fonts/fusion_pixel/fusion_pixel_8px.otf")
	for i in POOL:
		var s := Sprite2D.new()
		s.centered = false
		s.visible = false
		add_child(s)
		_sprites.append(s)
	_base_pos.resize(POOL)
	_phase.resize(POOL)
	_sprite_group.resize(POOL)


## GAME_SPEC §11.1
static func visible_for(count: float) -> int:
	if count <= 0.0:
		return 0
	if count <= 12.0:
		return int(ceilf(count))
	return mini(12 + int(floor(6.0 * log(count / 12.0) / log(2.0))), 40)


func clear_army() -> void:
	groups.clear()
	_relayout()


func add_group(unit_id: String, elements: PackedStringArray, count: float) -> int:
	groups.append({"unit": unit_id, "elements": elements, "count": count, "visible": 0, "highlight": false})
	_relayout()
	return groups.size() - 1


## Sets one group's true Count; returns the sprites that just appeared (for a pop tween).
func set_count(gi: int, count: float) -> Array[Sprite2D]:
	groups[gi]["count"] = count
	return _relayout()


## Re-place every sprite (after the battlefield is resized).
func relayout() -> void:
	_relayout()


func set_highlight(gi: int, on: bool) -> void:
	for g in groups:
		g["highlight"] = false
	if gi >= 0 and gi < groups.size():
		groups[gi]["highlight"] = on
	queue_redraw()


func total_visible() -> int:
	var n := 0
	for g in groups:
		n += visible_for(g["count"])
	return n


func group_sprites(gi: int) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	if gi < _assign.size():
		for i: int in _assign[gi]:
			out.append(_sprites[i])
	return out


func all_sprites() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	for s in _sprites:
		if s.visible:
			out.append(s)
	return out


## Resting position of a sprite (tweens return here; skip snaps here).
func rest_position(s: Sprite2D) -> Vector2:
	return _base_pos[_sprites.find(s)]


func set_lunging(on: bool) -> void:
	_lunging = on


func reset_pose() -> void:
	_lunging = false
	for i in POOL:
		var s := _sprites[i]
		s.scale = Vector2.ONE
		s.modulate = Color.WHITE
		s.position = _base_pos[i]


func _relayout() -> Array[Sprite2D]:
	var before := {}
	for s in _sprites:
		if s.visible:
			before[s] = true
	var counts: Array[int] = []
	var total := 0
	for g in groups:
		var v := visible_for(g["count"])
		counts.append(v)
		total += v
	_tier = 0 if total <= FULL_LIMIT else (1 if total <= MINI_LIMIT else 2)
	if _tier == 2:
		counts = _scale_counts(counts, MINI_LIMIT)
	var cell := Vector2(11, 12) if _tier == 0 else Vector2(7, 7)
	var sprite_size := 16 if _tier == 0 else 8
	_assign.clear()
	var next := 0
	var columns := _columns(counts, cell)
	for gi in groups.size():
		var ids: Array[int] = []
		var col: Rect2 = columns[gi]
		var per_row := maxi(1, int(col.size.x / cell.x))
		var rng := RandomNumberGenerator.new()
		rng.seed = gi * 7919 + 13
		for k in counts[gi]:
			if next >= POOL:
				break
			var row := k / per_row
			var c := k % per_row
			var x := col.position.x + c * cell.x + rng.randi_range(-1, 1) + (row % 2) * floorf(cell.x / 2.0)
			var y := area.y - sprite_size - row * cell.y + rng.randi_range(-1, 1)
			_place(next, gi, Vector2(roundf(x), roundf(maxf(12.0, y))))
			ids.append(next)
			next += 1
		_assign.append(ids)
		groups[gi]["visible"] = counts[gi]
	for i in range(next, POOL):
		_sprites[i].visible = false
	queue_redraw()
	var appeared: Array[Sprite2D] = []
	for i in next:
		if not before.has(_sprites[i]):
			appeared.append(_sprites[i])
	return appeared


func _place(i: int, gi: int, pos: Vector2) -> void:
	var s := _sprites[i]
	var g := groups[gi]
	s.texture = _texture(g, 0)
	s.position = pos
	s.visible = true
	_base_pos[i] = pos
	_sprite_group[i] = gi
	_phase[i] = fmod(float(i) * 0.37, 1.0)


func _texture(g: Dictionary, f: int) -> Texture2D:
	if _tier == 0:
		return Art.unit(g["unit"], f, g["elements"])
	return Art.mini(db, g["unit"], f, g["elements"])


## Column rects: widths proportional to each group's visible count (min one cell + gap).
func _columns(counts: Array[int], cell: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var weight := 0.0
	for v in counts:
		weight += maxf(1.0, sqrt(v))
	var x := 2.0
	var usable := area.x - 4.0
	for v in counts:
		var w := maxf(cell.x + 2.0, floorf(usable * maxf(1.0, sqrt(v)) / maxf(1.0, weight)))
		out.append(Rect2(x, 0, w - 2.0, area.y))
		x += w
	return out


static func _scale_counts(counts: Array[int], limit: int) -> Array[int]:
	var total := 0
	for v in counts:
		total += v
	var out: Array[int] = []
	for v in counts:
		out.append(maxi(1, int(floor(float(v) * limit / total))))
	return out


func _process(delta: float) -> void:
	_time += delta
	var bob := not reduce_motion and not _lunging
	for i in POOL:
		var s := _sprites[i]
		if not s.visible:
			continue
		var t := _time * BOB_HZ + _phase[i]
		var f := int(_time * IDLE_FPS + _phase[i] * 2.0) % 2
		s.texture = _texture(groups[_sprite_group[i]], f)
		if bob:
			s.position.y = _base_pos[i].y + (1.0 if fmod(t, 1.0) < 0.5 else 0.0)


func _draw() -> void:
	var columns_x := {}
	for gi in groups.size():
		var ids: Array = _assign[gi] if gi < _assign.size() else []
		if ids.is_empty():
			continue
		var min_x := INF
		var max_x := -INF
		var min_y := INF
		for i: int in ids:
			min_x = minf(min_x, _base_pos[i].x)
			max_x = maxf(max_x, _base_pos[i].x)
			min_y = minf(min_y, _base_pos[i].y)
		columns_x[gi] = true
		var g := groups[gi]
		var text := NumberFormat.format(g["count"])
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4
		var cx := roundf((min_x + max_x + (16 if _tier == 0 else 8)) / 2.0)
		var pos := Vector2(roundf(cx - w / 2.0), maxf(0.0, min_y - 11))
		var bg := Art.colour("G1") if g["highlight"] else Art.colour("N0")
		draw_rect(Rect2(pos, Vector2(w, 10)), bg)
		draw_string(_font, pos + Vector2(2, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Art.colour("N0") if g["highlight"] else Art.colour("R1"))
		if _tier == 2:
			var banner := Art.tex("res://assets/sprites/units/legion_banner.png")
			draw_texture(banner, pos + Vector2(w + 1, -3))
			draw_texture(Art.mini(db, g["unit"], 0, g["elements"]), pos + Vector2(w + 5, -1))
