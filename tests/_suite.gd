class_name TestSuite
extends RefCounted
## Base of every tests/test_*.gd. A suite is a set of cases: methods named `test_*`, run in
## declaration order by tests/_run.gd, each reported on its own (PASS / FAIL with its time).
## Cases may await (the tree is running). `COVERS` (a const in each suite) lists the repo paths
## whose changes the suite checks, so `tools\test.cmd --changed` runs only the suites a working
## tree change can break; a change no suite covers is reported.

## The running tree, for cases that add scenes or wait frames.
var tree: SceneTree
var failures := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func _eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		_fail("%s: got %s, expected %s" % [msg, actual, expected])


func _fail(msg: String) -> void:
	failures += 1
	push_error(msg)
