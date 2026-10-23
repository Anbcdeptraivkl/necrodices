class_name Art
extends RefCounted
## Texture lookup for every asset in the ART_SPEC §11 manifest, by game id, with a cache.
## Frames of a sheet come back as AtlasTextures. The Wisp mask (§4.3) is palette-swapped once
## per element pair on the CPU and cached, so UI and the horde need no swap shader.

const PALETTE := {
	"N0": Color("#0d0a14"), "N1": Color("#1a1326"), "N2": Color("#281d3b"), "N3": Color("#3b2c55"),
	"N4": Color("#574577"), "N5": Color("#8577a3"), "N6": Color("#c4bad8"), "N7": Color("#f4efe4"),
	"B0": Color("#7b6a52"), "B1": Color("#bba783"), "B2": Color("#e9ddbf"),
	"F0": Color("#b33a10"), "F1": Color("#f2781c"), "F2": Color("#ffc85a"),
	"I0": Color("#23589c"), "I1": Color("#4fb6ea"), "I2": Color("#c6f1ff"),
	"L0": Color("#1f6136"), "L1": Color("#49b23f"), "L2": Color("#b4ec6a"),
	"V0": Color("#7d7a12"), "V1": Color("#e3df34"), "V2": Color("#fbfaa6"),
	"M0": Color("#4f5b66"), "M1": Color("#93a3ae"), "M2": Color("#dfe8ec"),
	"R0": Color("#8c1c34"), "R1": Color("#e0344a"), "G0": Color("#c98a17"), "G1": Color("#ffe066"),
	"S0": Color("#a8643c"), "S1": Color("#f0b896"), "K0": Color("#000000"),
}
const ELEMENT_RAMP := {"BONE": "B", "FIRE": "F", "ICE": "I", "LEAF": "L", "VOLT": "V", "METAL": "M"}
const MASK_KEYS := {
	Color("#ff0000"): 0, Color("#ff6060"): 1, Color("#ffc0c0"): 2,
	Color("#0000ff"): 3, Color("#6060ff"): 4, Color("#c0c0ff"): 5,
}

static var _cache := {}


## A 1 px rectangle outline on whole pixels (draw_rect with filled = false lands on half pixels).
static func draw_ring(item: CanvasItem, r: Rect2, c: Color) -> void:
	item.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), c)
	item.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), c)
	item.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), c)
	item.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 0), Vector2(1, r.size.y)), c)


static func colour(key: String) -> Color:
	return PALETTE[key]


static func element_colour(element: String, step: int = 1) -> Color:
	return PALETTE["%s%d" % [ELEMENT_RAMP[element], step]]


static func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		var t: Texture2D = load(path)
		if t == null:
			push_error("missing texture %s" % path)
		_cache[path] = t
	return _cache[path]


static func frame(path: String, frame_w: int, index: int) -> Texture2D:
	var key := "%s#%d" % [path, index]
	if not _cache.has(key):
		var base := tex(path)
		var a := AtlasTexture.new()
		a.atlas = base
		a.region = Rect2(index * frame_w, 0, frame_w, base.get_height())
		_cache[key] = a
	return _cache[key]


## Unit sprite frame: 16×16, or 32×32 for Quintet legends (the frame is as wide as the sheet
## is tall). WISP needs its two elements for the swap.
static func unit(unit_id: String, index: int = 0, elements: PackedStringArray = []) -> Texture2D:
	if unit_id == "WISP":
		return _wisp(elements, index, "res://assets/sprites/units/wisp_mask.png", 16)
	var path := "res://assets/sprites/units/%s.png" % unit_id.to_lower()
	return frame(path, tex(path).get_height(), index)


## Crowd mini (8×8) for a horde unit: its `mini` element (§4.4).
static func mini(db: ContentDb, unit_id: String, index: int = 0, elements: PackedStringArray = []) -> Texture2D:
	if unit_id == "WISP":
		return _wisp(elements, index, "res://assets/sprites/minis/mini_wisp_mask.png", 8)
	var element: String = db.units[unit_id].get("mini", "bone")
	return frame("res://assets/sprites/minis/mini_%s.png" % element, 8, index)


