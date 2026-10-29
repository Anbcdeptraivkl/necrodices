extends Node
## Screenshot runner (skill godot-debugging-testing): builds a known state from a preset,
## waits for layout and animation to settle, saves the viewport as PNG, quits.
##   godot --path . --resolution 960x540 res://scenes/dev/capture.tscn -- --preset=encounter --out=captures/x.png
## Presets are rows in PRESETS; a missing situation is a new row, not a new branch.
## Battle presets: `squads` summons played by the balance bot's pick through the screen's own
## handlers; `pick` leaves the last pick unsummoned; `roll` presses ROLL; `wait` = seconds of
## playback before the shot (`--wait=<s>` overrides it; `--time_scale=0.1` slows the game so a
## 0.1 s punch can be caught). Saves go to user://sav_capture.

const PRESETS := {
	"title": {"screen": "title"},
	"title_hover": {"screen": "title", "hover": "NewRun"},
	"map_tip_codex": {"screen": "night_map", "seed": "CAPTURE1", "hover": "Codex", "wait": 0.8},
	"night_map": {"screen": "night_map", "seed": "CAPTURE1"},
	"cup": {"screen": "encounter", "seed": "CAPTURE1", "relics": ["RATTLE_DRUM", "EMBER_JAR"]},
	"encounter": {"screen": "encounter", "seed": "CAPTURE1", "relics": ["RATTLE_DRUM", "EMBER_JAR", "CROWN_OF_THE_LICH"],
		"consumables": ["ELIXIR_FIRE", "AMBER"], "squads": 2, "pick": true, "wait": 6.0},
	"rolling": {"screen": "encounter", "seed": "CAPTURE1", "roll": true, "wait": 0.45},
	"summoning": {"screen": "encounter", "seed": "CAPTURE3", "squads": 1, "wait": 1.1,
		"relics": ["RATTLE_DRUM", "HYBRID_VIGOR", "GRAVEDIGGER_LAMP"], "dice": 6},
	"summon_8": {"screen": "encounter", "seed": "CAPTURE4", "squads": 1, "dice": 8, "runes": true, "wait": 0.9,
		"relics": ["EMBER_JAR", "MOSS_CHARM", "LIGHTNING_ROD"]},
	"summon_relics": {"screen": "encounter", "seed": "CAPTURE1", "squads": 1, "wait": 2.0,
		"relics": ["EMBER_JAR", "MOSS_CHARM", "GRAVEDIGGER_LAMP", "LIGHTNING_ROD"], "dice": 6},
	"boss": {"screen": "encounter", "seed": "CAPTURE2", "night": 8, "encounter": 2, "squads": 2, "pick": true,
		"relics": ["BONE_PILE", "BLOOD_MOON", "TACTICIAN_SKULL", "WISP_JAR", "GRAVEDIGGER_LAMP"], "dice": 8, "wait": 6.0},
	"horde": {"screen": "encounter", "seed": "CAPTURE4", "squads": 3, "levels": 6, "dice": 8, "runes": true, "pick": true,
		"relics": ["MOSS_CHARM", "CROWN_OF_THE_LICH", "GRAVEDIGGER_LAMP", "SPIRIT_BOARD", "TRIO_TOTEM"], "wait": 9.0},
	"result": {"screen": "encounter", "seed": "CAPTURE5", "squads": 1, "dice": 6, "hp": 0.01, "wait": 6.0, "attack": true,
		"relics": ["EMBER_JAR", "TRIO_TOTEM"]},
	"charge": {"screen": "encounter", "seed": "CAPTURE5", "squads": 1, "dice": 6, "hp": 0.01, "wait": 2.75, "attack": true,
		"relics": ["EMBER_JAR", "TRIO_TOTEM"]},
	"shop": {"screen": "shop", "seed": "CAPTURE5", "relics": ["RATTLE_DRUM", "OVERGROWTH"], "money": 23,
		"consumables": ["IRON_DRAUGHT"], "dice": 7, "runes": true, "gear": ["GRAVE_BELL", "LOADED_CUP"]},
	"shop_tip": {"screen": "shop", "seed": "CAPTURE5", "money": 23, "hover": "Gear", "wait": 0.8},
	"shop_coffer": {"screen": "shop", "seed": "CAPTURE7", "money": 23, "coffer": "COFFER_POTION_JUMBO"},
	"codex": {"screen": "night_map", "seed": "CAPTURE1", "overlay": "run_info", "levels": 2},
	"codex_units": {"screen": "night_map", "seed": "CAPTURE1", "overlay": "run_info", "page": "units"},
	"codex_trinkets": {"screen": "night_map", "seed": "CAPTURE1", "overlay": "run_info", "page": "trinkets"},
	"codex_runes": {"screen": "night_map", "seed": "CAPTURE1", "overlay": "run_info", "page": "runes"},
	"end": {"screen": "end", "seed": "CAPTURE6"},
}

