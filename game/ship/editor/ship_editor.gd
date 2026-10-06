extends Control

const SAVE_PATH := "user://ships/test_ship.json"
const RUNTIME_SCENE := preload("res://game/ship/runtime/ship_runtime.tscn")
const BATTLE_SCENE_PATH := "res://game/combat/battle.tscn"
const FIRST_BATTLE_DEFINITION_PATH := "res://data/battles/stage_001.tres"
const PROTOTYPE_ROUTE_PATH := "res://data/routes/prototype_route.tres"
const ROUTE_MAP_SCENE_PATH := "res://game/run/route/route_map_screen.tscn"
const BATTLE_DEFINITION_META := &"battle_definition_path"
const RUN_REFIT_META := &"run_refit_mode"

@onready var grid: ShipGridView = $MainLayout/Center/Grid
@onready var module_buttons: VBoxContainer = $MainLayout/LeftPanel/LeftMargin/LeftVBox/ModuleButtons
@onready var stats_label: Label = $MainLayout/RightPanel/RightMargin/RightVBox/StatsScroll/StatsLabel
@onready var speed_label: Label = $MainLayout/RightPanel/RightMargin/RightVBox/SpeedLabel
@onready var status_label: Label = $BottomBar/BottomMargin/StatusLabel
@onready var selected_label: Label = $MainLayout/LeftPanel/LeftMargin/LeftVBox/SelectedLabel

var run_refit_mode := false

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	_build_module_buttons()
	_bind_common_buttons()
	grid.ship_changed.connect(_on_grid_ship_changed)
	grid.selected_module_changed.connect(_on_selected_module_changed)
	grid.status_message.connect(_show_status)
	_refresh_selected_label()
	_refresh_stats()
	_show_status("先铺船体再安装设备｜左键放置/选中｜右键拆除｜R 旋转｜中键拖动画布")
	if get_tree().has_meta(RUN_REFIT_META):
		get_tree().remove_meta(RUN_REFIT_META)
		run_refit_mode = _run_state() != null and _run_state().run_active and _run_state().current_ship != null
		if run_refit_mode:
			grid.set_run_inventory_enabled(true)
			_load_run_ship()
			var current_node := _run_state().call("get_current_route_node") as RunRouteNodeDefinition
			if bool(_run_state().call("is_route_active")) and current_node != null and current_node.node_type == RunRouteNodeDefinition.NodeType.REFIT:
				$MainLayout/RightPanel/RightMargin/RightVBox/BattleButton.text = "完成整备并返回星图"
			else:
				$MainLayout/RightPanel/RightMargin/RightVBox/BattleButton.text = "继续下一战"
			$MainLayout/RightPanel/RightMargin/RightVBox/AITestButton.disabled = true
			$MainLayout/RightPanel/RightMargin/RightVBox/ClearButton.disabled = true
			_refresh_inventory_button_labels()
			_show_status("Run 整备模式｜Credits：%d｜模块/Hull 安装受库存限制" % _run_state().currency)
	elif get_tree().has_meta(&"restore_ship_design"):
		get_tree().remove_meta(&"restore_ship_design")
		if FileAccess.file_exists(SAVE_PATH):
			_load_ship()


func _on_grid_ship_changed() -> void:
	if run_refit_mode and _run_state() != null:
		_run_state().call("update_current_ship", grid.ship)
	_refresh_stats()
	_refresh_inventory_button_labels()

func _refresh_inventory_button_labels() -> void:
	if not run_refit_mode or _run_state() == null:
		return
	for child in module_buttons.get_children():
		if not (child is Button):
			continue
		var button := child as Button
		var kind := StringName(button.get_meta(&"inventory_kind", &""))
		if kind == &"hull":
			button.text = "船体｜基础船体格｜库存 %d" % int(_run_state().get("hull_stock"))
		elif kind == &"module":
			var module_id := StringName(button.get_meta(&"module_id", &""))
			var definition := grid.definitions.get(String(module_id), null) as ShipModuleDefinition
			if definition != null:
				button.text = "%s｜%s｜库存 %d" % [
					definition.get_type_name(),
					definition.display_name,
					int(_run_state().call("get_module_inventory_count", module_id))
				]

