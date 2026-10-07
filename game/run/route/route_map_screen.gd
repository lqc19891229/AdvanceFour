extends Control

const BATTLE_SCENE_PATH := "res://game/combat/battle.tscn"
const SHOP_SCENE_PATH := "res://game/run/shop/shop_screen.tscn"
const EDITOR_SCENE_PATH := "res://game/ship/editor/ship_editor.tscn"
const WAREHOUSE_SCENE_PATH := "res://game/run/warehouse/warehouse_screen.tscn"
const BATTLE_DEFINITION_META := &"battle_definition_path"
const RUN_REFIT_META := &"run_refit_mode"

@onready var title: Label = $Margin/Layout/Header/Title
@onready var status: Label = $Margin/Layout/Header/Status
@onready var map_area: Control = $Margin/Layout/MapFrame/MapArea
@onready var hint: Label = $Margin/Layout/Hint
@onready var warehouse_button: Button = $Margin/Layout/Actions/Warehouse

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	warehouse_button.pressed.connect(_open_warehouse)
	_refresh()

func _refresh() -> void:
	var run_state := _run_state()
	if run_state == null or not bool(run_state.call("is_route_active")):
		title.text = "没有进行中的航线"
		status.text = ""
		hint.text = "请从飞船编辑器开始新的 Run。"
		return
	var route := run_state.get("route_definition") as RunRouteDefinition
	var current := run_state.call("get_current_route_node") as RunRouteNodeDefinition
	title.text = route.display_name
	status.text = "能量结晶：%d｜零件：%d｜仓库：%d / %d｜当前节点：%s" % [
		int(run_state.get("energy_crystals")),
		int(run_state.get("parts")),
		int(run_state.call("get_warehouse_used")),
		int(run_state.call("get_warehouse_capacity")),
		"无" if current == null else current.display_name
	]
	hint.text = "选择高亮节点继续前进。路线一旦选择，本层另一分支将不可返回。"
	_rebuild_map(route)

func _rebuild_map(route: RunRouteDefinition) -> void:
	for child in map_area.get_children():
		map_area.remove_child(child)
		child.queue_free()

	var run_state := _run_state()
	var available: Array[StringName] = run_state.call("get_available_route_node_ids")
	var completed: Array = run_state.get("completed_route_nodes")
	var current_id := StringName(run_state.get("current_route_node_id"))

	for raw_node in route.nodes:
		var node := raw_node as RunRouteNodeDefinition
		if node == null:
			continue
		for next_id in node.next_node_ids:
			var next_node := route.get_node(next_id)
			if next_node == null:
				continue
			var line := Line2D.new()
			line.width = 3.0
			line.default_color = Color(0.4, 0.45, 0.55, 0.7)
			line.points = PackedVector2Array([
				node.map_position + Vector2(65, 25),
				next_node.map_position + Vector2(65, 25)
			])
			map_area.add_child(line)

	for raw_node in route.nodes:
		var node := raw_node as RunRouteNodeDefinition
		if node == null:
			continue
		var button := Button.new()
		button.position = node.map_position
		button.custom_minimum_size = Vector2(130, 50)
		button.size = Vector2(130, 50)
		var prefix := ""
		if completed.has(node.node_id):
			prefix = "✓ "
		elif node.node_id == current_id:
			prefix = "● "
		elif available.has(node.node_id):
			prefix = "▶ "
		button.text = "%s%s\n[%s]" % [prefix, node.display_name, node.get_type_label()]
		button.disabled = not available.has(node.node_id)
		button.tooltip_text = _get_node_tooltip(node)
		button.pressed.connect(_select_node.bind(node.node_id))
		map_area.add_child(button)

func _get_node_tooltip(node: RunRouteNodeDefinition) -> String:
	match node.node_type:
		RunRouteNodeDefinition.NodeType.BATTLE:
			return "进入战斗节点。胜利后返回战果页。"
		RunRouteNodeDefinition.NodeType.SHOP:
			return "进入补给商店，用能量结晶购买模块或 Hull。"
		RunRouteNodeDefinition.NodeType.REFIT:
			return "进入整备站，使用当前 Run Inventory 改装飞船。"
		RunRouteNodeDefinition.NodeType.END:
			return "完成当前 Prototype 航线并返回飞船编辑器。"
	return ""

func _select_node(node_id: StringName) -> void:
	var run_state := _run_state()
	if run_state == null or not bool(run_state.call("select_route_node", node_id)):
		return
	var node := run_state.call("get_current_route_node") as RunRouteNodeDefinition
	if node == null:
		return
	match node.node_type:
		RunRouteNodeDefinition.NodeType.BATTLE:
			get_tree().set_meta(BATTLE_DEFINITION_META, node.target_path)
			get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
		RunRouteNodeDefinition.NodeType.SHOP:
			get_tree().change_scene_to_file(SHOP_SCENE_PATH)
		RunRouteNodeDefinition.NodeType.REFIT:
			get_tree().set_meta(RUN_REFIT_META, true)
			get_tree().change_scene_to_file(EDITOR_SCENE_PATH)
		RunRouteNodeDefinition.NodeType.END:
			run_state.call("complete_current_route_node")
			run_state.call("reset_run")
			get_tree().set_meta(&"restore_ship_design", true)
			get_tree().change_scene_to_file(EDITOR_SCENE_PATH)


func _open_warehouse() -> void:
	var run_state := _run_state()
	if run_state == null or not bool(run_state.call("is_route_active")):
		return
	get_tree().change_scene_to_file(WAREHOUSE_SCENE_PATH)
