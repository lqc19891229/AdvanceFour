extends Control

const BATTLE_SCENE_PATH := "res://game/combat/battle.tscn"
const SHOP_SCENE_PATH := "res://game/run/shop/shop_screen.tscn"
const EDITOR_SCENE_PATH := "res://game/ship/editor/ship_editor.tscn"
const STATION_SCENE_PATH := "res://game/run/station/station_screen.tscn"
const WAREHOUSE_SCENE_PATH := "res://game/run/warehouse/warehouse_screen.tscn"
const BATTLE_DEFINITION_META := &"battle_definition_path"
const RUN_REFIT_META := &"run_refit_mode"

@onready var top_bar: HBoxContainer = $Margin/Layout/Header/TopBar
@onready var status: Label = $Margin/Layout/Header/Status
@onready var map_scroll: ScrollContainer = $Margin/Layout/MapFrame/MapScroll
@onready var map_area: Control = $Margin/Layout/MapFrame/MapScroll/MapArea
@onready var hint: Label = $Margin/Layout/Hint
@onready var warehouse_button: Button = $Margin/Layout/Actions/Warehouse

const NODE_SCENE := preload("res://game/run/route/route_node_view.tscn")
const BACKGROUND_ART := preload("res://data/assets/ui/star_map_background.svg")
const NODE_SIZE := Vector2(160, 90)
const MAP_PADDING := Vector2(100, 90)
var map_content_size := Vector2.ZERO

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	warehouse_button.pressed.connect(_open_warehouse)
	var edit_button := Button.new()
	edit_button.text = "编辑飞船"
	edit_button.custom_minimum_size = Vector2(180, 44)
	edit_button.pressed.connect(_open_editor)
	$Margin/Layout/Actions.add_child(edit_button)
	map_scroll.resized.connect(_update_map_size)
	_refresh()

func _refresh() -> void:
	var run_state := _run_state()
	if run_state == null:
		hint.text = "RunState 不可用"
		return
	if not bool(run_state.call("is_route_active")):
		var design := Battle.build_starter_design()
		var save_path := "user://ships/test_ship.json"
		if FileAccess.file_exists(save_path):
			var loaded := ShipSerializer.load_from_file(save_path, preload("res://data/modules/module_database.tres"))
			if bool(loaded.get("ok", false)) and (loaded.get("ship") as ShipData).is_design_valid():
				design = loaded["ship"] as ShipData
		if not bool(run_state.call("start_run_with_test_route", design)):
			hint.text = "无法载入测试星图，请检查飞船数据。"
			return
	var route := run_state.get("route_definition") as RunRouteDefinition
	var current := run_state.call("get_current_route_node") as RunRouteNodeDefinition
	top_bar.call("update_resources", int(run_state.get("energy_crystals")), int(run_state.get("parts")), route.display_name)
	status.text = "仓库：%d / %d    ｜    当前节点：%s" % [int(run_state.call("get_warehouse_used")), int(run_state.call("get_warehouse_capacity")), "无" if current == null else current.display_name]
	hint.text = "固定测试航线：商店 → 维修站 → 战斗。点击当前节点进入，飞船编辑与战斗入口分离。" if route.route_id == &"fixed_test_sector" else "选择高亮节点继续前进。路线一旦选择，本层另一分支将不可返回。"
	_rebuild_map(route)

func _rebuild_map(route: RunRouteDefinition) -> void:
	var procedural := route.route_id == &"generated_sector" or route.route_id == &"fixed_test_sector"
	map_content_size = _calculate_map_content_size(route)
	_update_map_size()
	for child in map_area.get_children():
		map_area.remove_child(child)
		child.queue_free()

	var run_state := _run_state()
	var active := run_state != null and bool(run_state.call("is_route_active"))
	var available: Array[StringName] = []
	var completed: Array = []
	var current_id: StringName = &""
	if active:
		available.assign(run_state.call("get_available_route_node_ids"))
		if not bool(run_state.call("is_current_route_node_complete")):
			available.append(StringName(run_state.get("current_route_node_id")))
		completed = run_state.get("completed_route_nodes")
		current_id = StringName(run_state.get("current_route_node_id"))

	if procedural:
		_draw_starfield(map_area.custom_minimum_size)
	for raw_node in route.nodes:
		var node := raw_node as RunRouteNodeDefinition
		if node == null:
			continue
		for next_id in node.next_node_ids:
			var next_node := route.get_node(next_id)
			if next_node == null:
				continue
			var line := Line2D.new()
			line.width = 5.0 if procedural else 3.0
			line.antialiased = true
			var traveled := completed.has(node.node_id) and (completed.has(next_id) or current_id == next_id)
			var reachable := available.has(next_id) and current_id == node.node_id
			line.default_color = (Color(0.15, 0.95, 1.0, 0.95) if traveled else Color(0.18, 0.75, 0.92, 0.85) if reachable else Color(0.17, 0.38, 0.53, 0.55)) if procedural else Color(0.4, 0.45, 0.55, 0.7)
			line.points = PackedVector2Array([
				node.map_position + NODE_SIZE * 0.5,
				next_node.map_position + NODE_SIZE * 0.5
			])
			map_area.add_child(line)

	for raw_node in route.nodes:
		var node := raw_node as RunRouteNodeDefinition
		if node == null:
			continue
		var button := NODE_SCENE.instantiate() as Button
		button.position = node.map_position
		button.call("configure", node, completed.has(node.node_id), available.has(node.node_id), node.node_id == current_id)
		button.connect("route_selected", _select_node)
		map_area.add_child(button)


