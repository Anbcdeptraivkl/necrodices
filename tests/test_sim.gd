extends TestSuite
## The balance bot plays through the real commands without errors, and the Night 1 Mob stays
## beatable with the starting dice (GAME_SPEC §12). Numbers are tunable: this checks ranges.

const COVERS: Array[String] = ["core/combos.gd", "core/scorer.gd", "core/encounter_state.gd",
	"core/shop_state.gd", "tools/sim/", "data/"]


func test_baseline_night1() -> void:
	var r := BalanceSimStats.baseline(Fixtures.db(), 300, "REG")
	_check(r["mean"] > 0.0, "army deals damage")
	_check(r["night1_mob_win"] >= 0.8, "night 1 mob beatable (%s)" % r["night1_mob_win"])


func test_runs_complete() -> void:
	var r := BalanceSimStats.runs(Fixtures.db(), 20, "REGRUN")
	_eq(r["runs"], 20, "all runs ended")
	_check(r["reach_night4"] >= 0.0, "stats computed")
