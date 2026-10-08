extends Control

signal close_requested
var embedded_holo := false

const ROUTE_MAP_SCENE_PATH := "res://game/run/route/route_map_screen.tscn"
const CARD_UI := preload("res://game/run/ui/holo_card_ui.gd")
var selected_item: StationCraftItemDefinition
var details: PanelContainer

var station_definition: StationDefinition

@onready var title: Label = $Margin/Layout/Title
@onready var resources: Label = $Margin/Layout/Resources
@onready var repair_status: Label = $Margin/Layout/RepairStatus
@onready var craft_list: VBoxContainer = $Margin/Layout/Body/CraftScroll/CraftList
@onready var status: Label = $Margin/Layout/Status

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	details = CARD_UI.make_details()
	$Margin/Layout/Body.add_child(details)
	station_definition = _resolve_station_definition()
	var run_state := _run_state()
	if run_state != null and run_state.run_active:
		run_state.call("repair_all_free_at_station")
	_refresh()

func _resolve_station_definition() -> StationDefinition:
	var run_state := _run_state()
	if run_state == null or not bool(run_state.call("is_route_active")):
		return null
	var node := run_state.call("get_current_route_node") as RunRouteNodeDefinition
	if node == null or node.node_type != RunRouteNodeDefinition.NodeType.REFIT or node.target_path.is_empty():
		return null
	if not ResourceLoader.exists(node.target_path):
		return null
	var loaded := ResourceLoader.load(node.target_path)
	return loaded as StationDefinition if loaded is StationDefinition else null

func _refresh() -> void:
	var run_state := _run_state()
	if run_state == null or not run_state.run_active or station_definition == null or not station_definition.is_valid():
		title.text = "空间站不可用"
		resources.text = ""
		repair_status.text = ""
		_clear_craft_list()
		return

	title.text = station_definition.display_name
	resources.text = "能量结晶：%d｜零件：%d｜仓库：%d / %d" % [
		int(run_state.get("energy_crystals")),
		int(run_state.get("parts")),
		int(run_state.call("get_warehouse_used")),
		int(run_state.call("get_warehouse_capacity"))
	]
	repair_status.text = "空间站维护服务：已免费将全部 Hull 恢复至满血。"
	_rebuild_craft_list()
	_update_details()

func _clear_craft_list() -> void:
	for child in craft_list.get_children():
		craft_list.remove_child(child)
		child.queue_free()

func _rebuild_craft_list() -> void:
	_clear_craft_list()
	var run_state := _run_state()
	for raw_item in station_definition.craft_items:
		var item := raw_item as StationCraftItemDefinition
		if item == null:
			continue
		var panel := PanelContainer.new()
		CARD_UI.style_card(panel, selected_item == item)
		panel.custom_minimum_size.y = 66
		craft_list.add_child(panel)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var texture := TextureRect.new()
		texture.custom_minimum_size = Vector2(48, 48)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture = item.get_texture()
		row.add_child(texture)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = item.display_name
		label.add_theme_font_size_override("font_size", 17)
		row.add_child(label)
		var cost := Label.new()
		cost.text = "⬡ 零件 ×%d" % item.parts_cost
		cost.add_theme_color_override("font_color", Color("#8be5f6"))
		cost.add_theme_font_size_override("font_size", 16)
		row.add_child(cost)
		CARD_UI.make_card_clickable(panel, _select_item.bind(item))

func _select_item(item: StationCraftItemDefinition) -> void:
	selected_item = item
	_rebuild_craft_list()
	_update_details()

func _update_details() -> void:
	if details == null:
		return
	var state := _run_state()
	if selected_item == null or state == null:
		CARD_UI.show_details(details, "制造详情", "选择左侧模块查看制造成本与仓储需求。", "选择模块", false, Callable())
		return
	var can_craft := bool(state.call("can_craft_station_item", selected_item))
	var storage := int(state.call("get_module_storage_cost", selected_item.module_id, selected_item.module_count))
	var info := "%s\n制造成本：%d 零件\n仓储占用：%d\n\n%s" % [selected_item.get_contents_label(), selected_item.parts_cost, storage, "可以制造" if can_craft else "零件不足或仓库空间不足"]
	CARD_UI.show_details(details, selected_item.display_name, info, "制造", can_craft, _craft.bind(selected_item))

func _craft(item: StationCraftItemDefinition) -> void:
	var run_state := _run_state()
	if run_state != null and bool(run_state.call("craft_station_item", item)):
		status.text = "制造完成：%s，已送入仓库。" % item.get_contents_label()
	else:
		status.text = "制造失败：零件不足、仓库空间不足或配置无效。"
	_refresh()

func _leave_station() -> void:
	var run_state := _run_state()
	if run_state != null and bool(run_state.call("is_route_active")):
		var node := run_state.call("get_current_route_node") as RunRouteNodeDefinition
		if node != null and node.node_type == RunRouteNodeDefinition.NodeType.REFIT:
			run_state.call("complete_current_route_node")
	if embedded_holo:
		close_requested.emit()
	else:
		get_tree().change_scene_to_file(ROUTE_MAP_SCENE_PATH)
