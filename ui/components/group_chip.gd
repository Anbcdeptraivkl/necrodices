class_name GroupChip
extends PanelContainer
## Pending group chip (ART_SPEC §6.2): group colour number + unit icon + short name.
## Click = unbind (the screen issues the command).

signal pressed(index: int)

var index := -1
var hovered := false:
	set(v):
		hovered = v
		theme_type_variation = &"ChipPanelHover" if v else &"ChipPanel"
@onready var _num: Label = %Num
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name


func _ready() -> void:
	set_meta(&"press_fx", true)
	set_meta(&"hover_fx", true)


func show_group(db: ContentDb, g: Group, group_index: int) -> void:
	index = group_index
	_num.text = str(group_index + 1)
	_num.add_theme_color_override(&"font_color", Art.group_colour(group_index))
	_icon.texture = Art.unit(g.unit_id, 0, g.elements)
	_name.text = db.units[g.unit_id]["name"]


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(index)
		accept_event()
