extends Control

signal close_requested
var embedded_holo := false

const MAP := "res://game/run/route/route_map_screen.tscn"

var heading: Label
var balance: Label
var list: VBoxContainer
var feedback: Label

func _state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	var layer := MarginContainer.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_theme_constant_override("margin_left", 36)
	layer.add_theme_constant_override("margin_right", 36)
	layer.add_theme_constant_override("margin_top", 30)
	layer.add_theme_constant_override("margin_bottom", 30)
	add_child(layer)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	layer.add_child(layout)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 28)
	layout.add_child(heading)
	balance = Label.new()
	layout.add_child(balance)
	list = VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(list)
	feedback = Label.new()
	layout.add_child(feedback)
	var leave := Button.new()
	leave.text = "离开酒馆"
	leave.custom_minimum_size.y = 45
	leave.pressed.connect(_leave)
	layout.add_child(leave)
	_refresh()

func _refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var state := _state()
	if state == null or not bool(state.call("is_current_tavern_active")):
		heading.text = "酒馆不可用"
		return
	var tavern := state.call("get_current_tavern") as TavernDefinition
	heading.text = tavern.display_name
	balance.text = "能量结晶：%d" % int(state.get("energy_crystals"))
	var candidates: Array = state.call("get_tavern_candidates")
	var db := preload("res://data/bridge/bridge_database.tres") as BridgeDatabase
	for i in range(candidates.size()):
		var id := StringName(candidates[i])
		var crew := db.find_crew(id)
		if crew == null:
			continue
		var entry := HBoxContainer.new()
		entry.custom_minimum_size.y = 76
		list.add_child(entry)
		var description := Label.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.text = "%s  |  %s  |  %s  |  %d 能量结晶\n%s" % [crew.display_name, String(crew.race), String(crew.rarity), crew.price, crew.description]
		entry.add_child(description)
		var button := Button.new()
		var hired := bool(state.call("is_tavern_candidate_hired", i))
		button.text = "已招募" if hired else "招募"
		button.disabled = hired or not bool(state.call("can_hire_tavern_crew", i))
		button.custom_minimum_size.x = 120
		button.pressed.connect(_hire.bind(i))
		entry.add_child(button)

func _hire(index: int) -> void:
	if bool(_state().call("hire_tavern_crew", index)):
		feedback.text = "招募成功，人员已加入机组库存"
	else:
		feedback.text = "招募失败：能量结晶不足或候选已招募"
	_refresh()

func _leave() -> void:
	var state := _state()
	if state != null and bool(state.call("is_current_tavern_active")):
		state.call("complete_current_route_node")
	if embedded_holo:
		close_requested.emit()
	else:
		get_tree().change_scene_to_file(MAP)
