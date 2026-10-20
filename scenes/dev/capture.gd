extends Node
## Screenshot runner (skill godot-debugging-testing): builds a known state from a preset,
## waits for layout and animation to settle, saves the viewport as PNG, quits.
##   godot --path . --resolution 960x540 res://scenes/dev/capture.tscn -- --preset=encounter --out=captures/x.png
## Presets are rows in PRESETS; a missing situation is a new row, not a new branch.
## Saves go to user://sav_capture.

const PRESETS := {
	"title": {"screen": "title"},
	"night_map": {"screen": "night_map", "seed": "CAPTURE1"},
	"encounter": {"screen": "encounter", "seed": "CAPTURE1", "relics": ["RATTLE_DRUM", "EMBER_JAR", "CROWN_OF_THE_LICH"],
		"consumables": ["SIGIL_FIRE", "TOME_BONE"], "army_turns": 1},
	"boss": {"screen": "encounter", "seed": "CAPTURE2", "night": 8, "encounter": 2, "army_turns": 2,
		"relics": ["BONE_PILE", "FULL_MOON", "TACTICIAN_SKULL", "WISP_JAR", "GRAVEDIGGER_LAMP"], "dice": 8},
	"combat": {"screen": "encounter", "seed": "CAPTURE3", "army_turns": 2, "attack": true, "wait": 1.6,
		"relics": ["RATTLE_DRUM", "HYBRID_VIGOR", "GRAVEDIGGER_LAMP"], "dice": 6},
	"horde": {"screen": "encounter", "seed": "CAPTURE4", "army_turns": 3, "levels": 12, "dice": 8,
		"relics": ["BONE_PILE", "FULL_MOON", "CROWN_OF_THE_LICH", "BLACK_GRIMOIRE", "SPIRIT_BOARD"],
		"attack": true, "wait": 4.6},
	"shop": {"screen": "shop", "seed": "CAPTURE5", "relics": ["RATTLE_DRUM", "OVERGROWTH"], "money": 23,
		"consumables": ["INK_HEX"]},
	"recipes": {"screen": "night_map", "seed": "CAPTURE1", "overlay": "run_info"},
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
	game.profile["tutorial"] = {"tut_first_roll": true, "tut_first_bind": true, "tut_before_summon": true,
		"tut_first_combat": true, "tut_first_shop": true}
	var preset: Dictionary = PRESETS[_args.get("preset", "title")]
	await _build(game, db, preset)
	await get_tree().create_timer(float(preset.get("wait", 0.6))).timeout
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
	while run.dice.size() < int(p.get("dice", 4)):
		run.dice.append(Die.standard())
	run.money = int(p.get("money", run.money))
	if p.has("levels"):
		for u in db.unit_order:
			run.levels[u] = int(p["levels"])
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
		"shop":
			run.shop = ShopState.open(db, run)
			run.phase = RunState.Phase.SHOP
			game.goto("shop")
		"end":
			run.phase = RunState.Phase.GAME_OVER
			run.stats["best_damage"] = 1234567.0
			run.record_summon("LICH")
			game.goto("end")
		"encounter":
			game.start_encounter()
			await get_tree().process_frame
			await get_tree().process_frame
			var enc: EncounterState = game.encounter
			for t in int(p.get("army_turns", 0)):
				_bind_pairs(enc)
				if t == int(p.get("army_turns", 0)) - 1 and p.get("attack", false):
					enc.attack_now()
					get_tree().current_scene.call(&"_after_commit")
				else:
					enc.summon()
			if not p.get("attack", false):
				_select_some(enc)


func _bind_pairs(enc: EncounterState) -> void:
	var bot := SimBot.new(enc.db)
	var part := bot.best_partition_projected(enc)
	for idx: PackedInt32Array in part:
		for i in idx:
			enc.toggle_select(i)
		enc.bind()


func _select_some(enc: EncounterState) -> void:
	_bind_pairs(enc)
	if enc.pending.size() > 1:
		enc.unbind(enc.pending.size() - 1)
	for i in enc.tray_size:
		if enc.bound[i] == -1 and i != enc.shackled:
			enc.toggle_select(i)
			break
