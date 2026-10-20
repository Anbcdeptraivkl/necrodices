class_name TraceStep
extends RefCounted
## One step of the ScoreTrace (GAME_SPEC §5.4): the contract between scoring and playback.
## Presentation renders these verbatim and never re-evaluates a rule.

enum Kind { GROUP_BASE, FACE_MOD, RELIC, BOSS, TOTAL }

var kind: Kind
var group_index := -1
var source_id := ""
var op := "none"   # add_p / add_c / mul_p / mul_c / none (spec names)
var value := 0.0
var p_after := 0.0
var c_after := 0.0
var label := ""


static func make(p_kind: Kind, gi: int, src: String, p_op: String, v: float, p: float, c: float, text: String) -> TraceStep:
	var s := TraceStep.new()
	s.kind = p_kind
	s.group_index = gi
	s.source_id = src
	s.op = p_op
	s.value = v
	s.p_after = p
	s.c_after = c
	s.label = text
	return s


func to_dict() -> Dictionary:
	return {"kind": kind, "group_index": group_index, "source_id": source_id, "op": op,
		"value": value, "p_after": p_after, "c_after": c_after, "label": label}
