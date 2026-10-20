class_name SimBot
extends RefCounted
## Balance bots (GAME_SPEC §5.6 Appendix A, §13 M7 Appendix B). They play through the same
## EncounterState / ShopState / RunFlow commands the UI uses, so a bot result is evidence about
## the real rules (balance evidence only — never fun evidence).

var db: ContentDb


func _init(p_db: ContentDb) -> void:
	db = p_db


## Every set of disjoint valid groups over `free` tray indices: Array of Array[PackedInt32Array].
func partitions(enc: EncounterState, free: PackedInt32Array) -> Array:
	var out: Array = []
	_partitions(enc, free, [], out)
	return out


func _partitions(enc: EncounterState, avail: PackedInt32Array, cur: Array, out: Array) -> void:
	out.append(cur.duplicate())
	if avail.size() < 2:
		return
	var first := avail[0]
	var rest := avail.slice(1)
	for size in [2, 3]:
		for combo in _combinations(rest, size - 1):
			var idx := PackedInt32Array([first])
			idx.append_array(combo)
			var faces: Array[Face] = []
			for i in idx:
				faces.append(enc.face_at(i))
			if Recipes.can_bind(db, faces, enc.run.levels):
				var remaining := PackedInt32Array()
				for a in rest:
					if not combo.has(a):
						remaining.append(a)
				cur.append(idx)
				_partitions(enc, remaining, cur, out)
				cur.pop_back()
	_partitions(enc, rest, cur, out)


static func _combinations(items: PackedInt32Array, k: int) -> Array:
	var out: Array = []
	if k == 1:
		for i in items:
			out.append(PackedInt32Array([i]))
		return out
	for n in items.size():
		for tail in _combinations(items.slice(n + 1), k - 1):
			var c := PackedInt32Array([items[n]])
			c.append_array(tail)
			out.append(c)
	return out


func free_dice(enc: EncounterState) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in enc.tray_size:
		if enc.bound[i] == -1 and i != enc.shackled:
			out.append(i)
	return out


## Appendix A choice: the partition maximising cumulative P × C of base stats (no relics).
func best_partition_base(enc: EncounterState, p0: float, c0: float) -> Array:
	var best: Array = []
	var best_v := -1.0
	for part: Array in partitions(enc, free_dice(enc)):
		var p := p0
		var c := c0
		for idx: PackedInt32Array in part:
			var stats := _group_stats(enc, idx)
			p += stats.x
			c += stats.y
		if p * c > best_v:
			best_v = p * c
			best = part
	return best


## Appendix B choice: the partition with the highest projected damage (real scorer, relics on).
func best_partition_projected(enc: EncounterState) -> Array:
	var best: Array = []
	var best_v := -1.0
	for part: Array in partitions(enc, free_dice(enc)):
		_bind_all(enc, part)
		var v := enc.projected().damage
		if v > best_v:
			best_v = v
			best = part
		while not enc.pending.is_empty():
			enc.unbind(0)
	return best


func _group_stats(enc: EncounterState, idx: PackedInt32Array) -> Vector2:
	var faces: Array[Face] = []
	for i in idx:
		faces.append(enc.face_at(i))
	var res := Recipes.resolve(db, faces, enc.run.levels)
	return db.unit_stats(res["unit"], enc.run.level_of(res["unit"]))


func _bind_all(enc: EncounterState, part: Array) -> void:
	for idx: PackedInt32Array in part:
		for i in idx:
			enc.toggle_select(i)
		enc.bind()


## Appendix A encounter: 0 rerolls used, greedy partition each turn. Returns damage.
func play_baseline_encounter(enc: EncounterState) -> float:
	var p := 0.0
	var c := 0.0
	while enc.phase == EncounterState.Phase.AWAIT_INPUT:
		var part := best_partition_base(enc, p, c)
		for idx: PackedInt32Array in part:
			var s := _group_stats(enc, idx)
			p += s.x
			c += s.y
		_bind_all(enc, part)
		enc.summon()
	return enc.result.damage


## Appendix B encounter policy.
func play_encounter(enc: EncounterState) -> void:
	while enc.phase == EncounterState.Phase.AWAIT_INPUT:
		var part := best_partition_projected(enc)
		var used := {}
		for idx: PackedInt32Array in part:
			for i in idx:
				used[i] = true
		if enc.rerolls_left > 0 and part.size() < enc.tray_size / 2:
			for i in free_dice(enc):
				if not used.has(i):
					enc.toggle_select(i)
			if enc.reroll():
				continue
		_bind_all(enc, part)
		if enc.can(EncounterState.Verb.ATTACK) and enc.projected().damage >= 1.1 * enc.hp:
			enc.attack_now()
		else:
			enc.summon()


## Appendix B shop policy. `essence` = the last army's essence per element.
func play_shop(run: RunState, essence: Dictionary) -> void:
	var shop := run.shop
	var keep := 5 if run.night >= 2 else 0
	var rarity_rank := {"RARE": 3, "UNCOMMON": 2, "COMMON": 1}
	var best_slot := -1
	for i in shop.items.size():
		var item := shop.items[i]
		if item["kind"] != ShopState.KIND_RELIC or not shop.can_buy(db, run, i):
			continue
		if best_slot == -1 or rarity_rank[db.relics[item["id"]]["rarity"]] > rarity_rank[db.relics[shop.items[best_slot]["id"]]["rarity"]]:
			best_slot = i
	if best_slot != -1:
		shop.buy(db, run, best_slot)
	else:
		var top_element := ""
		for e: String in essence:
			if top_element == "" or essence[e] > essence[top_element]:
				top_element = e
		var none: Array[Vector2i] = []
		for i in shop.items.size():
			var item := shop.items[i]
			if item["id"] == "TOME_" + top_element and run.money - item["price"] >= keep:
				shop.buy_use(db, run, i, none)
	if ShopState.can_buy_equipment(db, run) and run.money - int(db.equipment[run.equipment_offer]["price"]) >= keep:
		ShopState.buy_equipment(db, run)


## Plays a whole run; returns {night, won, damages: Array}.
func play_run(seed: String) -> Dictionary:
	var run := RunFlow.new_run(db, seed)
	var reached := 1
	var died := ""
	var ratios := {}   # night -> Array of damage / HP
	while run.phase == RunState.Phase.NIGHT_MAP:
		reached = run.night
		var enc := RunFlow.start_encounter(db, run)
		enc.begin()
		play_encounter(enc)
		var essence := ScoreCtx.build(enc.army, 0, 0, 0, 0).essence
		if not ratios.has(run.night):
			ratios[run.night] = []
		ratios[run.night].append(enc.result.damage / enc.hp)
		if not enc.win:
			died = "%d-%s%s" % [run.night, enc.entry["role"], "" if enc.rules.is_empty() else "-" + "+".join(enc.rules)]
		RunFlow.finish_encounter(db, run, enc)
		if run.phase == RunState.Phase.SHOP:
			play_shop(run, essence)
			RunFlow.leave_shop(run)
	return {"night": reached, "won": run.phase == RunState.Phase.VICTORY, "best": run.stats["best_damage"],
		"died": died, "ratios": ratios, "relics": run.relics.size(), "money": run.money}
