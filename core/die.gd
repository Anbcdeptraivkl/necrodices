class_name Die
extends RefCounted
## A die with 6 faces (GAME_SPEC D-04). Faces are mutable by Sigils / Inks; the rolled top
## face lives in the encounter tray, not here.

const FACE_COUNT := 6

var faces: Array[Face] = []


static func standard() -> Die:
	var die := Die.new()
	for element: String in RulesRegistry.ELEMENTS:
		die.faces.append(Face.new(element))
	return die


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