func _calculate_map_content_size(route: RunRouteDefinition) -> Vector2:
	var extent := Vector2.ZERO
	for raw_node in route.nodes:
		var node := raw_node as RunRouteNodeDefinition
		if node != null:
			extent = extent.max(node.map_position + NODE_SIZE)
	return extent + MAP_PADDING

func _update_map_size() -> void:
	if not is_node_ready():
		return
	map_area.custom_minimum_size = Vector2(maxf(map_content_size.x, map_scroll.size.x), maxf(map_content_size.y, map_scroll.size.y))

func _draw_starfield(canvas_size: Vector2) -> void:
	# Background artwork is a separate static texture, with optional dynamic debris on top.
	var background := TextureRect.new()
	background.texture = BACKGROUND_ART
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.position = Vector2.ZERO
	background.size = canvas_size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_area.add_child(background)
	var rng := RandomNumberGenerator.new()
	rng.seed = 81421
	for i in range(85):
		var dot := ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(rng.randf_range(0, canvas_size.x), rng.randf_range(0, canvas_size.y))
		var radius := float(rng.randi_range(1, 3))
		dot.size = Vector2(radius, radius)
		dot.color = Color(0.35, 0.82, 1.0, rng.randf_range(0.15, 0.65))
		map_area.add_child(dot)
	for i in range(24):
		var asteroid := ColorRect.new()
		asteroid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		asteroid.position = Vector2(rng.randf_range(0, 2045), rng.randf_range(0, 530))
		var size := float(rng.randi_range(4, 12))
		asteroid.size = Vector2(size, size)
		asteroid.color = Color("#30445e")
		map_area.add_child(asteroid)


func _get_node_tooltip(node: RunRouteNodeDefinition) -> String:
	match node.node_type:
		RunRouteNodeDefinition.NodeType.BATTLE:
			return "进入战斗节点。胜利后返回战果页。"
		RunRouteNodeDefinition.NodeType.SHOP:
			return "进入补给商店，用能量结晶购买模块或 Hull。"
		RunRouteNodeDefinition.NodeType.REFIT:
			return "进入维修改装空间站：免费维修至满血，可用零件制造模块并进入飞船改装。"
		RunRouteNodeDefinition.NodeType.END:
			return "完成当前 Prototype 航线并返回飞船编辑器。"
	return ""

func _select_node(node_id: StringName) -> void:
	var run_state := _run_state()
	if run_state == null:
		return
	var is_current := StringName(run_state.get("current_route_node_id")) == node_id
	if not is_current and not bool(run_state.call("select_route_node", node_id)):
		return
	if is_current and bool(run_state.call("is_current_route_node_complete")):
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
			get_tree().change_scene_to_file(STATION_SCENE_PATH)
		RunRouteNodeDefinition.NodeType.END:
			run_state.call("complete_current_route_node")
			run_state.call("reset_run")
			get_tree().set_meta(&"restore_ship_design", true)
			get_tree().change_scene_to_file(EDITOR_SCENE_PATH)


func _open_warehouse() -> void:
	var run_state := _run_state()
	if run_state == null or not bool(run_state.call("is_route_active")):
		get_tree().change_scene_to_file(EDITOR_SCENE_PATH)
		return
	get_tree().change_scene_to_file(WAREHOUSE_SCENE_PATH)


func _open_editor() -> void:
	var run_state := _run_state()
	if run_state != null and bool(run_state.call("is_route_active")):
		get_tree().set_meta(RUN_REFIT_META, true)
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)
