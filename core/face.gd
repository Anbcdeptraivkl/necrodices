class_name Face
extends RefCounted
## One die face: an element and at most one modifier (GAME_SPEC §2, §4.9).

var element: String
var modifier: String  # "" = none; else one of RulesRegistry.MODIFIERS


func _init(p_element: String = "BONE", p_modifier: String = "") -> void:
	element = p_element
	modifier = p_modifier


func copy() -> Face:
	return Face.new(element, modifier)


func is_wild() -> bool:
	return modifier == "WILD"


func to_dict() -> Dictionary:
	return {"e": element, "m": modifier}


static func from_dict(d: Dictionary) -> Face:
	return Face.new(d["e"], d["m"])
