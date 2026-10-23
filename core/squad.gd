class_name Squad
extends RefCounted
## One summon (GAME_SPEC §2, §4.3–§4.5): the picked dice in pick order (face copies taken at
## summon time), the combo they form with WILD resolved, which of them score, the held dice,
## the luck rolled for it, its unit and — once scored — its result and commit events.
## Positions ("k") index the picked list; `dice` maps them to tray indices.

var combo := ""
var unit_id := ""
var unit_elements: PackedStringArray = []  # Wisp tint (two elements) or the unit's elements
var dice: PackedInt32Array = []            # tray index per picked position
var faces: Array[Face] = []                # copies, pick order
var elements: PackedStringArray = []       # resolved element per position ("" = TOMB)
var scored: PackedInt32Array = []          # positions that score, pick order
var held: PackedInt32Array = []            # tray indices of the dice not picked
var held_faces: Array[Face] = []
## position -> {"count": bool, "money": bool} for LUCKY faces (rolled in the SUMMON command).
var luck := {}
var result: ScoreResult
var money := 0                              # earned at commit (SUMMON trinkets, lucky money)
var broken: PackedInt32Array = []          # tray indices whose GLASS rune shattered


func scored_count(element: String) -> int:
	var n := 0
	for k in scored:
		if elements[k] == element:
			n += 1
	return n


func has_element(element: String) -> bool:
	return scored_count(element) > 0


func held_count(element: String) -> int:
	var n := 0
	for f in held_faces:
		if not f.is_tomb() and f.element == element:
			n += 1
	return n


## Elements of the scored dice (TOMB excluded), for the battle's element tally.
func scored_elements() -> PackedStringArray:
	var out: PackedStringArray = []
	for k in scored:
		if elements[k] != "" and not out.has(elements[k]):
			out.append(elements[k])
	return out


func strength() -> float:
	return result.strength if result != null else 0.0
