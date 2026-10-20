extends SceneTree
## Headless balance simulation (GAME_SPEC §5.6, Appendix A/B).
##   godot --headless --path . --script res://tools/balance_sim.gd -- --mode=baseline --trials=20000
##   godot --headless --path . --script res://tools/balance_sim.gd -- --mode=runs --trials=1000
## Entry point: tools\balance_sim.cmd. Prints a one-line summary first (diffable between commits).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var db := ContentDb.new()
	if not db.load_all():
		printerr("data errors: %s" % [db.errors])
		quit(1)
		return
	var trials := int(args.get("trials", "2000"))
	var seed: String = args.get("seed", "SIM")
	match args.get("mode", "baseline"):
		"baseline":
			print(BalanceSimStats.baseline(db, trials, seed))
		"runs":
			print(BalanceSimStats.runs(db, trials, seed))
		_:
			printerr("unknown mode")
			quit(1)
			return
	quit(0)
