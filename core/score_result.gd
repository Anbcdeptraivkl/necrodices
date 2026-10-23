class_name ScoreResult
extends RefCounted
## Output of Scorer.score_squad: strength = floor(P × C) plus the trace that explains it.

var power := 0.0
var count := 0.0
var strength := 0.0
var trace: Array[TraceStep] = []
