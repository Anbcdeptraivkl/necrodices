extends Node
## UI smoke tests in the real game context (autoloads present), driven through the screens'
## own buttons and signals: every script parses, a full battle → spoils → market → night map
## loop works, a coffer opens, a loss reaches the end screen, saves restore. Prints PASS / FAIL lines and quits
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
	_game.profile["tutorial"] = {"tut_first_roll": true, "tut_first_summon": true, "tut_first_shop": true}
	await _case("scripts_parse", _scripts_parse)
	await _case("title", _title)
	await _case("win_loop", _win_loop)
	await _case("continue_restores_shop", _continue_restores_shop)
	await _case("loss_reaches_end", _loss)
	await _case("overlays_open", _overlays)
	await _case("coffer_take", _coffer)
	await _case("tooltip_no_flicker", _tooltip_states)
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


## Presses ROLL, skips the roll playback, picks the first `n` free dice through the die views.
func _roll_and_pick(screen: Node, n: int) -> void:
	var enc: EncounterState = _game.encounter
	(screen.get_node("%Roll") as Button).pressed.emit()
	await _frames(1)
	(screen.get_node("%Queue") as PresentationQueue).skip_all()
	await _frames(2)
	var dice: Array = screen.get_node("%Tray").get_children()
	var picked := 0
	for i in dice.size():
		if picked < n and i != enc.shackled:
			(dice[i] as DieView).pressed.emit(i)
			picked += 1
	await _frames(2)


func _win_loop() -> void:
	await _new_run("UIWIN001", 0.001)
	_check(_scene().name == "NightMap", "night map after new run")
	(_scene().get_node("%Fight") as Button).pressed.emit()
	await _frames()
	_check(_scene().name == "Encounter", "battle after FIGHT")
	var screen := _scene()
	var enc: EncounterState = _game.encounter
	_check(enc.phase == EncounterState.Phase.AWAIT_ROLL and enc.tray_size == 5, "dice in the cup")
	await _roll_and_pick(screen, 3)
	_check(enc.phase == EncounterState.Phase.PICK, "rolled through the ROLL button")
	_check(enc.picked.size() == 3, "three dice picked through the die views")
	_check((screen.get_node("%PickSlots") as Node).get_child(2).modulate.a == 1.0, "pick tray shows the third die")
	(screen.get_node("%Summon") as Button).pressed.emit()
	await _frames(1)
	(screen.get_node("%Queue") as PresentationQueue).skip_all()
	await _frames(2)
	_check(enc.phase == EncounterState.Phase.AWAIT_ROLL, "the squad joins; the battle waits")
	_check((screen.get_node("%Attack") as Button).is_visible_in_tree(), "ATTACK! shown between summons")
	(screen.get_node("%Attack") as Button).pressed.emit()
	await _frames(2)
	_check(enc.phase == EncounterState.Phase.DONE and enc.win, "battle won by attacking early")
	_check(_game.run.phase == RunState.Phase.SHOP, "run moved to SHOP at once")
	(screen.get_node("%Queue") as PresentationQueue).skip_all()
	await _frames(3)
	_check(screen.get_node("%Chips").get_child_count() == 1, "squad chip shown")
	var host: OverlayHost = screen.get_node("%Overlays")
	_check(host.is_open(), "spoils overlay open")
	var spoils := _find(host, "Spoils")
	_check(spoils != null, "spoils found")
	if spoils != null:
		(spoils.get_node("%Continue") as Button).pressed.emit()
	await _frames(4)
	_check(_scene().name == "Shop", "market after the spoils")
	var shop := _scene()
	_game.run.money = 50
	shop.call(&"_refresh")
	var cards: Array = shop.get_node("%Cards").get_children()
	(cards[0] as ShopCard).buy_pressed.emit(0)
	await _frames(2)
	_check(_game.run.shop.cards[0]["sold"] or _game.run.money < 50, "bought from card 0")
	_check(_game.store.load_run().money == _game.run.money, "market command saved")
	(shop.get_node("%Next") as Button).pressed.emit()
	await _frames(3)
	_check(_scene().name == "NightMap", "back to night map")
	_check(_game.run.encounter_index == 1, "next battle is the champion")


func _continue_restores_shop() -> void:
	await _new_run("UICONT01", 0.001)
	_game.start_encounter()
	await _frames()
	var enc: EncounterState = _game.encounter
	enc.roll()
	for i in enc.tray_size:
		if enc.picked.size() < 3 and i != enc.shackled:
			enc.toggle_select(i)
	enc.summon()
	enc.attack()
	_game.finish_encounter()
	var saved := JSON.stringify(JsonUtil.narrow(_game.run.to_dict()), "", true)
	_game.run = null
	_game.continue_run()
	await _frames(3)
	_check(_scene().name == "Shop", "continue routes to the market")
	_check(JSON.stringify(JsonUtil.narrow(_game.run.to_dict()), "", true) == saved, "identical state after continue")


