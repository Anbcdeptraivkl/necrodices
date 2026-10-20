extends Overlay
## Cash-out after a won combat (GAME_SPEC §4.5, ART_SPEC §6.6): the lines Economy produced,
## the total, CONTINUE. The money is already in the run; this only explains it.

@onready var _lines: GridContainer = %Lines
@onready var _total: Label = %Total
@onready var _continue: Button = %Continue


func setup(db: ContentDb, lines: Array[Dictionary]) -> void:
	dismissable = false
	%Title.text = db.text("title_cash_out")
	for line in lines:
		var label := Label.new()
		var text := db.text(line["key"])
		if line["key"] == "cashout_relics":
			text = db.relics[line["source"]]["name"]
		elif line["key"] == "cashout_unused_summons":
			text = "%s ×%s" % [text, line["source"]]
		label.text = text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var amount := Label.new()
		amount.text = "$%d" % int(line["amount"])
		amount.theme_type_variation = &"GoldLabel"
		_lines.add_child(label)
		_lines.add_child(amount)
	_total.text = "%s  $%d" % [db.text("cashout_total"), Economy.total(lines)]
	_continue.text = db.text("btn_continue")


func _ready() -> void:
	_continue.pressed.connect(func() -> void:
		Audio.play("coin")
		close(true))
