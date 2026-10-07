extends Control

const ROUTE_MAP_SCENE_PATH := "res://game/run/route/route_map_screen.tscn"
const EDITOR_SCENE_PATH := "res://game/ship/editor/ship_editor.tscn"
const STATION_SCENE_PATH := "res://game/run/station/station_screen.tscn"
const RUN_REFIT_META := &"run_refit_mode"
const DATABASE := preload("res://data/modules/module_database.tres")

var filter_type := -1
var selected_module_id: StringName = &""

@onready var capacity_label: Label = $Margin/Layout/Header/Capacity
@onready var warning_label: Label = $Margin/Layout/Header/Warning
@onready var item_list: VBoxContainer = $Margin/Layout/Body/InventoryPanel/InventoryMargin/InventoryLayout/ItemScroll/ItemList
@onready var empty_label: Label = $Margin/Layout/Body/InventoryPanel/InventoryMargin/InventoryLayout/Empty
@onready var detail_texture: TextureRect = $Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/Texture
@onready var detail_name: Label = $Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/Name
@onready var detail_type: Label = $Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/Type
@onready var detail_body: Label = $Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/Body
@onready var hull_label: Label = $Margin/Layout/Footer/Hull
@onready var refit_button: Button = $Margin/Layout/Footer/Refit
@onready var return_button: Button = $Margin/Layout/Footer/Return

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	$Margin/Layout/Filters/All.pressed.connect(_set_filter.bind(-1))
	$Margin/Layout/Filters/Weapon.pressed.connect(_set_filter.bind(ShipModuleDefinition.ModuleType.WEAPON))
	$Margin/Layout/Filters/Energy.pressed.connect(_set_filter.bind(ShipModuleDefinition.ModuleType.ENERGY))
	$Margin/Layout/Filters/Propulsion.pressed.connect(_set_filter.bind(ShipModuleDefinition.ModuleType.PROPULSION))
	$Margin/Layout/Filters/Defense.pressed.connect(_set_filter.bind(ShipModuleDefinition.ModuleType.DEFENSE))
	$Margin/Layout/Filters/Function.pressed.connect(_set_filter.bind(ShipModuleDefinition.ModuleType.FUNCTION))
	$Margin/Layout/Filters/Core.pressed.connect(_set_filter.bind(ShipModuleDefinition.ModuleType.CORE))
	refit_button.pressed.connect(_open_refit)
	return_button.pressed.connect(_return_to_route)
	_refresh()

func _refresh() -> void:
	var run_state := _run_state()
	if run_state == null or not run_state.run_active:
		capacity_label.text = "没有进行中的 Run"
		warning_label.text = ""
		refit_button.disabled = true
		_rebuild_inventory()
		return

	var used := int(run_state.call("get_warehouse_used"))
	var capacity := int(run_state.call("get_warehouse_capacity"))
	var remaining := capacity - used
	capacity_label.text = "能量结晶：%d｜零件：%d｜模块仓库：%d / %d｜剩余：%d" % [int(run_state.get("energy_crystals")), int(run_state.get("parts")), used, capacity, maxi(remaining, 0)]
	if remaining < 0:
		warning_label.text = "仓库超载 %d：无法购买或领取新的模块。" % -remaining
	else:
		warning_label.text = ""
	hull_label.text = "Hull：%d（不占模块仓储）" % int(run_state.get("hull_stock"))
	refit_button.disabled = _find_refit_node_id() == &""
	_rebuild_inventory()

func _set_filter(module_type: int) -> void:
	filter_type = module_type
	selected_module_id = &""
	_rebuild_inventory()

func _rebuild_inventory() -> void:
	for child in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()

	var run_state := _run_state()
	if run_state == null or not run_state.run_active:
		empty_label.visible = true
		empty_label.text = "当前没有可查看的仓库。"
		_clear_detail()
		return

	var inventory: Dictionary = run_state.get("module_inventory")
	var entries: Array[ShipModuleDefinition] = []
	for raw_id in inventory.keys():
		var definition := DATABASE.get_by_id(StringName(raw_id))
		if definition == null:
			continue
		if filter_type >= 0 and int(definition.module_type) != filter_type:
			continue
		entries.append(definition)
	entries.sort_custom(func(a: ShipModuleDefinition, b: ShipModuleDefinition) -> bool:
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0
	)

	empty_label.visible = entries.is_empty()
	empty_label.text = "当前分类没有模块。"
	for definition in entries:
		var count := int(inventory.get(definition.id, 0))
		var total_storage := int(run_state.call("get_module_storage_cost", definition.id, count))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 72)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s  ×%d\n%s｜%d×%d｜总占用 %d" % [
			definition.display_name,
			count,
			definition.get_type_name(),
			definition.size.x,
			definition.size.y,
			total_storage
		]
		button.icon = definition.texture
		button.expand_icon = true
		button.pressed.connect(_select_module.bind(definition.id))
		item_list.add_child(button)

	if selected_module_id != &"" and inventory.has(selected_module_id):
		var selected := DATABASE.get_by_id(selected_module_id)
		if selected != null and (filter_type < 0 or int(selected.module_type) == filter_type):
			_show_detail(selected)
			return
	if entries.is_empty():
		_clear_detail()
	else:
		selected_module_id = entries[0].id
		_show_detail(entries[0])