func _build_inventory_summary() -> String:
	if not run_refit_mode or _run_state() == null:
		return ""
	var lines: Array[String] = []
	lines.append("Run 库存")
	lines.append("Hull：%d" % int(_run_state().get("hull_stock")))
	var inventory: Dictionary = _run_state().get("module_inventory")
	if inventory.is_empty():
		lines.append("模块：无")
	else:
		lines.append("模块：")
		var ids := inventory.keys()
		ids.sort()
		for raw_id in ids:
			var module_id := StringName(raw_id)
			var definition := grid.definitions.get(String(module_id), null) as ShipModuleDefinition
			var display_name := String(module_id) if definition == null else definition.display_name
			lines.append("- %s ×%d" % [display_name, int(inventory[module_id])])
	return "\n".join(lines)

func _build_module_buttons() -> void:
	for child in module_buttons.get_children():
		child.queue_free()

	var hull_button := Button.new()
	hull_button.set_meta(&"inventory_kind", &"hull")
	hull_button.custom_minimum_size = Vector2(0, 44)
	hull_button.text = "船体｜基础船体格"
	hull_button.tooltip_text = "Hull Layout：每格独立 20 HP、质量 2。设备必须完整安装在船体格上。"
	hull_button.pressed.connect(_select_hull)
	module_buttons.add_child(hull_button)

	for definition in grid.get_all_definitions():
		var button := Button.new()
		button.set_meta(&"inventory_kind", &"module")
		button.set_meta(&"module_id", definition.id)
		button.custom_minimum_size = Vector2(0, 44)
		button.text = "%s｜%s" % [definition.get_type_name(), definition.display_name]
		button.tooltip_text = _build_module_tooltip(definition)
		button.pressed.connect(func(): _select(String(definition.id)))
		module_buttons.add_child(button)

func _build_module_tooltip(definition: ShipModuleDefinition) -> String:
	var lines: Array[String] = []
	lines.append(definition.description)
	lines.append("尺寸：%d×%d" % [definition.size.x, definition.size.y])
	lines.append("耗能：%.1f" % definition.energy_cost)

	if definition is EnergyModuleDefinition:
		lines.append("供能：%.1f" % (definition as EnergyModuleDefinition).energy_output)
	elif definition is PropulsionModuleDefinition:
		lines.append("动力：%.1f" % (definition as PropulsionModuleDefinition).thrust)
	elif definition is WeaponModuleDefinition:
		var weapon := definition as WeaponModuleDefinition
		lines.append("火力：%.1f" % weapon.firepower)
		lines.append("射程：%.1f" % weapon.attack_range)
		lines.append("射击间隔：%.2f 秒" % weapon.fire_interval)
		lines.append("炮塔转速：%.1f°/秒" % weapon.turn_speed_degrees)
		lines.append("弹速：%.1f px/s" % weapon.projectile_speed)
		lines.append("射界：%.1f°" % weapon.firing_arc_degrees)
		lines.append("开火角容差：%.1f°" % weapon.fire_angle_tolerance_degrees)
	elif definition is DefenseModuleDefinition:
		var defense := definition as DefenseModuleDefinition
		lines.append("装甲 HP：%.1f" % defense.hp)
		lines.append("防护：%.1f" % defense.protection)
	elif definition is FunctionModuleDefinition:
		lines.append("功能模块：暂无额外参数")
	elif definition is CoreModuleDefinition:
		lines.append("核心模块：被击毁时判定沉没")

	return "\n".join(lines)

func _bind_common_buttons() -> void:
	$MainLayout/RightPanel/RightMargin/RightVBox/SaveButton.pressed.connect(_save_ship)
	$MainLayout/RightPanel/RightMargin/RightVBox/LoadButton.pressed.connect(_load_ship)
	$MainLayout/RightPanel/RightMargin/RightVBox/MoveButton.pressed.connect(grid.begin_move_selected)
	$MainLayout/RightPanel/RightMargin/RightVBox/RotateButton.pressed.connect(grid.rotate_selection_or_preview)
	$MainLayout/RightPanel/RightMargin/RightVBox/CenterButton.pressed.connect(grid.center_view)
	$MainLayout/RightPanel/RightMargin/RightVBox/ClearButton.pressed.connect(grid.clear_ship)
	$MainLayout/RightPanel/RightMargin/RightVBox/AITestButton.pressed.connect(_start_ai_test)
	$MainLayout/RightPanel/RightMargin/RightVBox/BattleButton.pressed.connect(_start_battle)

