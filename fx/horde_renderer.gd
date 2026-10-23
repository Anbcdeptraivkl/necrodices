class_name HordeRenderer
extends Node2D
## Draws the army on the battlefield (GAME_SPEC §11): one column per squad, left → right.
## Horde squads show their Count as soldiers (linear to 12, log beyond, cap 40); render tiers
## by total visible (≤60 full 16×16 sprites, ≤240 8×8 minis, else 240 minis + LEGION banners).
## Single units (Elite / Ritual / Parade) and 32×32 legends show one body whose aura grows with
## Count (tiers at 10 / 40 / 160: glow ring, + flame crown, + bigger flames). Jitter is seeded
## by squad index (never the game RNG); idle bob ±1 px at 1.5 Hz.
## Sprite pools are allocated once; nothing is instantiated during playback.
## Pure view: it shows counts it is given and never reads the model.

const POOL := 260
const AURA_POOL := 8
const FULL_LIMIT := 60
const MINI_LIMIT := 240
const BOB_HZ := 1.5
const IDLE_FPS := 3.0
const AURA_TIERS: Array[float] = [10.0, 40.0, 160.0]

var db: ContentDb
var area := Vector2(224, 140)
## Per squad: {unit, elements, count (true), display, visible, highlight}
var groups: Array[Dictionary] = []
var reduce_motion := false

var _sprites: Array[Sprite2D] = []
var _auras: Array[Sprite2D] = []
var _flames: Array[Sprite2D] = []
var _assign: Array = []          # squad index -> Array[int] sprite indices
var _base_pos: PackedVector2Array = []
var _phase: PackedFloat32Array = []
var _sprite_group: PackedInt32Array = []
var _tier := 0                   # 0 full, 1 minis, 2 legion
var _time := 0.0
var _font: Font
var _lunging := false
var _badges: Node2D


func _ready() -> void:
	_font = load("res://assets/fonts/fusion_pixel/fusion_pixel_8px.otf")
	for i in AURA_POOL:
		_auras.append(_new_sprite(true))
		_flames.append(_new_sprite(true))
	for i in POOL:
		_sprites.append(_new_sprite(false))
	# Count badges draw on a child added last, above the auras and the units (z_index would
	# also sink below the screen background).
	_badges = Node2D.new()
	_badges.draw.connect(_draw_badges)
	add_child(_badges)
	_base_pos.resize(POOL)
	_phase.resize(POOL)
	_sprite_group.resize(POOL)


