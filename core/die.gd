class_name Die
extends RefCounted
## A die with 6 faces, one per element in canonical order (GAME_SPEC D-03, D-04): BONE is 6
## points, the other five carry 1..5 in a per-die shuffled order. Potions rewrite faces; the
## rolled top face lives in the battle state, not here.

const FACE_COUNT := 6

var faces: Array[Face] = []


## A fresh die: points 1..5 shuffled over the five non-BONE elements (`rng` = the DICE stream).
static func random(rng: RandomNumberGenerator) -> Die:
	var points := [1, 2, 3, 4, 5]
	for i in range(points.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = points[i]
		points[i] = points[j]
		points[j] = t
	var die := Die.new()
	for k in RulesRegistry.ELEMENTS.size():
		var e := RulesRegistry.ELEMENTS[k]
		die.faces.append(Face.new(e, Face.BONE_POINTS if k == 0 else points[k - 1]))
	return die


## Test helper / fixed layout: FIRE 1, ICE 2, LEAF 3, VOLT 4, METAL 5.
static func standard() -> Die:
	var die := Die.new()
	for k in RulesRegistry.ELEMENTS.size():
		die.faces.append(Face.new(RulesRegistry.ELEMENTS[k], Face.BONE_POINTS if k == 0 else k))
	return die


func face_of(element: String) -> int:
	for k in faces.size():
		if faces[k].element == element:
			return k
	return -1


func copy() -> Die:
	var die := Die.new()
	for f in faces:
		die.faces.append(f.copy())
	return die


func to_dict() -> Array:
	var out: Array = []
	for f in faces:
		out.append(f.to_dict())
	return out


static func from_dict(data: Array) -> Die:
	var die := Die.new()
	for d: Dictionary in data:
		die.faces.append(Face.from_dict(d))
	return die
