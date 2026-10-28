class_name SquadChip
extends PanelContainer
## A summoned squad in the battle's squad grid (ART_SPEC §6.2): just the unit icon; combo,
## Power × Count and strength are in its tooltip.

var hovered := false:
	set(v):
		hovered = v
		theme_type_variation = &"ChipPanelHover" if v else &"ChipPanel"
@onready var _icon: TextureRect = %Icon


func _ready() -> void:
	set_meta(&"hover_fx", true)


func show_squad(db: ContentDb, s: Squad) -> void:
	_icon.texture = Art.unit(s.unit_id, 0, s.unit_elements)
	InfoPanel.attach(self, func() -> Dictionary: return InfoText.squad(db, s))
