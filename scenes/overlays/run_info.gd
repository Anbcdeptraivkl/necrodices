extends Overlay
## Codex (GAME_SPEC §8, ART_SPEC §6.6), in pages:
## COMBOS — every combo illustrated (a unit it summons + an example roll), its level and
## Power × Count at that level, and the four rituals (core element twice);
## MONSTERS / HUNTERS / RUNES / TRINKETS / POTIONS / GEMS / GEAR — a grid of entries and a
## detail pane (name, kind in its colour code, effect, a short funny description). Hovering a
## cell shows it; clicking pins it. All words come from data/text.

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
const PAGES := ["combos", "units", "hunters", "runes", "trinkets", "potions", "gems", "gear"]
const UNIT_KIND_ORDER := ["T1", "HYBRID", "WISP", "RITUAL", "PARADE", "ELITE", "LEGEND"]

var _db: ContentDb
var _run: RunState
var _page := ""
var _pinned := ""
var _cells: Array[CodexCell] = []
var _infos := {}        # entry key -> InfoText dictionary
var _tabs := {}         # page -> Button
@onready var _combos: GridContainer = %Combos
@onready var _rituals: VBoxContainer = %Rituals
@onready var _grid: GridContainer = %Grid
@onready var _close: Button = %Close


func setup(db: ContentDb, run: RunState) -> void:
	_db = db
	_run = run
	%Title.text = ""
	%Title.visible = false
	%CombosTitle.text = db.text("lbl_combos")
	%RitualsTitle.text = db.text("lbl_rituals")
	_close.text = db.text("btn_close")
	for page: String in PAGES:
		var b := Button.new()
		b.text = db.text("codex_tab_" + page)
		b.theme_type_variation = &"SecondaryButton"
		b.custom_minimum_size = Vector2(0, 16)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func() -> void:
			Audio.play("page")
			show_page(page))
		%Tabs.add_child(b)
		_tabs[page] = b
	_build_overview()
	show_page("combos")


func _ready() -> void:
	_close.pressed.connect(func() -> void:
		Audio.play("click")
		close(null))


func show_page(page: String) -> void:
	_page = page
	for p: String in _tabs:
		_tabs[p].theme_type_variation = &"" if p == page else &"SecondaryButton"
	%Overview.visible = page == "combos"
	%Entries.visible = page != "combos"
	if page != "combos":
		_fill_entries(_entries(page))


## [key, texture, ring colour, info] rows for a page.
func _entries(page: String) -> Array:
	var out: Array = []
	match page:
		"units":
			for kind: String in UNIT_KIND_ORDER:
				for id: String in _db.units:
					if _db.units[id]["kind"] == kind:
						var tint := PackedStringArray(["LEAF", "VOLT"]) if kind == "WISP" else PackedStringArray()
						var info := InfoText.unit(_db, id, tint)
						info["body"] = "%s\n%s" % [InfoText.unit_recipe(_db, id), info["body"]]
						out.append([id, Art.unit(id, 0, tint), Color(0, 0, 0, 0), info])
		"hunters":
			for id: String in _db.enemies:
				out.append([id, Art.enemy(id), Color(0, 0, 0, 0), InfoText.hunter(_db, id)])
		"runes":
			for id in RulesRegistry.RUNES:
				out.append([id, Art.face_tile(Face.new("BONE", 6, id)), Art.kind_colour("RUNE"), InfoText.rune(_db, id)])
		"trinkets":
			for rarity: String in RulesRegistry.RARITIES:
				for id: String in _db.relics:
					if _db.relics[id]["rarity"] == rarity:
						out.append([id, Art.relic(id), Art.kind_colour("RELIC"), InfoText.relic_offer(_db, id)])
		"potions", "gems":
			var kind := "POTION" if page == "potions" else "GEM"
			for id: String in _db.consumables:
				if _db.consumables[id]["kind"] == kind:
					out.append([id, Art.consumable(id), Art.kind_colour(kind), InfoText.consumable(_db, id)])
		"gear":
			for id: String in _db.equipment:
				out.append([id, Art.equipment(id), Art.kind_colour("GEAR"), InfoText.equipment(_db, id)])
	return out


func _fill_entries(rows: Array) -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_cells.clear()
	_infos.clear()
	for row: Array in rows:
		var cell := CodexCell.new()
		cell.show_entry(row[0], row[1], row[2])
		cell.picked.connect(_on_picked)
		_grid.add_child(cell)
		_cells.append(cell)
		_infos[row[0]] = row[3]
	_pinned = rows[0][0] if not rows.is_empty() else ""
	_show_detail(_pinned)


func _on_picked(key: String, pinned: bool) -> void:
	if pinned:
		_pinned = key
		Audio.play("select")
	_show_detail(key)


func _show_detail(key: String) -> void:
	for c in _cells:
		c.selected = c.key == _pinned
	var info: Dictionary = _infos.get(key, {})
	%DetailIcon.texture = info.get("icon")
	%DetailTitle.text = info.get("title", "")
	%DetailKind.text = info.get("kind", "")
	%DetailKind.add_theme_color_override(&"font_color", info.get("kind_colour", Art.colour("N6")))
	%DetailPrice.text = info.get("price", "")
	%DetailPrice.visible = %DetailPrice.text != ""
	%DetailBody.text = info.get("body", "")
	%DetailLore.text = info.get("lore", "")


func _build_overview() -> void:
	var order := _db.combo_order.duplicate()
	order.reverse()
	for id: String in order:
		var lv := _run.level_of(id)
		var stats := _db.combo_stats(id, lv)
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
		var name := _label(_db.combos[id]["name"], style)
		_combos.add_child(name)
		_combos.add_child(_label(_db.text("lbl_level_short") % lv, style))
		_combos.add_child(_label("%s × %s" % [RelicEval.fmt(stats.x), RelicEval.fmt(stats.y)], style))
		for c in [icon, glyphs, name]:
			InfoPanel.attach(c, func() -> Dictionary: return InfoText.combo(_db, id, lv))
	for ritual: Dictionary in _db.rituals:
		var unit: String = ritual["unit"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 2)
		var icon := _cell(Art.unit(unit), Vector2(18, 18))
		InfoPanel.attach(icon, func() -> Dictionary: return InfoText.unit(_db, unit))
		row.add_child(icon)
		for e: String in ritual["elements"]:
			row.add_child(_cell(Art.glyph(e, true), Vector2(9, 18)))
			if e == ritual["core"]:
				row.add_child(_cell(Art.glyph(e, true), Vector2(9, 18)))
		row.add_child(_label(" " + _db.units[unit]["name"], &"BodyLabel"))
		_rituals.add_child(row)


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
