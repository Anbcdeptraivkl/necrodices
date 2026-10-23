extends Overlay
## Codex (GAME_SPEC §8, ART_SPEC §6.6): every combo illustrated — a unit it summons and an
## example roll as element glyphs — with its level and Power × Count at that level; the four
## rituals (core element twice); the eight runes on their die bodies. Hover for details.

## Illustration per combo: [unit, its tint elements, example faces]. View-only examples.
const EXAMPLES := {
	"QUINTET": ["IRON_JUGGERNAUT", [], ["METAL", "METAL", "METAL", "METAL", "METAL"]],
	"QUARTET": ["THUNDER_GHOUL", [], ["VOLT", "VOLT", "VOLT", "VOLT"]],
	"RITUAL": ["HEADLESS_HORSEMAN", [], ["BONE", "BONE", "FIRE", "LEAF"]],
	"FULL_MOON": ["STEAM_SLIME", [], ["FIRE", "FIRE", "FIRE", "ICE", "ICE"]],
	"RAINBOW": ["PHANTOM_PARADE", [], ["BONE", "FIRE", "ICE", "LEAF", "VOLT"]],
	"TRIO": ["SKELETON_WARRIOR", [], ["BONE", "BONE", "BONE"]],
	"DUO_PACT": ["JACK_O_LANTERN", [], ["FIRE", "FIRE", "LEAF", "LEAF"]],
	"RABBLE": ["WISP", ["LEAF", "VOLT"], ["LEAF", "VOLT", "METAL"]],
}

var _db: ContentDb
var _run: RunState
@onready var _combos: GridContainer = %Combos
@onready var _rituals: VBoxContainer = %Rituals
@onready var _runes: GridContainer = %Runes
@onready var _close: Button = %Close


func setup(db: ContentDb, run: RunState) -> void:
	_db = db
	_run = run
	%Title.text = db.text("title_codex")
	%CombosTitle.text = db.text("lbl_combos")
	%RitualsTitle.text = db.text("lbl_rituals")
	%RunesTitle.text = db.text("lbl_runes")
	_close.text = db.text("btn_close")
	var order := db.combo_order.duplicate()
	order.reverse()
	for id: String in order:
		var lv := run.level_of(id)
		var stats := db.combo_stats(id, lv)
		var style := &"GoldLabel" if lv > 1 else &"BodyLabel"
		var example: Array = EXAMPLES[id]
		var icon := _cell(Art.unit(example[0], 0, PackedStringArray(example[1])), Vector2(18, 18))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_combos.add_child(icon)
		var glyphs := HBoxContainer.new()
		glyphs.add_theme_constant_override(&"separation", 1)
		glyphs.custom_minimum_size = Vector2(46, 18)
		for e: String in example[2]:
			glyphs.add_child(_cell(Art.glyph(e, true), Vector2(8, 18)))
		_combos.add_child(glyphs)
		var name := _label(db.combos[id]["name"], style)
		_combos.add_child(name)
		_combos.add_child(_label(db.text("lbl_level_short") % lv, style))
		_combos.add_child(_label("%s × %s" % [RelicEval.fmt(stats.x), RelicEval.fmt(stats.y)], style))
		for c in [icon, glyphs, name]:
			InfoPanel.attach(c, func() -> Dictionary: return InfoText.combo(db, id, lv))
	for ritual: Dictionary in db.rituals:
		var unit: String = ritual["unit"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 2)
		var icon := _cell(Art.unit(unit), Vector2(18, 18))
		InfoPanel.attach(icon, func() -> Dictionary: return InfoText.unit(db, unit))
		row.add_child(icon)
		for e: String in ritual["elements"]:
			row.add_child(_cell(Art.glyph(e, true), Vector2(9, 18)))
			if e == ritual["core"]:
				row.add_child(_cell(Art.glyph(e, true), Vector2(9, 18)))
		row.add_child(_label(" " + db.units[unit]["name"], &"BodyLabel"))
		_rituals.add_child(row)
	for rune in RulesRegistry.RUNES:
		var face := Face.new("FIRE", 3, rune)
		var tile := FaceTile.new()
		tile.show_points = false
		tile.show_face(face, -1, -1)
		tile.mouse_default_cursor_shape = Control.CURSOR_ARROW
		InfoPanel.attach(tile, func() -> Dictionary: return {"icon": Art.die_body(face),
			"title": db.text("rune_name_" + rune.to_lower()), "kind": db.text("info_kind_rune"),
			"body": db.text("rune_" + rune.to_lower())})
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override(&"separation", 2)
		cell.add_child(tile)
		cell.add_child(_label(db.text("rune_name_" + rune.to_lower()), &"BodyLabel"))
		_runes.add_child(cell)


func _ready() -> void:
	_close.pressed.connect(func() -> void:
		Audio.play("click")
		close(null))


func _label(text: String, style: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = style
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	return l


func _cell(tex: Texture2D, size := Vector2(20, 20)) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = size
	t.texture = tex
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_STOP if tex != null else Control.MOUSE_FILTER_IGNORE
	return t
