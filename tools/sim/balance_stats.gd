class_name BalanceSimStats
extends RefCounted
## Balance statistics over the SimBot (GAME_SPEC §5.6 Appendix A, §13 M7 Appendix B).
## Used by tools/balance_sim.gd (headless runner) and tests/test_sim.gd.


## Appendix A: 4 standard dice, 3 summons, no rerolls / relics, levels 1.
static func baseline(db: ContentDb, trials: int, seed: String) -> Dictionary:
	var bot := SimBot.new(db)
	var damages: Array[float] = []
	var groups := 0
	for t in trials:
		var run := RunFlow.new_run(db, "%s%d" % [seed, t])
		var enc := RunFlow.start_encounter(db, run)
		enc.begin()
		damages.append(bot.play_baseline_encounter(enc))
		groups += enc.army.size()
	damages.sort()
	var total := 0.0
	for d in damages:
		total += d
	return {"mean": roundf(total / trials), "median": damages[trials / 2],
		"p10": damages[trials / 10], "p90": damages[trials * 9 / 10],
		"groups_per_encounter": snappedf(float(groups) / trials, 0.01)}


## Appendix B: whole runs with the shop / attack policy.
static func runs(db: ContentDb, trials: int, seed: String) -> Dictionary:
	var bot := SimBot.new(db)
	var nights := {}
	var won := 0
	var reach4 := 0
	var deaths := {}
	var ratio_sum := {}
	var ratio_n := {}
	var relics := 0
	for t in trials:
		var r := bot.play_run("%s%d" % [seed, t])
		nights[r["night"]] = nights.get(r["night"], 0) + 1
		deaths[r["died"]] = deaths.get(r["died"], 0) + 1
		relics += r["relics"]
		for n: int in r["ratios"]:
			for v: float in r["ratios"][n]:
				ratio_sum[n] = ratio_sum.get(n, 0.0) + v
				ratio_n[n] = ratio_n.get(n, 0) + 1
		if r["won"]:
			won += 1
		if r["night"] >= 4:
			reach4 += 1
	var ratios := {}
	for n: int in ratio_sum:
		ratios[n] = snappedf(ratio_sum[n] / ratio_n[n], 0.01)
	return {"runs": trials, "reach_night4": snappedf(float(reach4) / trials, 0.001),
		"win_rate": snappedf(float(won) / trials, 0.001), "night_reached": nights, "deaths": deaths,
		"mean_damage_over_hp": ratios, "relics_at_end": snappedf(float(relics) / trials, 0.1)}
