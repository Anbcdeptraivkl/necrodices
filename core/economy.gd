class_name Economy
extends RefCounted
## Money and HP math (GAME_SPEC §4.5, §6.10, §6.11) — one function per table, tested line by line.


## Enemy HP: night base × role multiplier. A boss uses the product of its rules' multipliers
## (each rule's multiplier prices in how much it weakens the army; Enraged multiplies its two
## rules by its own factor) — DECISIONS D-G02.
static func hp_for(db: ContentDb, night: int, role: String, rules: Array) -> float:
	var base: float = db.curve["night_base"][night - 1]
	var mult: float = db.curve["role_mult"][role]
	if role == "BOSS" and not rules.is_empty():
		mult = 1.0
		for r: String in rules:
			mult *= float(db.boss_rules[r]["hp_mult"])
	return roundf(base * mult)


## Interest on money held before the payout: $amount per $per, capped.
static func interest(db: ContentDb, money_before: int) -> int:
	var e := db.economy
	return mini(int(money_before / int(e["interest_per"])) * int(e["interest_amount"]), int(e["interest_cap"]))


## Cash-out lines after a won combat: [{key, amount, source}] — the screen shows and sums
## exactly these. FIGHT_END relics (Grave Robber) add one line each.
static func cash_out_lines(db: ContentDb, run: RunState, role: String, unused_summons: int) -> Array[Dictionary]:
	var e := db.economy
	var lines: Array[Dictionary] = []
	var no_army: Array[Group] = []
	lines.append({"key": "cashout_enemy_reward", "amount": int(e["reward_" + role.to_lower()]), "source": role})
	if unused_summons > 0:
		lines.append({"key": "cashout_unused_summons", "amount": unused_summons * int(e["unused_summon_bonus"]),
			"source": str(unused_summons)})
	var interest_amount := interest(db, run.money)
	if interest_amount > 0:
		lines.append({"key": "cashout_interest", "amount": interest_amount, "source": ""})
	for r in run.relics:
		for block: Dictionary in RulesRegistry.relic_blocks(db.relics[r.id]):
			if block["trigger"] != "FIGHT_END":
				continue
			var ctx := ScoreCtx.build(no_army, run.money, 0, unused_summons, run.bosses_defeated)
			if not RelicEval.cond(block["cond"], null, -1, ctx, db):
				continue
			for effect: Dictionary in block["effects"]:
				if effect["op"] == "add_money":
					lines.append({"key": "cashout_relics", "amount": int(RelicEval.value(effect["value"], r.counter, ctx)),
						"source": r.id})
	return lines


static func total(lines: Array[Dictionary]) -> int:
	var sum := 0
	for line in lines:
		sum += int(line["amount"])
	return sum


static func sell_price_relic(db: ContentDb, id: String) -> int:
	return int(db.relics[id]["price"]) / int(db.economy["sell_relic_divisor"])


static func sell_price_consumable(db: ContentDb) -> int:
	return int(db.economy["sell_consumable"])
