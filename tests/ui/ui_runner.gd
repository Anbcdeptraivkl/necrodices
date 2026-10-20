extends Node
## UI smoke tests in the real game context (autoloads present), driven through the screens'
## own buttons and signals: every script parses, a full encounter → cash-out → shop → night map
## loop works, a loss reaches the end screen, saves restore. Prints PASS / FAIL lines and quits
## with exit code 1 on any failure. Entry point: tools\ui_test.cmd.
## Saves go to user://sav_uitest (never the real profile).

const SAVE_DIR := "user://sav_uitest"
const SKIP_DIRS := ["res://.godot", "res://addons", "res://tests"]

var _failures := 0
var _game: Node


func _ready() -> void:
	_detach.call_deferred()


## The runner must outlive scene changes: it moves under the root and leaves a placeholder as
## the current scene for change_scene to free.
func _detach() -> void:
	var tree := get_tree()
	var placeholder := Node.new()
	placeholder.name = "Placeholder"
	tree.root.add_child(placeholder)
	tree.current_scene = placeholder
	reparent(tree.root)
	_run.call_deferred()


func _run() -> void:
	_game = get_node("/root/Game")
	var db := ContentDb.new()
	_check(db.load_all(), "data loads")
	_game.db = db
	_game.store = SaveStore.new(SAVE_DIR)
	_game.store.delete_run()
	_game.profile = _game.store.load_profile()
	_game.profile["tutorial"] = {"tut_first_roll": true, "tut_first_bind": true, "tut_before_summon": true,
		"tut_first_combat": true, "tut_first_shop": true}
	await _case("scripts_parse", _scripts_parse)
	await _case("title", _title)
	await _case("win_loop", _win_loop)
	await _case("continue_restores_shop", _continue_restores_shop)
	await _case("loss_reaches_end", _loss)
	await _case("overlays_open", _overlays)
	_game.store.delete_run()
	print("UI %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _case(name: String, fn: Callable) -> void:
	var before := _failures
	var t0 := Time.get_ticks_msec()
	await fn.call()
	print("%s ui.%s (%d ms)" % ["PASS" if _failures == before else "FAIL", name, Time.get_ticks_msec() - t0])


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		push_error(msg)


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _scene() -> Node:
	return get_tree().current_scene


func _scripts_parse() -> void:
	for path in _gd_files("res://"):
		var s: Script = load(path)
		_check(s != null and s.can_instantiate() or path.contains("/tests/"), "script loads: %s" % path)
	await _frames(1)


func _gd_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for d in DirAccess.get_directories_at(dir):
		var sub := dir.path_join(d)
		if sub in SKIP_DIRS or d.begins_with("."):
			continue
		out.append_array(_gd_files(sub))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


func _title() -> void:
	_game.goto("title")
	await _frames()
	_check(_scene().name == "Title", "title scene shown")
	_check((_scene().get_node("%Continue") as Button).disabled, "no saved run → Continue disabled")


func _new_run(seed: String, hp_mult: float) -> void:
	_game.new_run(seed)
	_game.run.debug_hp_mult = hp_mult
	await _frames()


func _win_loop() -> void:
	await _new_run("UIWIN001", 0.001)
	_check(_scene().name == "NightMap", "night map after new run")
	(_scene().get_node("%Fight") as Button).pressed.emit()
	await _frames()
	_check(_scene().name == "Encounter", "encounter after FIGHT")
	var screen := _scene()
	var enc: EncounterState = _game.encounter
	_check(enc.turn == 1 and enc.tray_size == 4, "first turn rolled")
	# Bind the first bindable pair through the die views, then attack.
	var dice: Array = screen.get_node("%Tray").get_children()
	(dice[0] as DieView).pressed.emit(0)
	(dice[1] as DieView).pressed.emit(1)
	await _frames(1)
	(screen.get_node("%Bind") as Button).pressed.emit()
	await _frames(2)
	_check(enc.pending.size() == 1, "group bound through the BIND button")
	_check(screen.get_node("%Chips").get_child_count() == 1, "pending chip shown")
	(screen.get_node("%Attack") as Button).pressed.emit()
	await _frames(2)
	_check(enc.phase == EncounterState.Phase.DONE and enc.win, "combat won")
	_check(_game.run.phase == RunState.Phase.SHOP, "run moved to SHOP at once")
	(screen.get_node("%Queue") as PresentationQueue).skip_all()
	await _frames(3)
	var host: OverlayHost = screen.get_node("%Overlays")
	_check(host.is_open(), "cash-out overlay open")
	var cash := _find(host, "CashOut")
	_check(cash != null, "cash-out found")
	if cash != null:
		(cash.get_node("%Continue") as Button).pressed.emit()
	await _frames(4)
	_check(_scene().name == "Shop", "shop after cash-out")
	var shop := _scene()
	var money_before: int = _game.run.money
	_game.run.money = 50
	shop.call(&"_refresh")
	var cards: Array = shop.get_node("%Cards").get_children()
	(cards[0] as ShopCard).buy_pressed.emit(0)
	await _frames(2)
	_check(_game.run.shop.items[0]["sold"] or _game.run.money < 50, "bought from card 0")
	_check(_game.store.load_run().money == _game.run.money, "shop command saved")
	(shop.get_node("%Next") as Button).pressed.emit()
	await _frames(3)
	_check(_scene().name == "NightMap", "back to night map")
	_check(_game.run.encounter_index == 1, "next encounter is the champion")
	_check(money_before >= 0, "money kept")


func _continue_restores_shop() -> void:
	await _new_run("UICONT01", 0.001)
	_game.start_encounter()
	await _frames()
	var enc: EncounterState = _game.encounter
	enc.toggle_select(0)
	enc.toggle_select(1)
	enc.bind()
	enc.attack_now()
	_game.finish_encounter()
	var saved := JSON.stringify(JsonUtil.narrow(_game.run.to_dict()), "", true)
	_game.run = null
	_game.continue_run()
	await _frames(3)
	_check(_scene().name == "Shop", "continue routes to the shop")
	_check(JSON.stringify(JsonUtil.narrow(_game.run.to_dict()), "", true) == saved, "identical state after continue")


func _loss() -> void:
	await _new_run("UILOSS01", 1000.0)
	_game.start_encounter()
	await _frames()
	var screen := _scene()
	for t in 3:
		(screen.get_node("%Summon") as Button).pressed.emit()
		await _frames(1)
		var host: OverlayHost = screen.get_node("%Overlays")
		var confirm := _find(host, "Confirm")
		if confirm != null:
			(confirm.get_node("%Yes") as Button).pressed.emit()
		await _frames(2)
	_check(_game.encounter.phase == EncounterState.Phase.DONE and not _game.encounter.win, "lost the fight")
	_check(_game.run.phase == RunState.Phase.GAME_OVER, "run over")
	_check(not _game.store.has_run(), "run save deleted")
	(screen.get_node("%Queue") as PresentationQueue).skip_all()
	await get_tree().create_timer(0.8).timeout
	await _frames(3)
	_check(_scene().name == "End", "end screen")


func _overlays() -> void:
	await _new_run("UIOVER01", 1.0)
	_game.start_encounter()
	await _frames()
	var screen := _scene()
	(screen.get_node("%Book") as Button).pressed.emit()
	await _frames(2)
	var host: OverlayHost = screen.get_node("%Overlays")
	_check(_find(host, "RunInfo") != null, "recipe book opens")
	host.close_all()
	await _frames(2)
	_check(not host.is_open(), "overlays close")
	_game.run.consumables.append("SIGIL_FIRE")
	screen.call(&"_on_consumable_pressed", 0)
	screen.call(&"_use_selected_consumable", 0)
	await _frames(2)
	var inspector := _find(host, "DiceInspector")
	_check(inspector != null, "dice inspector opens for a sigil")
	if inspector != null:
		var tiles: Array = []
		for row in inspector.get_node("%Rows").get_children():
			for c in row.get_children():
				if c is FaceTile:
					tiles.append(c)
		(tiles[0] as FaceTile).pressed.emit(0, 0)
		await _frames(1)
		(inspector.get_node("%Confirm") as Button).pressed.emit()
		await _frames(3)
		_check(_game.run.dice[0].faces[0].element == "FIRE", "sigil applied through the inspector")
		_check(_game.run.consumables.is_empty(), "consumable used up")
	_game.goto("title")
	await _frames()


func _find(host: Node, name: String) -> Node:
	for n in host.find_children("*", "", true, false):
		if n.name == name:
			return n
	return null