func _new_sprite(is_centered: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = is_centered
	s.visible = false
	add_child(s)
	return s


## GAME_SPEC §11 (horde squads)
static func visible_for(count: float) -> int:
	if count <= 0.0:
		return 0
	if count <= 12.0:
		return int(ceilf(count))
	return mini(12 + int(floor(6.0 * log(count / 12.0) / log(2.0))), 40)


static func aura_tier(count: float) -> int:
	var t := 0
	for threshold in AURA_TIERS:
		if count >= threshold:
			t += 1
	return t


func clear_army() -> void:
	groups.clear()
	_relayout()


func add_group(unit_id: String, elements: PackedStringArray, count: float) -> Array[Sprite2D]:
	groups.append({"unit": unit_id, "elements": elements, "count": count, "display": db.display_of(unit_id),
		"visible": 0, "highlight": false})
	return _relayout()


## Sets one squad's true Count; returns the sprites that just appeared (for a pop tween).
func set_count(gi: int, count: float) -> Array[Sprite2D]:
	groups[gi]["count"] = count
	return _relayout()


func relayout() -> void:
	_relayout()


func set_highlight(gi: int, on: bool) -> void:
	for g in groups:
		g["highlight"] = false
	if gi >= 0 and gi < groups.size():
		groups[gi]["highlight"] = on
	_redraw_badges()


func group_sprites(gi: int) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	if gi < _assign.size():
		for i: int in _assign[gi]:
			out.append(_sprites[i])
	return out


## The aura and flame sprites of a single / legend squad (empty for hordes).
func group_auras(gi: int) -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	if gi < AURA_POOL and gi < groups.size() and groups[gi]["display"] != "horde":
		for s in [_auras[gi], _flames[gi]]:
			if s.visible:
				out.append(s)
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
	_relayout()


func _relayout() -> Array[Sprite2D]:
	var before := {}
	for s in _sprites:
		if s.visible:
			before[s] = true
	var counts: Array[int] = []
	var total := 0
	for g in groups:
		var v := visible_for(g["count"]) if g["display"] == "horde" else 1
		counts.append(v)
		total += v
	_tier = 0 if total <= FULL_LIMIT else (1 if total <= MINI_LIMIT else 2)
	if _tier == 2:
		counts = _scale_counts(counts, MINI_LIMIT)
	_assign.clear()
	var next := 0
	var columns := _columns(counts)
	for gi in groups.size():
		var ids: Array[int] = []
		if groups[gi]["display"] == "horde":
			next = _place_horde(gi, counts[gi], columns[gi], next, ids)
		elif next < POOL:
			_place_single(gi, columns[gi], next)
			ids.append(next)
			next += 1
		_assign.append(ids)
		groups[gi]["visible"] = counts[gi]
	for i in range(next, POOL):
		_sprites[i].visible = false
	_place_auras()
	_redraw_badges()
	var appeared: Array[Sprite2D] = []
	for i in next:
		if not before.has(_sprites[i]):
			appeared.append(_sprites[i])
	return appeared


func _place_horde(gi: int, n: int, col: Rect2, next: int, ids: Array[int]) -> int:
	var cell := Vector2(11, 12) if _tier == 0 else Vector2(7, 7)
	var sprite_size := 16 if _tier == 0 else 8
	var per_row := maxi(1, int(col.size.x / cell.x))
	var rng := RandomNumberGenerator.new()
	rng.seed = gi * 7919 + 13
	for k in n:
		if next >= POOL:
			break
		var row := k / per_row
		var c := k % per_row
		var x := col.position.x + c * cell.x + rng.randi_range(-1, 1) + (row % 2) * floorf(cell.x / 2.0)
		var y := area.y - sprite_size - row * cell.y + rng.randi_range(-1, 1)
		_place(next, gi, Vector2(roundf(x), roundf(maxf(12.0, y))))
		ids.append(next)
		next += 1
	return next


func _place_single(gi: int, col: Rect2, i: int) -> void:
	var h := 32.0 if groups[gi]["display"] == "legend" else 16.0
	var x := col.position.x + floorf((col.size.x - h) / 2.0)
	_place(i, gi, Vector2(roundf(x), area.y - h - 2.0))


## Aura ring + flame crown behind each single / legend squad, by aura tier.
func _place_auras() -> void:
	for gi in AURA_POOL:
		var aura := _auras[gi]
		var flame := _flames[gi]
		aura.visible = false
		flame.visible = false
		if gi >= groups.size() or groups[gi]["display"] == "horde" or gi >= _assign.size() or _assign[gi].is_empty():
			continue
		var tier := aura_tier(groups[gi]["count"])
		var body := _sprites[_assign[gi][0]]
		var size := body.texture.get_size() if body.texture != null else Vector2(16, 16)
		var centre := (_base_pos[_assign[gi][0]] + size / 2.0).round()
		var tint := _tint(groups[gi])
		aura.position = centre
		flame.position = centre - Vector2(0, roundf(size.y / 4.0))
		aura.modulate = tint
		flame.modulate = tint
		aura.visible = tier >= 1
		flame.visible = tier >= 2
		flame.scale = Vector2.ONE * (2.0 if tier >= 3 else 1.0)


func _tint(g: Dictionary) -> Color:
	var els: PackedStringArray = g["elements"]
	if els.is_empty():
		return Art.colour("N6")
	return Art.element_colour(els[0], 2)


func _place(i: int, gi: int, pos: Vector2) -> void:
	var s := _sprites[i]
	s.texture = _texture(groups[gi], 0)
	s.position = pos
	s.visible = true
	_base_pos[i] = pos
	_sprite_group[i] = gi
	_phase[i] = fmod(float(i) * 0.37, 1.0)


func _texture(g: Dictionary, f: int) -> Texture2D:
	if _tier == 0 or g["display"] != "horde":
		return Art.unit(g["unit"], f, g["elements"])
	return Art.mini(db, g["unit"], f, g["elements"])


## Column rects: horde widths proportional to sqrt(visible); singles 20 px, legends 36 px;
## the set is centred when it does not fill the field.
func _columns(counts: Array[int]) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var fixed := 0.0
	var weight := 0.0
	for gi in counts.size():
		match groups[gi]["display"]:
			"legend":
				fixed += 36.0
			"single":
				fixed += 20.0
			_:
				weight += maxf(1.0, sqrt(counts[gi]))
	var x := 2.0
	var usable := maxf(0.0, area.x - 4.0 - fixed)
	var hordes := counts.size() - _non_horde_count()
	if hordes == 0 or weight < 4.0 * hordes:
		usable = minf(usable, 40.0 * hordes)
		x = floorf((area.x - usable - fixed) / 2.0)
	for gi in counts.size():
		var w: float
		match groups[gi]["display"]:
			"legend":
				w = 36.0
			"single":
				w = 20.0
			_:
				w = maxf(13.0, floorf(usable * maxf(1.0, sqrt(counts[gi])) / maxf(1.0, weight)))
		out.append(Rect2(x, 0, w - 2.0, area.y))
		x += w
	return out


func _redraw_badges() -> void:
	if _badges != null:
		_badges.queue_redraw()


func _non_horde_count() -> int:
	var n := 0
	for g in groups:
		if g["display"] != "horde":
			n += 1
	return n


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
	var af := int(_time * 8.0) % 4
	for gi in AURA_POOL:
		if _auras[gi].visible:
			_auras[gi].texture = Art.vfx("aura", 40, af)
		if _flames[gi].visible:
			_flames[gi].texture = Art.vfx("flame", 32, af)


func _draw_badges() -> void:
	for gi in groups.size():
		var ids: Array = _assign[gi] if gi < _assign.size() else []
		if ids.is_empty():
			continue
		var min_x := INF
		var max_x := -INF
		var min_y := INF
		var w_sprite := 0.0
		for i: int in ids:
			min_x = minf(min_x, _base_pos[i].x)
			max_x = maxf(max_x, _base_pos[i].x)
			min_y = minf(min_y, _base_pos[i].y)
			w_sprite = _sprites[i].texture.get_width() if _sprites[i].texture != null else 16.0
		var g := groups[gi]
		var text := NumberFormat.format(g["count"])
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4
		var cx := roundf((min_x + max_x + w_sprite) / 2.0)
		var pos := Vector2(roundf(cx - w / 2.0), maxf(0.0, min_y - 11))
		var bg := Art.colour("G1") if g["highlight"] else Art.colour("N0")
		_badges.draw_rect(Rect2(pos, Vector2(w, 10)), bg)
		_badges.draw_string(_font, pos + Vector2(2, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
			Art.colour("N0") if g["highlight"] else Art.colour("R1"))
		if _tier == 2 and g["display"] == "horde":
			var banner := Art.tex("res://assets/sprites/units/legion_banner.png")
			_badges.draw_texture(banner, pos + Vector2(w + 1, -3))
			_badges.draw_texture(Art.mini(db, g["unit"], 0, g["elements"]), pos + Vector2(w + 5, -1))