static func enemy(enemy_id: String, index: int = 0) -> Texture2D:
	return frame("res://assets/sprites/enemies/%s.png" % enemy_id.to_lower(), 32, index)


static func shopkeeper(index: int = 0) -> Texture2D:
	return frame("res://assets/sprites/enemies/shopkeeper_undertaker.png", 32, index)


static func glyph(element: String, small: bool = false) -> Texture2D:
	return tex("res://assets/sprites/dice/%s_%s.png" % ["glyph8" if small else "glyph", element.to_lower()])


## Glyph shown on a face: TOMB faces show none (the tomb body carries the cross).
static func face_glyph(face: Face, small: bool = false) -> Texture2D:
	if face.is_tomb():
		return null
	return glyph(face.element, small)


static func pip(element: String) -> Texture2D:
	return tex("res://assets/sprites/dice/pip_%s.png" % element.to_lower())


## Die body for the face showing: its rune's material, or plain bone.
static func die_body(face: Face) -> Texture2D:
	if face == null or face.rune == "":
		return dice("die_body")
	return dice("die_body_" + face.rune.to_lower())


static func face_tile(face: Face) -> Texture2D:
	if face == null or face.rune == "":
		return dice("face_tile")
	return dice("face_tile_" + face.rune.to_lower())


## Points badge (7×9); TOMB faces have none.
static func points_badge(face: Face) -> Texture2D:
	if face == null or face.is_tomb():
		return null
	return dice("num_%d" % clampi(face.points, 1, 9))


static func dice(name: String) -> Texture2D:
	return tex("res://assets/sprites/dice/%s.png" % name)


static func relic(id: String) -> Texture2D:
	return tex("res://assets/icons/relics/%s.png" % id.to_lower())


static func consumable(id: String) -> Texture2D:
	return tex("res://assets/icons/consumables/%s.png" % id.to_lower())


static func coffer(id: String) -> Texture2D:
	return tex("res://assets/icons/coffers/%s.png" % id.to_lower())


static func equipment(id: String) -> Texture2D:
	return tex("res://assets/icons/equipment/%s.png" % id.to_lower())


static func stat(name: String) -> Texture2D:
	return tex("res://assets/icons/stats/%s.png" % name)


static func ui(name: String) -> Texture2D:
	return tex("res://assets/ui/%s.png" % name)


static func vfx(name: String, frame_w: int = 0, index: int = 0) -> Texture2D:
	var path := "res://assets/vfx/%s.png" % name
	return tex(path) if frame_w == 0 else frame(path, frame_w, index)


static func bg(name: String) -> Texture2D:
	return tex("res://assets/bg/%s.png" % name)


## Palette swap of a mask sheet frame: A ramp ← first element, C ramp ← second (§4.3).
static func _wisp(elements: PackedStringArray, index: int, path: String, frame_w: int) -> Texture2D:
	var sorted := Array(elements)
	sorted.sort_custom(func(x: String, y: String) -> bool:
		return RulesRegistry.ELEMENTS.find(x) < RulesRegistry.ELEMENTS.find(y))
	var a: String = sorted[0] if sorted.size() > 0 else "BONE"
	var b: String = sorted[1] if sorted.size() > 1 else a
	var key := "%s#%s+%s#%d" % [path, a, b, index]
	if _cache.has(key):
		return _cache[key]
	var img := tex(path).get_image()
	img = img.get_region(Rect2i(index * frame_w, 0, frame_w, img.get_height()))
	var targets: Array[Color] = [element_colour(a, 0), element_colour(a, 1), element_colour(a, 2),
		element_colour(b, 0), element_colour(b, 1), element_colour(b, 2)]
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var opaque := Color(c.r, c.g, c.b, 1.0)
			for k: Color in MASK_KEYS:
				if opaque.is_equal_approx(k):
					img.set_pixel(x, y, targets[MASK_KEYS[k]])
					break
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t
