class_name SquadChip
extends PanelContainer
## A summoned squad in the battle's right column (ART_SPEC §6.2): unit icon, combo name and
## strength. Hover / click shows the squad in the info panel.

var hovered := false:
	set(v):
		hovered = v
		theme_type_variation = &"ChipPanelHover" if v else &"ChipPanel"
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _strength: Label = %Strength


func _ready() -> void:
	set_meta(&"hover_fx", true)


func show_squad(db: ContentDb, s: Squad) -> void:
	_icon.texture = Art.unit(s.unit_id, 0, s.unit_elements)
	_name.text = db.combos[s.combo]["name"]
	_strength.text = Settings.fmt(s.result.strength)
	InfoPanel.attach(self, func() -> Dictionary: return InfoText.squad(db, s))
