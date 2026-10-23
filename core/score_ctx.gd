class_name ScoreCtx
extends RefCounted
## Facts the trinket conditions and value sources read (GAME_SPEC §9.1), built once before a
## squad (or the resolve) is scored, plus the running Power / Count. Never reads nodes or the
## live run: the battle state fills it.

var money := 0
var rerolls_left := 0
var summons_left := 0            # after the squad being scored
var squads_before := 0           # squads summoned earlier this battle
var bosses_defeated := 0
var seen_units := {}             # unit ids of earlier squads this battle
var battle_elements := {}        # elements scored by earlier squads this battle
var squad: Squad                 # null while resolving
var p := 0.0
var c := 0.0


func source(name: String, counter: int) -> float:
	if name.begins_with("scored:"):
		return squad.scored_count(name.trim_prefix("scored:")) if squad != null else 0.0
	if name.begins_with("held:"):
		return squad.held_count(name.trim_prefix("held:")) if squad != null else 0.0
	match name:
		"money": return money
		"rerolls_left": return rerolls_left
		"summons_left": return summons_left
		"squads_before": return squads_before
		"bosses_defeated": return bosses_defeated
		"counter": return counter
		"scored_dice": return squad.scored.size() if squad != null else 0.0
	push_error("unknown value source %s" % name)
	return 0.0


## Distinct elements scored this battle, including the squad being scored.
func distinct_elements() -> int:
	var all := battle_elements.duplicate()
	if squad != null:
		for e in squad.scored_elements():
			all[e] = true
	return all.size()
