class_name Face
extends RefCounted
## One die face (GAME_SPEC D-03, D-04): an element, its points and at most one rune.
## BONE faces are always worth 6 points; the other elements carry 1..max_points.

const BONE_POINTS := 6

var element: String
var points: int
var rune: String  # "" = none; else one of RulesRegistry.RUNES


func _init(p_element: String = "BONE", p_points: int = BONE_POINTS, p_rune: String = "") -> void:
	element = p_element
	points = BONE_POINTS if p_element == "BONE" else p_points
	rune = p_rune


func copy() -> Face:
	return Face.new(element, points, rune)


func is_wild() -> bool:
	return rune == "WILD"


## TOMB faces have no element and no points (they always score their rune).
func is_tomb() -> bool:
	return rune == "TOMB"


## Element potions (§6.6): BONE becomes 6 points; a former BONE face drops to `former_bone`.
func set_element(e: String, former_bone: int) -> void:
	if e == "BONE":
		points = BONE_POINTS
	elif element == "BONE":
		points = former_bone
	element = e


func to_dict() -> Dictionary:
	return {"e": element, "p": points, "r": rune}


static func from_dict(d: Dictionary) -> Face:
	return Face.new(d["e"], d["p"], d["r"])
