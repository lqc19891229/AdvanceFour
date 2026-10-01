extends Control

const SAVE_PATH := "user://ships/test_ship.json"

@onready var grid: ShipGridView = $MainLayout/Center/Grid
@onready var module_buttons: VBoxContainer = $MainLayout/LeftPanel/LeftMargin/LeftVBox/ModuleButtons
@onready var stats_label: Label = $MainLayout/RightPanel/RightMargin/RightVBox/StatsScroll/StatsLabel
@onready var status_label: Label = $BottomBar/BottomMargin/StatusLabel
@onready var selected_label: Label = $MainLayout/LeftPanel/LeftMargin/LeftVBox/SelectedLabel

func _ready() -> void:
	_build_module_buttons()
	_bind_common_buttons()
	grid.ship_changed.connect(_refresh_stats)
	grid.status_message.connect(_show_status)
	_refresh_selected_label()
	_refresh_stats()
	_show_status("左键放置｜右键删除｜R 旋转｜中键拖动画布")
	if get_tree().has_meta(&"restore_ship_design"):
		get_tree().remove_meta(&"restore_ship_design")
		if FileAccess.file_exists(SAVE_PATH):
			_load_ship()

func _build_module_buttons() -> void:
	for child in module_buttons.get_children():
		child.queue_free()

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
	lines.append("质量：%.1f" % definition.mass)
	lines.append("耗能：%.1f" % definition.energy_cost)
	lines.append("HP：%.1f" % definition.hp)

	if definition is EnergyModuleDefinition:
		lines.append("供能：%.1f" % (definition as EnergyModuleDefinition).energy_output)
	elif definition is PropulsionModuleDefinition:
		lines.append("动力：%.1f" % (definition as PropulsionModuleDefinition).thrust)
	elif definition is WeaponModuleDefinition:
		lines.append("火力：%.1f" % (definition as WeaponModuleDefinition).firepower)
	elif definition is DefenseModuleDefinition:
		lines.append("防护：%.1f" % (definition as DefenseModuleDefinition).protection)
	elif definition is FunctionModuleDefinition:
		lines.append("功能模块：暂无额外参数")
	elif definition is CoreModuleDefinition:
		lines.append("核心模块：被击毁时判定沉没")

	return "\n".join(lines)

func _bind_common_buttons() -> void:
	$MainLayout/RightPanel/RightMargin/RightVBox/SaveButton.pressed.connect(_save_ship)
	$MainLayout/RightPanel/RightMargin/RightVBox/LoadButton.pressed.connect(_load_ship)
	$MainLayout/RightPanel/RightMargin/RightVBox/RotateButton.pressed.connect(grid.rotate_preview)
	$MainLayout/RightPanel/RightMargin/RightVBox/CenterButton.pressed.connect(grid.center_view)
	$MainLayout/RightPanel/RightMargin/RightVBox/ClearButton.pressed.connect(grid.clear_ship)
	$MainLayout/RightPanel/RightMargin/RightVBox/AITestButton.pressed.connect(_start_ai_test)
	$MainLayout/RightPanel/RightMargin/RightVBox/BattleButton.pressed.connect(_start_battle)

func _start_battle() -> void:
	_start_scene_with_design("res://game/combat/battle.tscn")

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

func _refresh_selected_label() -> void:
	if grid.selected_definition == null:
		selected_label.text = "当前：未选择"
	else:
		selected_label.text = "当前：%s" % grid.selected_definition.display_name

func _refresh_stats() -> void:
	var s := grid.ship
	var design_status := "可出航" if s.is_design_valid() else "不可出航：%s" % s.get_design_invalid_reason()

	stats_label.text = """模块数量：%d

质量：%.1f

能量：%.1f / %.1f
动力：%.1f
推重比：%.2f

火力：%.1f
防护：%.1f

核心：%s
沉没判定：%s

设计状态：%s

结构规则：
模块可分开放置；
不要求相邻、连通或填满格子。

能量规则：
编辑时允许临时超额耗能；
出航时总耗能必须 ≤ 总供能。""" % [
		s.modules.size(),
		s.get_mass(),
		s.get_energy_cost(),
		s.get_energy_output(),
		s.get_thrust(),
		s.get_acceleration_score(),
		s.get_firepower(),
		s.get_protection(),
		"已安装" if s.has_core() else "未安装",
		"核心被击毁 → 沉没" if s.has_core() else "需要核心模块",
		design_status
	]

func _show_status(text: String) -> void:
	status_label.text = text
