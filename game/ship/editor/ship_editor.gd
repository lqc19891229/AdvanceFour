extends Control

const SAVE_PATH := "user://ships/test_ship.json"
const RUNTIME_SCENE := preload("res://game/ship/runtime/ship_runtime.tscn")
const BATTLE_SCENE_PATH := "res://game/combat/battle.tscn"
const FIRST_BATTLE_DEFINITION_PATH := "res://game/combat/definitions/stage_001.tres"
const BATTLE_DEFINITION_META := &"battle_definition_path"

@onready var grid: ShipGridView = $MainLayout/Center/Grid
@onready var module_buttons: VBoxContainer = $MainLayout/LeftPanel/LeftMargin/LeftVBox/ModuleButtons
@onready var stats_label: Label = $MainLayout/RightPanel/RightMargin/RightVBox/StatsScroll/StatsLabel
@onready var speed_label: Label = $MainLayout/RightPanel/RightMargin/RightVBox/SpeedLabel
@onready var status_label: Label = $BottomBar/BottomMargin/StatusLabel
@onready var selected_label: Label = $MainLayout/LeftPanel/LeftMargin/LeftVBox/SelectedLabel

func _ready() -> void:
	_build_module_buttons()
	_bind_common_buttons()
	grid.ship_changed.connect(_refresh_stats)
	grid.selected_module_changed.connect(_on_selected_module_changed)
	grid.status_message.connect(_show_status)
	_refresh_selected_label()
	_refresh_stats()
	_show_status("先铺船体再安装设备｜左键放置/选中｜右键拆除｜R 旋转｜中键拖动画布")
	if get_tree().has_meta(&"restore_ship_design"):
		get_tree().remove_meta(&"restore_ship_design")
		if FileAccess.file_exists(SAVE_PATH):
			_load_ship()

func _build_module_buttons() -> void:
	for child in module_buttons.get_children():
		child.queue_free()

	var hull_button := Button.new()
	hull_button.custom_minimum_size = Vector2(0, 44)
	hull_button.text = "船体｜基础船体格"
	hull_button.tooltip_text = "Hull Layout：每格独立 20 HP、质量 2。设备必须完整安装在船体格上。"
	hull_button.pressed.connect(_select_hull)
	module_buttons.add_child(hull_button)

	for definition in grid.get_all_definitions():
		var button := Button.new()
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
	get_tree().set_meta(BATTLE_DEFINITION_META, FIRST_BATTLE_DEFINITION_PATH)
	_start_scene_with_design(BATTLE_SCENE_PATH)

func _start_ai_test() -> void:
	_start_scene_with_design("res://game/ship/dev/ship_ai_test.tscn")

func _start_scene_with_design(scene_path: String) -> void:
	if not grid.ship.is_design_valid():
		_show_status("无法出航：%s" % grid.ship.get_design_invalid_reason())
		return
	var result := ShipSerializer.save_to_file(grid.ship, SAVE_PATH)
	if not result["ok"]:
		_show_status("保存失败：%s" % result["error"])
		return
	get_tree().change_scene_to_file(scene_path)

func _save_ship() -> void:
	var result := ShipSerializer.save_to_file(grid.ship, SAVE_PATH)
	if result["ok"]:
		_show_status("飞船设计已保存：%s" % SAVE_PATH)
	else:
		_show_status("保存失败：%s" % result["error"])

func _load_ship() -> void:
	var result := ShipSerializer.load_from_file(SAVE_PATH, grid.module_database)
	if result["ok"]:
		var loaded_ship := result["ship"] as ShipData
		grid.set_ship(loaded_ship)
		_show_status("飞船设计已加载：%s" % SAVE_PATH)
	else:
		_show_status("加载失败：%s" % result["error"])

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
