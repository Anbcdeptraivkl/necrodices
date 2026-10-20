class_name ScoreResult
extends RefCounted
## Output of Scorer.score: damage = floor(P × C) plus the trace that explains it.

var damage := 0.0
var power := 0.0
var count := 0.0
var trace: Array[TraceStep] = []
