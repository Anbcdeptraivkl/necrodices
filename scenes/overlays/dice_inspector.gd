extends Overlay
## Dice Inspector (GAME_SPEC §8, ART_SPEC §6.6): every die's six faces; in target mode the
## player picks the faces a Sigil / Ink applies to. Result: Array[Vector2i] targets, or null.
## Legality comes from ConsumableFx.can_apply — the same check the command runs.

var _db: ContentDb
var _run: RunState
var _consumable := ""
var _targets: Array[Vector2i] = []
var _tiles: Array[FaceTile] = []
@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _rows: VBoxContainer = %Rows
@onready var _confirm: Button = %Confirm
@onready var _cancel: Button = %Cancel


## `consumable` = "" for view-only mode.
func setup(db: ContentDb, run: RunState, consumable: String) -> void:
	_db = db
	_run = run
	_consumable = consumable
	_title.text = db.text("title_dice") if consumable == "" else db.consumables[consumable]["name"]
	_hint.text = "" if consumable == "" else db.text("hint_pick_faces") % ConsumableFx.target_count(db, consumable)
	_confirm.visible = consumable != ""
	_confirm.text = db.text("btn_confirm")
	_cancel.text = db.text("btn_close") if consumable == "" else db.text("btn_cancel")
	for d in run.dice.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 4)
		var num := Label.new()
		num.text = str(d + 1)
		num.custom_minimum_size = Vector2(10, 16)
		num.theme_type_variation = &"MutedLabel"
		row.add_child(num)
		for f in Die.FACE_COUNT:
			var tile := FaceTile.new()
			tile.show_face(run.dice[d].faces[f], d, f)
			tile.pressed.connect(_on_tile)
			InfoPanel.attach(tile, func() -> Dictionary: return InfoText.face(db, run.dice[d].faces[f]))
			row.add_child(tile)
			_tiles.append(tile)
		_rows.add_child(row)
	_update()


func _ready() -> void:
	_confirm.pressed.connect(func() -> void:
		Audio.play("click")
		close(_targets))
	_cancel.pressed.connect(func() -> void:
		Audio.play("click")
		close(null))


func _on_tile(die: int, face: int) -> void:
	if _consumable == "":
		return
	var t := Vector2i(die, face)
	if _targets.has(t):
		_targets.erase(t)
	elif _targets.size() < ConsumableFx.target_count(_db, _consumable):
		_targets.append(t)
	elif ConsumableFx.target_count(_db, _consumable) == 1:
		_targets = [t]
	else:
		Audio.play("error")
		return
	Audio.play("select")
	_update()


func _update() -> void:
	for tile in _tiles:
		tile.selected = _targets.has(Vector2i(tile.die_index, tile.face_index))
	_confirm.disabled = _consumable == "" or not ConsumableFx.can_apply(_db, _run, _consumable, _targets)