func _start_battle() -> void:
	if not _save_design_for_departure():
		return
	if run_refit_mode:
		var run_state := _run_state()
		if run_state != null and bool(run_state.call("is_route_active")):
			var node := run_state.call("get_current_route_node") as RunRouteNodeDefinition
			if node != null and node.node_type == RunRouteNodeDefinition.NodeType.REFIT:
				run_state.call("complete_current_route_node")
				get_tree().change_scene_to_file(ROUTE_MAP_SCENE_PATH)
				return
		var battle_path := String(run_state.call("advance_to_next_battle"))
		if battle_path.is_empty():
			_show_status("当前 Run 已没有下一场战斗。")
			return
		get_tree().set_meta(BATTLE_DEFINITION_META, battle_path)
		get_tree().change_scene_to_file(BATTLE_SCENE_PATH)
		return

	var run_state := _run_state()
	if run_state == null or not bool(run_state.call("start_run_with_route", grid.ship, PROTOTYPE_ROUTE_PATH)):
		_show_status("无法创建星系航线 Run。")
		return
	var start_node := run_state.call("get_current_route_node") as RunRouteNodeDefinition
	if start_node == null or start_node.node_type != RunRouteNodeDefinition.NodeType.BATTLE:
		_show_status("航线起点不是有效战斗节点。")
		run_state.call("reset_run")
		return
	get_tree().set_meta(BATTLE_DEFINITION_META, start_node.target_path)
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)

func _start_ai_test() -> void:
	_start_scene_with_design("res://game/ship/dev/ship_ai_test.tscn")

func _start_scene_with_design(scene_path: String) -> void:
	if not _save_design_for_departure():
		return
	get_tree().change_scene_to_file(scene_path)

func _save_design_for_departure() -> bool:
	if not grid.ship.is_design_valid():
		_show_status("无法出航：%s" % grid.ship.get_design_invalid_reason())
		return false
	if run_refit_mode:
		if not _run_state().update_current_ship(grid.ship):
			_show_status("无法保存当前 Run 的整备状态。")
			return false
		return true
	var result := ShipSerializer.save_to_file(grid.ship, SAVE_PATH)
	if not result["ok"]:
		_show_status("保存失败：%s" % result["error"])
		return false
	return true

func _save_ship() -> void:
	if run_refit_mode:
		if _run_state().update_current_ship(grid.ship):
			_show_status("当前 Run 整备状态已更新｜Credits：%d" % _run_state().currency)
		else:
			_show_status("当前 Run 整备状态保存失败。")
		return
	var result := ShipSerializer.save_to_file(grid.ship, SAVE_PATH)
	if result["ok"]:
		_show_status("飞船设计已保存：%s" % SAVE_PATH)
	else:
		_show_status("保存失败：%s" % result["error"])

func _load_ship() -> void:
	if run_refit_mode:
		_load_run_ship()
		return
	var result := ShipSerializer.load_from_file(SAVE_PATH, grid.module_database)
	if result["ok"]:
		var loaded_ship := result["ship"] as ShipData
		grid.set_ship(loaded_ship)
		_show_status("飞船设计已加载：%s" % SAVE_PATH)
	else:
		_show_status("加载失败：%s" % result["error"])

func _load_run_ship() -> void:
	if _run_state() == null or not _run_state().run_active or _run_state().current_ship == null:
		_show_status("当前没有可整备的 Run 飞船。")
		return
	var cloned := ShipSerializer.from_dictionary(
		ShipSerializer.to_dictionary(_run_state().current_ship),
		grid.module_database
	)
	if not cloned["ok"]:
		_show_status("Run 飞船加载失败：%s" % cloned["error"])
		return
	grid.set_ship(cloned["ship"] as ShipData)

func _select(id: String) -> void:
	grid.select_definition(id)
	_refresh_selected_label()

func _select_hull() -> void:
	grid.select_hull()
	_refresh_selected_label()

func _refresh_selected_label() -> void:
	if grid.placing_hull:
		selected_label.text = "待放置：基础船体格"
	elif grid.selected_definition == null:
		selected_label.text = "待放置：未选择"
	else:
		selected_label.text = "待安装：%s" % grid.selected_definition.display_name

func _on_selected_module_changed(_module: ShipModuleInstance) -> void:
	_refresh_stats()

