class_name Loadout
extends RefCounted
## Fills the loadout blocks that show what the player owns (battle left column, market): gear
## icons and one face tile per die (its rune face, else its best face). Hover = tooltip; the
## dice block opens the Dice Inspector from the screen that owns it.


static func fill_gear(grid: GridContainer, db: ContentDb, run: RunState) -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	for id in run.equipment:
		var icon := TextureRect.new()
		icon.texture = Art.equipment(id)
		icon.custom_minimum_size = Vector2(16, 16)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		InfoPanel.attach(icon, func() -> Dictionary: return InfoText.equipment(db, id))
		grid.add_child(icon)
	if run.equipment.is_empty():
		var none := Label.new()
		none.text = db.text("msg_no_equipment_owned")
		none.theme_type_variation = &"MutedLabel"
		grid.add_child(none)


## One tile per die; rebuilt only when the set changes size, faces refreshed every call.
static func fill_dice(grid: GridContainer, run: RunState) -> void:
	while grid.get_child_count() < run.dice.size():
		var tile := FaceTile.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(tile)
	for i in grid.get_child_count():
		var tile := grid.get_child(i) as FaceTile
		tile.visible = i < run.dice.size()
		if i < run.dice.size():
			tile.show_face(run.dice[i].faces[featured_face(run.dice[i])], i, -1)


## The face worth showing for a die: the first face with a rune, else its best non-BONE face
## (every die has BONE 6, so that would make all dice look alike).
static func featured_face(die: Die) -> int:
	var best := -1
	for f in die.faces.size():
		var face := die.faces[f]
		if face.rune != "":
			return f
		if face.element != "BONE" and (best < 0 or face.points > die.faces[best].points):
			best = f
	return maxi(best, 0)
