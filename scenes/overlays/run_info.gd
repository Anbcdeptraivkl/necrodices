extends Overlay
## Run Info / recipe book (GAME_SPEC §8 — mandatory, ART_SPEC §6.6): the 6×6 pair matrix with
## unit icons, the four triple recipes, and the unit level table. Hover / click a cell for the
## unit's details in the info panel. All recipes are shown (discovery is stretch).

var _db: ContentDb
var _run: RunState
@onready var _matrix: GridContainer = %Matrix
@onready var _triples: VBoxContainer = %Triples
@onready var _levels: GridContainer = %Levels
@onready var _close: Button = %Close


func setup(db: ContentDb, run: RunState) -> void:
	_db = db
	_run = run
	%Title.text = db.text("title_run_info")
	%TriplesTitle.text = db.text("lbl_triples")
	%LevelsTitle.text = db.text("lbl_levels")
	_close.text = db.text("btn_close")
	_matrix.add_child(_cell(null))
	for e: String in RulesRegistry.ELEMENTS:
		_matrix.add_child(_cell(Art.glyph(e, true)))
	for a: String in RulesRegistry.ELEMENTS:
		_matrix.add_child(_cell(Art.glyph(a, true)))
		for b: String in RulesRegistry.ELEMENTS:
			var unit: String = db.recipes[ContentDb.recipe_key([a, b])]
			var elements := PackedStringArray([a, b])
			var cell := _cell(Art.unit(unit, 0, elements))
			InfoPanel.attach(cell, func() -> Dictionary: return InfoText.unit(db, unit, run.level_of(unit), elements))
			_matrix.add_child(cell)
	for key: String in db.recipes:
		if key.count("+") != 2:
			continue
		var unit: String = db.recipes[key]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 2)
		var icon := _cell(Art.unit(unit))
		InfoPanel.attach(icon, func() -> Dictionary: return InfoText.unit(db, unit, run.level_of(unit)))
		row.add_child(icon)
		for e: String in key.split("+"):
			row.add_child(_cell(Art.glyph(e, true), Vector2(10, 20)))
		var name := Label.new()
		name.text = db.units[unit]["name"]
		row.add_child(name)
		_triples.add_child(row)
	for unit in db.unit_order:
		var lv := run.level_of(unit)
		var stats := db.unit_stats(unit, lv)
		var name := Label.new()
		name.text = db.units[unit]["name"]
		name.theme_type_variation = &"BodyLabel" if lv == 1 else &"GoldLabel"
		var info := Label.new()
		info.text = db.text("lbl_level_row") % [lv, RelicEval.fmt(stats.x), RelicEval.fmt(stats.y)]
		info.theme_type_variation = &"MutedLabel" if lv == 1 else &"GoldLabel"
		_levels.add_child(name)
		_levels.add_child(info)


func _ready() -> void:
	_close.pressed.connect(func() -> void:
		Audio.play("click")
		close(null))


func _cell(tex: Texture2D, size := Vector2(20, 20)) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = size
	t.texture = tex
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_STOP if tex != null else Control.MOUSE_FILTER_IGNORE
	return t
