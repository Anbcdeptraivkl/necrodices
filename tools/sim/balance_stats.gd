class_name BalanceSimStats
extends RefCounted
## Balance statistics over the SimBot (GAME_SPEC §12). Used by tools/balance_sim.gd (headless
## runner) and tests/test_sim.gd.


## Night 1 Mob with the starting dice and no market: army damage distribution and win rate.
static func baseline(db: ContentDb, trials: int, seed: String) -> Dictionary:
	var bot := SimBot.new(db)
	var damages: Array[float] = []
	var wins := 0
	var squads := 0
	for t in trials:
		var run := RunFlow.new_run(db, "%s%d" % [seed, t])
		run.night_plan[0]["hp"] = 1.0e12  # play all three summons to measure the full army
		var enc := RunFlow.start_encounter(db, run)
		enc.begin()
		bot.play_encounter(enc)
		damages.append(enc.resolution.damage)
		squads += enc.squads.size()
		if enc.resolution.damage >= Economy.hp_for(db, 1, "MOB", []):
			wins += 1
	damages.sort()
	var total := 0.0
	for d in damages:
		total += d
	return {"mean": roundf(total / trials), "median": damages[trials / 2],
		"p10": damages[trials / 10], "p90": damages[trials * 9 / 10],
		"night1_mob_win": snappedf(float(wins) / trials, 0.001), "combos": bot.combo_tally}


## Whole runs with the market policy.
static func runs(db: ContentDb, trials: int, seed: String) -> Dictionary:
	var bot := SimBot.new(db)
	var nights := {}
	var won := 0
	var reach4 := 0
	var deaths := {}
	var ratio_sum := {}
	var ratio_n := {}
	var relics := 0
	var dice := 0
	for t in trials:
		var r := bot.play_run("%s%d" % [seed, t])
		nights[r["night"]] = nights.get(r["night"], 0) + 1
		deaths[r["died"]] = deaths.get(r["died"], 0) + 1
		relics += r["relics"]
		dice += r["dice"]
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
		"mean_damage_over_hp": ratios, "relics_at_end": snappedf(float(relics) / trials, 0.1),
		"dice_at_end": snappedf(float(dice) / trials, 0.1)}
