class_name TraceStep
extends RefCounted
## One step of a trace (GAME_SPEC §5.5): the contract between scoring and playback.
## Squad steps carry the running Power / Count; RESOLVE / TOTAL steps carry the running army
## damage in `p_after`. `die` is the tray index of the die the step is about (-1 = none).
## Presentation renders these verbatim and never re-evaluates a rule.

enum Kind { COMBO, DIE, RUNE, HELD, TRINKET, BOSS, STRENGTH, RESOLVE, TOTAL }

var kind: Kind
var die := -1
var source_id := ""
var op := "none"   # add_p / add_c / mul_p / mul_c / mul_d / add_d / none
var value := 0.0
var p_after := 0.0
var c_after := 0.0
var label := ""


static func make(p_kind: Kind, p_die: int, src: String, p_op: String, v: float, p: float, c: float, text: String) -> TraceStep:
	var s := TraceStep.new()
	s.kind = p_kind
	s.die = p_die
	s.source_id = src
	s.op = p_op
	s.value = v
	s.p_after = p
	s.c_after = c
	s.label = text
	return s


func to_dict() -> Dictionary:
	return {"kind": Kind.keys()[kind], "die": die, "source_id": source_id, "op": op, "value": value,
		"p_after": p_after, "c_after": c_after, "label": label}
