class_name RelicInstance
extends RefCounted
## An owned relic: its id, its persistent counter (Overgrowth, §9.1) and whether a boss rule
## disabled it for the current encounter (Witch Hunter). Order in RunState.relics is the
## trigger order.

var id: String
var counter := 0
var disabled := false  # this encounter only; never saved


func _init(p_id: String = "", p_counter: int = 0) -> void:
	id = p_id
	counter = p_counter


func copy() -> RelicInstance:
	var r := RelicInstance.new(id, counter)
	r.disabled = disabled
	return r


func to_dict() -> Dictionary:
	return {"id": id, "counter": counter}


static func from_dict(d: Dictionary) -> RelicInstance:
	return RelicInstance.new(d["id"], d["counter"])
