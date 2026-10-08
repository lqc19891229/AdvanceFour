extends Control

signal close_requested
var embedded_holo := false

const CARD_UI := preload("res://game/run/ui/holo_card_ui.gd")
var selected_index := -1
var details: PanelContainer

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
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	layout.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 550
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	details = CARD_UI.make_details()
	body.add_child(details)
	feedback = Label.new()
	layout.add_child(feedback)
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
	if selected_index < 0:
		for i in range(candidates.size()):
			if db.find_crew(StringName(candidates[i])) != null:
				selected_index = i
				break
	for i in range(candidates.size()):
		var id := StringName(candidates[i])
		var crew := db.find_crew(id)
		if crew == null:
			continue
		var panel := PanelContainer.new()
		CARD_UI.style_card(panel, selected_index == i)
		panel.custom_minimum_size.y = 94
		list.add_child(panel)
		var entry := HBoxContainer.new()
		panel.add_child(entry)
		var description := Label.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.text = crew.display_name
		description.add_theme_font_size_override("font_size", 19)
		entry.add_child(description)
		var price := Label.new()
		price.text = "◆ 能量结晶 ×%d" % crew.price
		price.add_theme_color_override("font_color", Color("#8be5f6"))
		entry.add_child(price)
		CARD_UI.make_card_clickable(panel, _select_candidate.bind(i))
	_update_details()

func _select_candidate(index: int) -> void:
	selected_index = index
	_refresh()

func _update_details() -> void:
	if details == null:
		return
	var state := _state()
	if state == null or not bool(state.call("is_current_tavern_active")):
		return
	var candidates: Array = state.call("get_tavern_candidates")
	if selected_index < 0 or selected_index >= candidates.size():
		CARD_UI.show_details(details, "机组详情", "选择左侧人物，查看种族、品质、说明和招募价格。", "选择机组", false, Callable())
		return
	var db := preload("res://data/bridge/bridge_database.tres") as BridgeDatabase
	var crew := db.find_crew(StringName(candidates[selected_index]))
	if crew == null:
		return
	var hired := bool(state.call("is_tavern_candidate_hired", selected_index))
	var can_hire := bool(state.call("can_hire_tavern_crew", selected_index))
	var info := "种族：%s\n品质：%s\n\n%s\n\n招募价格：%d 能量结晶\n%s" % [String(crew.race), String(crew.rarity), crew.description, crew.price, "已招募" if hired else "可以招募" if can_hire else "能量结晶不足"]
	CARD_UI.show_details(details, crew.display_name, info, "已招募" if hired else "招募", can_hire, _hire.bind(selected_index))

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