func _build_installed_module_details(module: ShipModuleInstance) -> String:
	if module == null:
		return "已选模块：无\n点击飞船上的模块查看详情。"

	var definition := module.definition
	var lines: Array[String] = []
	lines.append("已选模块：%s" % definition.display_name)
	lines.append("类型：%s" % definition.get_type_name())
	lines.append("位置：(%d, %d)" % [module.grid_position.x, module.grid_position.y])
	lines.append("旋转：%d°" % (module.rotation_quarters * 90))
	lines.append("尺寸：%d×%d" % [module.get_rotated_size().x, module.get_rotated_size().y])
	lines.append("耗能：%.1f" % definition.energy_cost)

	if definition is EnergyModuleDefinition:
		lines.append("供能：%.1f" % (definition as EnergyModuleDefinition).energy_output)
	elif definition is PropulsionModuleDefinition:
		lines.append("动力：%.1f" % (definition as PropulsionModuleDefinition).thrust)
	elif definition is WeaponModuleDefinition:
		var weapon := definition as WeaponModuleDefinition
		lines.append("火力：%.1f" % weapon.firepower)
		lines.append("射程：%.1f" % weapon.attack_range)
		lines.append("射击间隔：%.2f 秒" % weapon.fire_interval)
		lines.append("理论射速：%.2f 发/秒" % (1.0 / weapon.fire_interval))
		lines.append("理论 DPS：%.2f" % (weapon.firepower / weapon.fire_interval))
		lines.append("炮塔转速：%.1f°/秒" % weapon.turn_speed_degrees)
		lines.append("弹速：%.1f px/s" % weapon.projectile_speed)
		lines.append("射界：%.1f°" % weapon.firing_arc_degrees)
		lines.append("开火角容差：%.1f°" % weapon.fire_angle_tolerance_degrees)
	elif definition is DefenseModuleDefinition:
		var defense := definition as DefenseModuleDefinition
		lines.append("装甲 HP：%.1f" % defense.hp)
		lines.append("防护：%.1f%%" % defense.protection)
	elif definition is FunctionModuleDefinition:
		lines.append("功能：暂无额外参数")
	elif definition is CoreModuleDefinition:
		lines.append("核心规则：承载核心的船体格全部损毁时整船沉没")

	lines.append("")
	lines.append("操作：移动已选模块 / R 旋转 / 右键删除")
	return "\n".join(lines)

func _refresh_stats() -> void:
	var s := grid.ship
	var design_status := "可出航" if s.is_design_valid() else "不可出航：%s" % s.get_design_invalid_reason()
	var speed_text := "—（供能不足）"
	if s.is_energy_valid():
		var runtime := RUNTIME_SCENE.instantiate() as ShipRuntime
		var speed := runtime.estimate_design_top_speed(s)
		runtime.free()
		speed_text = "%.1f px/s" % speed
	speed_label.text = "预计最高速度：%s" % speed_text
	speed_label.tooltip_text = "完整船体、供能充足时，最高速度只由有效引擎推力 × speed_scale 决定。\nHull 受损会降低对应引擎效率，从而降低速度与加速度。"

	var selected_details := _build_installed_module_details(grid.selected_module)
	var inventory_summary := _build_inventory_summary()
	if not inventory_summary.is_empty():
		selected_details += "\n\n" + inventory_summary
	stats_label.text = """%s

────────────

飞船汇总

Hull 格：%d
Hull HP：%.0f / %.0f
Equipment：%d

能量：%.1f / %.1f
动力：%.1f
推进评分：%.1f

火力：%.1f
防御系统：%.1f

核心：%s
沉没判定：核心覆盖 Hull 全部损毁

设计状态：%s

结构规则：
Hull Layout 决定船体形状与局部 HP；
Equipment 必须完整安装在 Hull 上；
除 Defense 外 Equipment 不拥有 HP；
Defense.hp 会平均附加到其覆盖的 Hull 区域；
区域 HP = ShipHullCell HP + Defense HP；
Hull 受损会降低对应 Equipment 效率。

能量规则：
编辑时允许临时超额耗能；
出航时总耗能必须 ≤ 总供能。""" % [
		selected_details,
		s.hull_cells.size(),
		s.get_total_hull_hp(),
		s.get_total_hull_max_hp(),
		s.modules.size(),
		s.get_energy_cost(),
		s.get_energy_output(),
		s.get_thrust(),
		s.get_acceleration_score(),
		s.get_firepower(),
		s.get_protection(),
		"已安装" if s.has_core() else "未安装",
		design_status
	]

func _show_status(text: String) -> void:
	status_label.text = text