func _select_module(module_id: StringName) -> void:
	selected_module_id = module_id
	var definition := DATABASE.get_by_id(module_id)
	if definition != null:
		_show_detail(definition)

func _show_detail(definition: ShipModuleDefinition) -> void:
	var run_state := _run_state()
	if run_state == null:
		_clear_detail()
		return
	var count := int(run_state.call("get_module_inventory_count", definition.id))
	var unit_storage := definition.get_storage_cost()
	detail_texture.texture = definition.texture
	detail_name.text = definition.display_name
	detail_type.text = definition.get_type_name()
	var lines: Array[String] = []
	lines.append("尺寸：%d×%d" % [definition.size.x, definition.size.y])
	lines.append("单件仓储：%d" % unit_storage)
	lines.append("库存数量：%d" % count)
	lines.append("总仓储占用：%d" % (unit_storage * count))
	lines.append("能耗：%.1f" % definition.energy_cost)
	lines.append("")
	lines.append(definition.description)
	lines.append("")

	if definition is WeaponModuleDefinition:
		var weapon := definition as WeaponModuleDefinition
		lines.append("火力：%.1f" % weapon.firepower)
		lines.append("射程：%.1f" % weapon.attack_range)
		lines.append("射击间隔：%.2f 秒" % weapon.fire_interval)
		lines.append("炮塔转速：%.1f°/秒" % weapon.turn_speed_degrees)
		lines.append("弹速：%.1f px/s" % weapon.projectile_speed)
		lines.append("射界：%.1f°" % weapon.firing_arc_degrees)
	elif definition is EnergyModuleDefinition:
		lines.append("供能：%.1f" % (definition as EnergyModuleDefinition).energy_output)
	elif definition is PropulsionModuleDefinition:
		lines.append("推力：%.1f" % (definition as PropulsionModuleDefinition).thrust)
	elif definition is DefenseModuleDefinition:
		var defense := definition as DefenseModuleDefinition
		lines.append("装甲 HP：%.1f" % defense.hp)
		lines.append("防护：%.1f" % defense.protection)
	elif definition is FunctionModuleDefinition:
		var function_module := definition as FunctionModuleDefinition
		if function_module.storage_capacity > 0:
			lines.append("安装后仓储容量：+%d" % function_module.storage_capacity)
			lines.append("净仓储贡献：+%d" % (function_module.storage_capacity - unit_storage))
		else:
			lines.append("功能模块：暂无额外参数")
	elif definition is CoreModuleDefinition:
		lines.append("核心模块：核心覆盖 Hull 全部损毁时飞船沉没")

	detail_body.text = "\n".join(lines)

func _clear_detail() -> void:
	detail_texture.texture = null
	detail_name.text = "未选择模块"
	detail_type.text = ""
	detail_body.text = "从左侧仓库列表选择一个模块查看详细信息。"

func _find_refit_node_id() -> StringName:
	var run_state := _run_state()
	if run_state == null or not bool(run_state.call("is_route_active")):
		return &""
	var current := run_state.call("get_current_route_node") as RunRouteNodeDefinition
	if current != null and current.node_type == RunRouteNodeDefinition.NodeType.REFIT:
		return current.node_id
	var available: Array[StringName] = run_state.call("get_available_route_node_ids")
	var route := run_state.get("route_definition") as RunRouteDefinition
	if route == null:
		return &""
	for node_id in available:
		var node := route.get_node(node_id)
		if node != null and node.node_type == RunRouteNodeDefinition.NodeType.REFIT:
			return node_id
	return &""

func _open_refit() -> void:
	var run_state := _run_state()
	var refit_id := _find_refit_node_id()
	if run_state == null or refit_id == &"":
		return
	var current := run_state.call("get_current_route_node") as RunRouteNodeDefinition
	if current == null or current.node_id != refit_id:
		if not bool(run_state.call("select_route_node", refit_id)):
			return
	get_tree().change_scene_to_file(STATION_SCENE_PATH)

func _return_to_route() -> void:
	get_tree().change_scene_to_file(ROUTE_MAP_SCENE_PATH)