var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_detach.call_deferred()


func _detach() -> void:
	var tree := get_tree()
	var placeholder := Node.new()
	tree.root.add_child(placeholder)
	tree.current_scene = placeholder
	reparent(tree.root)
	_capture.call_deferred()


func _capture() -> void:
	var game := get_node("/root/Game")
	var db := ContentDb.new()
	db.load_all()
	game.db = db
	game.store = SaveStore.new("user://sav_capture")
	game.profile = game.store.load_profile()
	game.profile["tutorial"] = {"tut_first_roll": true, "tut_first_summon": true, "tut_first_shop": true}
	var preset: Dictionary = PRESETS[_args.get("preset", "title")]
	Engine.time_scale = float(_args.get("time_scale", 1.0))
	await _build(game, db, preset)
	if preset.has("hover"):
		var target: Control = null
		for i in 30:  # the scene change is deferred: wait until the target exists
			await get_tree().process_frame
			var scene := get_tree().current_scene
			target = scene.find_child(preset["hover"], true, false) if scene != null else null
			if target != null:
				break
		var motion := InputEventMouseMotion.new()
		motion.position = target.get_global_rect().get_center() * Vector2(get_window().size) / get_viewport().get_visible_rect().size
		Input.parse_input_event(motion)
		get_viewport().warp_mouse(target.get_global_rect().get_center())  # tooltips sit at the pointer
	await get_tree().create_timer(float(_args.get("wait", preset.get("wait", 0.6)))).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out: String = _args.get("out", "captures/capture.png")
	img.save_png(ProjectSettings.globalize_path("res://") + out)
	print("captured %s %s" % [out, img.get_size()])
	get_tree().quit()


func _build(game: Node, db: ContentDb, p: Dictionary) -> void:
	if p["screen"] == "title":
		game.goto("title")
		return
	var run := RunFlow.new_run(db, p.get("seed", "CAPTURE"))
	game.run = run
	for id: String in p.get("relics", []):
		run.relics.append(RelicInstance.new(id))
	for id: String in p.get("consumables", []):
		run.consumables.append(id)
	while run.dice.size() < int(p.get("dice", 5)):
		run.dice.append(ShopState.new_die(db, run))
	if p.get("runes", false):
		for d in run.dice.size():
			run.dice[d].faces[1 + d % 5].rune = RulesRegistry.RUNES[d % RulesRegistry.RUNES.size()]
	run.money = int(p.get("money", run.money))
	for id: String in p.get("gear", []):
		run.equipment.append(id)
	if p.has("levels"):
		for c in db.combo_order:
			run.levels[c] = int(p["levels"])
	if p.has("night"):
		run.night = int(p["night"])
		NightGen.generate(db, run)
	run.encounter_index = int(p.get("encounter", 0))
	match p["screen"]:
		"night_map":
			game.goto("night_map")
			if p.has("overlay"):
				await get_tree().process_frame
				await get_tree().process_frame
				var host: OverlayHost = get_tree().current_scene.get_node("%Overlays")
				var o: Control = (load("res://scenes/overlays/%s.tscn" % p["overlay"]) as PackedScene).instantiate()
				host.push(o)
				o.call(&"setup", db, run)
				if p.has("page"):
					o.call(&"show_page", p["page"])
		"shop":
			run.shop = ShopState.open(db, run)
			run.phase = RunState.Phase.SHOP
			if p.has("coffer"):
				run.shop.coffers[0] = {"id": p["coffer"], "price": 6, "sold": false}
				run.shop.buy_coffer(db, run, 0)
			game.goto("shop")
		"end":
			run.phase = RunState.Phase.GAME_OVER
			run.stats["best_damage"] = 1234567.0
			run.record_summon("LICH", 5000.0)
			game.goto("end")
		"encounter":
			var entry: Dictionary = run.night_plan[run.encounter_index]
			entry["hp"] = float(entry["hp"]) * float(p.get("hp", 1000.0 if p.has("squads") else 1.0))
			game.start_encounter()
			await get_tree().process_frame
			await get_tree().process_frame
			_play(game.encounter, get_tree().current_scene, SimBot.new(db), p)


## Summons through the screen's handlers so the playback runs exactly as in play.
func _play(enc: EncounterState, screen: Node, bot: SimBot, p: Dictionary) -> void:
	var squads := int(p.get("squads", 0))
	for t in squads:
		enc.roll()
		enc.picked = bot.best_pick(enc)
		if t == squads - 1 and p.get("pick", false):
			enc.changed.emit()
			return
		screen.call(&"_on_summon")
	if p.get("roll", false):
		screen.call(&"_on_roll")
	if p.get("attack", false):
		screen.call(&"_do_attack")