func _loss() -> void:
	await _new_run("UILOSS01", 1000.0)
	_game.start_encounter()
	await _frames()
	var screen := _scene()
	for t in 3:
		await _roll_and_pick(screen, 3)
		(screen.get_node("%Summon") as Button).pressed.emit()
		await _frames(1)
		(screen.get_node("%Queue") as PresentationQueue).skip_all()
		await _frames(2)
	_check(not (screen.get_node("%Roll") as Button).visible, "no ROLL without summons")
	(screen.get_node("%Attack") as Button).pressed.emit()
	await _frames(1)
	(screen.get_node("%Queue") as PresentationQueue).skip_all()
	await _frames(2)
	_check(_game.encounter.phase == EncounterState.Phase.DONE and not _game.encounter.win, "lost the battle")
	_check(_game.run.phase == RunState.Phase.GAME_OVER, "run over")
	_check(not _game.store.has_run(), "run save deleted")
	await get_tree().create_timer(0.9).timeout
	await _frames(3)
	_check(_scene().name == "End", "end screen")


func _coffer() -> void:
	await _new_run("UICOFF01", 1.0)
	var run: RunState = _game.run
	run.shop = ShopState.open(_game.db, run)
	run.shop.coffers[0] = {"id": "COFFER_BONE", "price": 4, "sold": false}
	run.phase = RunState.Phase.SHOP
	run.money = 20
	_game.goto("shop")
	await _frames(3)
	var shop := _scene()
	(shop.get_node("%Coffers").get_child(0) as ShopCard).buy_pressed.emit(0)
	await _frames(3)
	var host: OverlayHost = shop.get_node("%Overlays")
	var coffer := _find(host, "Coffer")
	_check(coffer != null, "coffer overlay opens")
	var dice := run.dice.size()
	if coffer != null:
		(coffer.get_node("%Choices").get_child(0) as ShopCard).buy_pressed.emit(0)
	await _frames(3)
	_check(run.dice.size() == dice + 1, "took a die from the bone coffer")
	_check(run.shop.open_coffer.is_empty(), "coffer done")
	_check(_find(host, "Coffer") == null or not host.is_open(), "overlay closed")
	_game.goto("title")
	await _frames()


func _overlays() -> void:
	await _new_run("UIOVER01", 1.0)
	_game.start_encounter()
	await _frames()
	var screen := _scene()
	(screen.get_node("%TopBar").get_node("%Codex") as Button).pressed.emit()
	await _frames(2)
	var host: OverlayHost = screen.get_node("%Overlays")
	_check(_find(host, "RunInfo") != null, "codex opens")
	host.close_all()
	await _frames(2)
	_check(not host.is_open(), "overlays close")
	_game.run.consumables.append("ELIXIR_FIRE")
	(screen.get_node("%TopBar") as TopBar).use_requested.emit(0)
	await _frames(2)
	var inspector := _find(host, "DiceInspector")
	_check(inspector != null, "dice inspector opens for an elixir")
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
		_check(_game.run.dice[0].faces[0].element == "FIRE", "elixir applied through the inspector")
		_check(_game.run.consumables.is_empty(), "potion used up")
	_game.goto("title")
	await _frames()


func _find(host: Node, name: String) -> Node:
	for n in host.find_children("*", "", true, false):
		if n.name == name:
			return n
	return null


## The tooltip state machine (autoload UiFx): rest before opening, no blink across a gap,
## instant switch between targets, close after the grace, muted after a click.
func _tooltip_states() -> void:
	var fx := get_node("/root/UiFx")
	var a := Control.new()
	var b := Control.new()
	a.set_meta(&"tip", "A")
	b.set_meta(&"tip", "B")
	add_child(a)
	add_child(b)
	var panel: Control = fx.get(&"_tip_panel")
	fx.call(&"_update_tip", a, 0.1)
	fx.call(&"_update_tip", a, 0.1)
	_check(not panel.visible, "not before the rest time")
	fx.call(&"_update_tip", a, 0.2)
	_check(panel.visible, "opens after resting")
	fx.call(&"_update_tip", null, 0.05)
	_check(panel.visible, "a gap between slots does not close it")
	fx.call(&"_update_tip", b, 0.01)
	_check(panel.visible and fx.get(&"_tip_target") == b, "switches to the next target at once")
	fx.call(&"_update_tip", null, 0.1)   # enters the grace
	fx.call(&"_update_tip", null, 0.1)
	_check(panel.visible, "still open inside the grace time")
	fx.call(&"_update_tip", null, 0.1)
	_check(not panel.visible, "closes after the grace time")
	fx.call(&"_update_tip", a, 0.3)
	fx.call(&"_update_tip", a, 0.3)
	_check(panel.visible, "reopens on a target")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	fx.call(&"_input", click)
	fx.call(&"_update_tip", a, 0.5)
	fx.call(&"_update_tip", a, 0.5)
	_check(not panel.visible, "muted on the clicked target")
	fx.call(&"_update_tip", b, 0.3)
	fx.call(&"_update_tip", b, 0.3)
	_check(panel.visible, "unmuted on another target")
	fx.call(&"_set_tip", 0, null)
	a.queue_free()
	b.queue_free()
	await _frames(1)
