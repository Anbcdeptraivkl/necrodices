extends Control
## Game Over / Victory (GAME_SPEC §7.3): run summary and New Run / Title.

func _ready() -> void:
	var db: ContentDb = Game.db
	var run: RunState = Game.run
	var won := run.phase == RunState.Phase.VICTORY
	%Title.text = db.text("title_victory" if won else "title_game_over")
	%Subtitle.text = db.text("msg_victory") if won else db.text("msg_defeat")
	var entry := run.current_encounter()
	var lines: PackedStringArray = [
		db.text("end_night") % [run.night, int(db.curve["nights"])],
		db.text("end_encounter") % db.text("role_" + (entry["role"] as String).to_lower()),
		db.text("end_best") % Settings.fmt(float(run.stats["best_damage"])),
	]
	var top := run.most_summoned()
	if top != "":
		lines.append(db.text("end_most") % db.units[top]["name"])
		%Unit.texture = Art.unit(top)
	lines.append(db.text("end_seed") % run.seed)
	%Stats.text = "\n".join(lines)
	%NewRun.text = db.text("btn_new_run")
	%ToTitle.text = db.text("btn_title")
	%NewRun.pressed.connect(func() -> void:
		Audio.play("click")
		Game.new_run())
	%ToTitle.pressed.connect(func() -> void:
		Audio.play("click")
		Game.goto("title"))
	Audio.music("" if not won else "night")
