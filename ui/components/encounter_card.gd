class_name EncounterCard
extends PanelContainer
## Night Map card (ART_SPEC §6.4): enemy on a pedestal, name, role, HP, reward, boss rule chip,
## G1 border when current, pre-drawn DEFEATED stamp when beaten.

@onready var _enemy: TextureRect = %Enemy
@onready var _name: Label = %Name
@onready var _role: Label = %Role
@onready var _hp: Label = %Hp
@onready var _rule: Label = %Rule
@onready var _stamp: TextureRect = %Stamp
@onready var _current: Panel = %Current
var _enemy_id := ""
var _time := 0.0


func show_entry(db: ContentDb, run: RunState, entry: Dictionary, state: int) -> void:
	_enemy_id = entry["enemy"]
	var role: String = entry["role"]
	var rules: Array = entry["rules"]
	_name.text = db.enemies[_enemy_id]["name"]
	if rules.has("ENRAGED"):
		_name.text = db.boss_rules["ENRAGED"]["name"] + " " + _name.text
	_role.text = db.text("role_" + role.to_lower())
	_hp.text = db.text("lbl_hp") % Settings.fmt(entry["hp"])
	%Bounty.text = db.text("lbl_bounty") % Economy.bounty(db, run, role)
	var names: PackedStringArray = []
	for r: String in NightGen.active_rules(entry):
		names.append(db.boss_rules[r]["short"])
	_rule.text = "\n".join(names)
	_rule.get_parent().visible = not names.is_empty()
	_stamp.texture = Art.ui("stamp_defeated")
	_stamp.visible = state < 0
	_current.visible = state == 0
	modulate = Color(1, 1, 1, 0.6) if state < 0 else Color.WHITE


func _process(delta: float) -> void:
	_time += delta
	if _enemy_id != "":
		_enemy.texture = Art.enemy(_enemy_id, int(_time * 2.0) % 2)
