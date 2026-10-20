class_name Group
extends RefCounted
## A bound or summoned unit stack (GAME_SPEC §2): the faces it was made from (copied at bind
## time, tray order), the elements they resolved to (WILD resolved, §5.2) and its unit.

var unit_id: String
var faces: Array[Face] = []
var elements: PackedStringArray = []  # resolved, same order as faces
var die_indices: PackedInt32Array = []  # tray positions while pending
var summon_index := -1


func has_element(element: String) -> bool:
	return elements.has(element)


func copy() -> Group:
	var g := Group.new()
	g.unit_id = unit_id
	for f in faces:
		g.faces.append(f.copy())
	g.elements = elements.duplicate()
	g.die_indices = die_indices.duplicate()
	g.summon_index = summon_index
	return g


func to_dict() -> Dictionary:
	var fs: Array = []
	for f in faces:
		fs.append(f.to_dict())
	return {"unit": unit_id, "faces": fs, "elements": Array(elements), "summon_index": summon_index}


static func from_dict(d: Dictionary) -> Group:
	var g := Group.new()
	g.unit_id = d["unit"]
	for fd: Dictionary in d["faces"]:
		g.faces.append(Face.from_dict(fd))
	g.elements = PackedStringArray(d["elements"])
	g.summon_index = d["summon_index"]
	return g
