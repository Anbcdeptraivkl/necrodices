class_name Economy
extends RefCounted
## Money and HP math (GAME_SPEC §4.8, §6.12, §6.13) — one function per table, tested line by line.


## Hunter HP: night base × role multiplier. A boss uses the product of its rules' multipliers
## (each rule's multiplier prices in how much it weakens the army) — DECISIONS D-G02.
static func hp_for(db: ContentDb, night: int, role: String, rules: Array) -> float:
	var base: float = db.curve["night_base"][night - 1]
	var mult: float = db.curve["role_mult"][role]
	if role == "BOSS" and not rules.is_empty():
		mult = 1.0
		for r: String in rules:
			mult *= float(db.boss_rules[r]["hp_mult"])
	return roundf(base * mult)


## Interest on money held before the payout: $amount per $per, capped (gear raises the cap).
static func interest(db: ContentDb, run: RunState, money_before: int) -> int:
	var e := db.economy
	var cap := int(e["interest_cap"]) + run.equipment_bonus("interest_cap", db)
	return mini(int(money_before / int(e["interest_per"])) * int(e["interest_amount"]), cap)


## The hunter's bounty: by role, the Night 8 boss pays `reward_final`.
static func bounty(db: ContentDb, run: RunState, role: String) -> int:
	if role == "BOSS" and run.night >= int(db.curve["nights"]):
		return int(db.economy["reward_final"])
	return int(db.economy["reward_" + role.to_lower()])


## Spoils lines after a won battle (§4.8): [{key, amount, source}] — the overlay shows and
## sums exactly these. Order: bounty, unused summons, interest, Gilded faces, SPOILS trinkets.
static func spoils_lines(db: ContentDb, run: RunState, enc: EncounterState) -> Array[Dictionary]:
	var e := db.economy
	var role: String = enc.entry["role"]
	var lines: Array[Dictionary] = []
	lines.append({"key": "spoils_bounty", "amount": bounty(db, run, role), "source": role})
	if enc.summons_left > 0:
		lines.append({"key": "spoils_unused_summons", "amount": enc.summons_left * int(e["unused_summon_bonus"]),
			"source": str(enc.summons_left)})
	var interest_amount := interest(db, run, run.money)
	if interest_amount > 0:
		lines.append({"key": "spoils_interest", "amount": interest_amount, "source": ""})
	if enc.gilded > 0:
		lines.append({"key": "spoils_gilded", "amount": enc.gilded * int(e["runes"]["GILDED"]["money"]),
			"source": str(enc.gilded)})
	var ctx := ScoreCtx.new()
	ctx.money = run.money
	ctx.bosses_defeated = run.bosses_defeated
	for r in run.relics:
		for block: Dictionary in RulesRegistry.relic_blocks(db.relics[r.id]):
			if block["trigger"] != "SPOILS" or not RelicEval.cond(block["cond"], ctx):
				continue
			for effect: Dictionary in block["effects"]:
				lines.append({"key": "spoils_trinket", "amount": int(RelicEval.value(effect["value"], r.counter, ctx)),
					"source": r.id})
	return lines


static func total(lines: Array[Dictionary]) -> int:
	var sum := 0
	for line in lines:
		sum += int(line["amount"])
	return sum


static func sell_price_relic(db: ContentDb, id: String) -> int:
	return maxi(1, int(db.relics[id]["price"]) / int(db.economy["sell_relic_divisor"]))


static func sell_price_consumable(db: ContentDb) -> int:
	return int(db.economy["sell_consumable"])


## Market price of a die: base, plus the rune price when one of its faces carries a rune.
static func die_price(db: ContentDb, die: Die) -> int:
	var price := int(db.economy["die_price"])
	for f in die.faces:
		if f.rune != "":
			return price + int(db.economy["die_rune_price"])
	return price
