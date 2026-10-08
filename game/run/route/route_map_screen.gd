extends Control

const BATTLE_SCENE_PATH := "res://game/combat/battle.tscn"
const SHOP_SCENE_PATH := "res://game/run/shop/shop_screen.tscn"
const EDITOR_SCENE_PATH := "res://game/ship/editor/ship_editor.tscn"
const STATION_SCENE_PATH := "res://game/run/station/station_screen.tscn"
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
		title.text = "ADVANCE FOUR · 星际导航"
		status.text = "SECTOR 01 | 战术星图预览"
		hint.text = "点击「配置飞船」进入机库，完成设计后启动本次航行。"
		warehouse_button.text = "配置飞船 / 开始游戏"
		warehouse_button.disabled = false
		_rebuild_map(RouteMapGenerator.generate(20261008))
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
	hint.text = "拖动横向滚动条探索星图；选择青色节点跃迁。航线不可回退。" if route.route_id == &"generated_sector" else "选择高亮节点继续前进。路线一旦选择，本层另一分支将不可返回。"
	_rebuild_map(route)

func _rebuild_map(route: RunRouteDefinition) -> void:
	var procedural := route.route_id == &"generated_sector"
	if procedural and map_area.get_parent() is not ScrollContainer:
		var frame := map_area.get_parent()
		var scroller := ScrollContainer.new()
		scroller.name = "StarMapScroll"
		scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		frame.add_child(scroller)
		map_area.reparent(scroller)
	if procedural:
		map_area.custom_minimum_size = Vector2(2050, 540)
	for child in map_area.get_children():
		map_area.remove_child(child)
		child.queue_free()

	var run_state := _run_state()
	var active := run_state != null and bool(run_state.call("is_route_active"))
	var available: Array[StringName] = run_state.call("get_available_route_node_ids") if active else []
	var completed: Array = run_state.get("completed_route_nodes") if active else []
	var current_id := StringName(run_state.get("current_route_node_id")) if active else &""

	if procedural:
		_draw_starfield()
	for raw_node in route.nodes:
		var node := raw_node as RunRouteNodeDefinition
		if node == null:
			continue
		for next_id in node.next_node_ids:
			var next_node := route.get_node(next_id)
			if next_node == null:
				continue
			var line := Line2D.new()
			line.width = 3.0 if procedural else 3.0
			line.antialiased = true
			var traveled := completed.has(node.node_id) and (completed.has(next_id) or current_id == next_id)
			var reachable := available.has(next_id) and current_id == node.node_id
			line.default_color = (Color(0.15, 0.95, 1.0, 0.95) if traveled else Color(0.18, 0.75, 0.92, 0.85) if reachable else Color(0.17, 0.38, 0.53, 0.55)) if procedural else Color(0.4, 0.45, 0.55, 0.7)
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
		button.tooltip_text = _get_node_tooltip(node) if active else "地图预览：配置飞船后可开始航行"
		button.pressed.connect(_select_node.bind(node.node_id))
		if procedural:
			_style_holographic_node(button, node, completed.has(node.node_id), available.has(node.node_id), node.node_id == current_id)
		map_area.add_child(button)


func _draw_starfield() -> void:
	# Lightweight, deterministic starfield; no external textures are needed.
	var rng := RandomNumberGenerator.new()
	rng.seed = 81421
	for i in range(115):
		var dot := ColorRect.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(rng.randf_range(0, 2040), rng.randf_range(4, 525))
		var radius := rng.randf_range(1.0, 2.5)
		dot.size = Vector2(radius, radius)
		dot.color = Color(0.35, 0.82, 1.0, rng.randf_range(0.15, 0.55))
		map_area.add_child(dot)


func _style_holographic_node(button: Button, node: RunRouteNodeDefinition, visited: bool, selectable: bool, current: bool) -> void:
	var tint := Color("#36566c")
	if visited:
		tint = Color("#29a7b9")
	elif selectable:
		tint = Color("#37eaff")
	elif current:
		tint = Color("#86efff")
	elif node.node_type == RunRouteNodeDefinition.NodeType.END:
		tint = Color("#e78a74")
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.025, 0.085, 0.15, 0.94)
	panel.border_color = tint
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(12)
	panel.shadow_color = Color(tint.r, tint.g, tint.b, 0.24 if selectable else 0.08)
	panel.shadow_size = 8 if selectable else 3
	button.add_theme_stylebox_override("normal", panel)
	button.add_theme_stylebox_override("disabled", panel)
	var hovered := panel.duplicate() as StyleBoxFlat
	hovered.bg_color = Color(0.07, 0.24, 0.34, 0.98)
	button.add_theme_stylebox_override("hover", hovered)
	button.add_theme_stylebox_override("pressed", hovered)
	button.add_theme_color_override("font_color", tint)
	button.add_theme_color_override("font_disabled_color", tint)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 13)


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
