extends Control

const ROUTE_MAP_SCENE_PATH := "res://game/run/route/route_map_screen.tscn"
const EDITOR_SCENE_PATH := "res://game/ship/editor/ship_editor.tscn"
const RUN_REFIT_META := &"run_refit_mode"

var station_definition: StationDefinition

@onready var title: Label = $Margin/Layout/Title
@onready var resources: Label = $Margin/Layout/Resources
@onready var repair_status: Label = $Margin/Layout/RepairStatus
@onready var craft_list: VBoxContainer = $Margin/Layout/CraftScroll/CraftList
@onready var status: Label = $Margin/Layout/Status
@onready var refit_button: Button = $Margin/Layout/Actions/Refit
@onready var leave_button: Button = $Margin/Layout/Actions/Leave

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	refit_button.pressed.connect(_open_refit)
	leave_button.pressed.connect(_leave_station)
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
		refit_button.disabled = true
		leave_button.disabled = false
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
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 54)
		var texture := TextureRect.new()
		texture.custom_minimum_size = Vector2(48, 48)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture = item.get_texture()
		row.add_child(texture)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s｜%s｜需要 %d 零件｜仓储 %d" % [
			item.display_name,
			item.get_contents_label(),
			item.parts_cost,
			int(run_state.call("get_module_storage_cost", item.module_id, item.module_count))
		]
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(120, 44)
		button.text = "制造"
		button.disabled = not bool(run_state.call("can_craft_station_item", item))
		button.tooltip_text = "零件不足或仓库空间不足时无法制造。"
		button.pressed.connect(_craft.bind(item))
		row.add_child(button)
		craft_list.add_child(row)

func _craft(item: StationCraftItemDefinition) -> void:
	var run_state := _run_state()
	if run_state != null and bool(run_state.call("craft_station_item", item)):
		status.text = "制造完成：%s，已送入仓库。" % item.get_contents_label()
	else:
		status.text = "制造失败：零件不足、仓库空间不足或配置无效。"
	_refresh()

func _open_refit() -> void:
	if _run_state() == null:
		return
	get_tree().set_meta(RUN_REFIT_META, true)
	get_tree().set_meta(&"refit_return_scene", "res://game/run/station/station_screen.tscn")
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)

func _leave_station() -> void:
	var run_state := _run_state()
	if run_state != null and bool(run_state.call("is_route_active")):
		var node := run_state.call("get_current_route_node") as RunRouteNodeDefinition
		if node != null and node.node_type == RunRouteNodeDefinition.NodeType.REFIT:
			run_state.call("complete_current_route_node")
	get_tree().change_scene_to_file(ROUTE_MAP_SCENE_PATH)
