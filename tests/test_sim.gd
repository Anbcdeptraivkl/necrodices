extends TestSuite
## Statistical regression of recipes + scorer (GAME_SPEC §5.6): the Appendix A bot over a fixed
## seed must stay within ±6% of the reference (smaller sample than the 20k acceptance run).

const COVERS: Array[String] = ["core/recipes.gd", "core/scorer.gd", "core/encounter_state.gd",
	"tools/sim/", "data/units.json"]
const TRIALS := 3000


func test_baseline_distribution() -> void:
	var r := BalanceSimStats.baseline(Fixtures.db(), TRIALS, "REG")
	_check(absf(r["mean"] / 1590.0 - 1.0) <= 0.06, "mean %s ≈ 1590" % r["mean"])
	_check(absf(r["median"] / 1530.0 - 1.0) <= 0.06, "median %s ≈ 1530" % r["median"])
	_check(absf(r["groups_per_encounter"] / 5.2 - 1.0) <= 0.06, "groups %s ≈ 5.2" % r["groups_per_encounter"])
