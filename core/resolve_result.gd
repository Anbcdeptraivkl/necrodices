class_name ResolveResult
extends RefCounted
## Output of Scorer.resolve (GAME_SPEC §5.2): the army's raw sum, the damage after RESOLVE
## trinkets, each squad's share of that damage (for the charge playback) and the trace.

var army := 0.0
var damage := 0.0
var shares: Array[float] = []
var trace: Array[TraceStep] = []
