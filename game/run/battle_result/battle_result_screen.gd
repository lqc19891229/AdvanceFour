extends Control

const BATTLE_SCENE_PATH := "res://game/combat/battle.tscn"
const EDITOR_SCENE_PATH := "res://game/ship/editor/ship_editor.tscn"
const BATTLE_DEFINITION_META := &"battle_definition_path"
const RUN_REFIT_META := &"run_refit_mode"

@onready var title: Label = $Center/Panel/Margin/Content/Title
@onready var summary: Label = $Center/Panel/Margin/Content/Summary
@onready var damage_list: VBoxContainer = $Center/Panel/Margin/Content/DamageScroll/DamageList
@onready var selected_detail: Label = $Center/Panel/Margin/Content/SelectedDetail
@onready var repair_selected_button: Button = $Center/Panel/Margin/Content/RepairSelected
@onready var repair_button: Button = $Center/Panel/Margin/Content/ActionRow/RepairAll
@onready var refit_button: Button = $Center/Panel/Margin/Content/ActionRow/Refit
@onready var next_button: Button = $Center/Panel/Margin/Content/ActionRow/NextBattle
@onready var end_run_button: Button = $Center/Panel/Margin/Content/ActionRow/EndRun

var has_selected_cell := false
var selected_position := Vector2i.ZERO

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	repair_selected_button.pressed.connect(_repair_selected)
	repair_button.pressed.connect(_repair_all)
	refit_button.pressed.connect(_enter_refit)
	next_button.pressed.connect(_next_battle)
	end_run_button.pressed.connect(_end_run)
	_refresh()

func _refresh() -> void:
	var run_state := _run_state()
	if run_state == null or not run_state.run_active or run_state.last_result == null:
		title.text = "没有可用的战斗结果"
		summary.text = "当前没有进行中的 Run。"
		_clear_damage_list()
		selected_detail.text = ""
		repair_selected_button.disabled = true
		repair_button.disabled = true
		refit_button.disabled = true
		next_button.disabled = true
		end_run_button.disabled = true
		return

	var result := run_state.last_result as BattleResult
	var damaged := 0
	var destroyed := 0
	var intact := 0
	for cell in run_state.current_ship.get_hull_cells():
		if cell.current_hp <= 0.0:
			destroyed += 1
		elif cell.current_hp < cell.max_hp:
			damaged += 1
		else:
			intact += 1

	var repair_cost := int(run_state.call("get_total_repair_cost"))
	title.text = "战斗胜利"
	summary.text = "%s\n奖励：+%d Credits｜当前 Credits：%d\nHull 完整：%d  受损：%d  摧毁：%d｜全部维修：%d Credits" % [
		String(result.battle_id),
		result.reward_credits,
		run_state.currency,
		intact,
		damaged,
		destroyed,
		repair_cost
	]

	_refresh_damage_list()
	_refresh_selected_detail()

	repair_button.text = "全部维修（%d Credits）" % repair_cost
	repair_button.disabled = repair_cost <= 0 or run_state.currency < repair_cost
	refit_button.disabled = false
	var has_next := not String(run_state.call("get_next_battle_path")).is_empty()
	next_button.visible = has_next
	next_button.disabled = not has_next
	end_run_button.visible = not has_next
	end_run_button.disabled = has_next

func _refresh_damage_list() -> void:
	_clear_damage_list()
	var run_state := _run_state()
	if run_state == null or run_state.current_ship == null:
		return

	var cells: Array[ShipHullCell] = run_state.current_ship.get_hull_cells()
	cells.sort_custom(func(a: ShipHullCell, b: ShipHullCell) -> bool:
		if a.grid_position.y == b.grid_position.y:
			return a.grid_position.x < b.grid_position.x
		return a.grid_position.y < b.grid_position.y
	)

	var damaged_count := 0
	for cell in cells:
		if cell.current_hp >= cell.max_hp:
			continue
		damaged_count += 1
		var position: Vector2i = cell.grid_position
		var module := run_state.current_ship.get_module_at(position) as ShipModuleInstance
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 38)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s (%d,%d)  %.0f/%.0f HP  |  %s  |  %d Credits" % [
			_get_damage_label(cell),
			position.x,
			position.y,
			cell.current_hp,
			cell.max_hp,
			_get_module_name(module),
			int(run_state.call("get_repair_cost_for_cell", position))
		]
		button.tooltip_text = "选择该 Hull Cell 查看其承载模块与维修后的效率变化。"
		button.pressed.connect(_select_cell.bind(position))
		damage_list.add_child(button)

	if damaged_count == 0:
		var label := Label.new()
		label.text = "当前没有受损 Hull。"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		damage_list.add_child(label)

func _clear_damage_list() -> void:
	for child in damage_list.get_children():
		damage_list.remove_child(child)
		child.queue_free()

func _select_cell(position: Vector2i) -> void:
	has_selected_cell = true
	selected_position = position
	_refresh_selected_detail()

func _refresh_selected_detail() -> void:
	var run_state := _run_state()
	if run_state == null or run_state.current_ship == null:
		has_selected_cell = false
		selected_detail.text = ""
		repair_selected_button.disabled = true
		return

	if not has_selected_cell:
		selected_detail.text = "选择上方受损 Hull，查看该区域的模块影响。"
		repair_selected_button.text = "维修选中 Hull"
		repair_selected_button.disabled = true
		return

	var cell: ShipHullCell = run_state.current_ship.get_hull_cell_at(selected_position)
	if cell == null or cell.current_hp >= cell.max_hp:
		has_selected_cell = false
		selected_detail.text = "该 Hull 已修复，请选择其他受损区域。"
		repair_selected_button.text = "维修选中 Hull"
		repair_selected_button.disabled = true
		return

	var module := run_state.current_ship.get_module_at(selected_position) as ShipModuleInstance
	var cost := int(run_state.call("get_repair_cost_for_cell", selected_position))
	var current_efficiency := _get_module_efficiency(module)
	var repaired_efficiency := _get_module_efficiency_after_repair(module, selected_position)
	var effect_line := "该格未承载 Equipment。"
	if module != null:
		effect_line = "覆盖模块：%s｜当前效率 %.0f%% → 修复后 %.0f%%" % [
			module.definition.display_name,
			current_efficiency * 100.0,
			repaired_efficiency * 100.0
		]

	selected_detail.text = "%s Hull (%d,%d)：%.0f / %.0f HP\n%s" % [
		_get_damage_label(cell),
		selected_position.x,
		selected_position.y,
		cell.current_hp,
		cell.max_hp,
		effect_line
	]
	repair_selected_button.text = "维修此格（%d Credits）" % cost
	repair_selected_button.disabled = cost <= 0 or run_state.currency < cost

func _get_damage_label(cell: ShipHullCell) -> String:
	if cell.current_hp <= 0.0:
		return "摧毁"
	var ratio := cell.get_health_ratio()
	if ratio < 0.5:
		return "重度受损"
	if ratio < 1.0:
		return "轻度受损"
	return "完好"

func _get_module_name(module: ShipModuleInstance) -> String:
	if module == null or module.definition == null:
		return "无设备"
	return module.definition.display_name

func _get_module_efficiency(module: ShipModuleInstance) -> float:
	var run_state := _run_state()
	if run_state == null or run_state.current_ship == null or module == null:
		return 0.0
	var cells: Array[Vector2i] = module.get_cells()
	if cells.is_empty():
		return 0.0
	var total := 0.0
	for position in cells:
		var hull: ShipHullCell = run_state.current_ship.get_hull_cell_at(position)
		if hull == null:
			return 0.0
		total += hull.get_health_ratio()
	return clampf(total / float(cells.size()), 0.0, 1.0)

func _get_module_efficiency_after_repair(module: ShipModuleInstance, repaired_position: Vector2i) -> float:
	var run_state := _run_state()
	if run_state == null or run_state.current_ship == null or module == null:
		return 0.0
	var cells: Array[Vector2i] = module.get_cells()
	if cells.is_empty():
		return 0.0
	var total := 0.0
	for position in cells:
		var hull: ShipHullCell = run_state.current_ship.get_hull_cell_at(position)
		if hull == null:
			return 0.0
		total += 1.0 if position == repaired_position else hull.get_health_ratio()
	return clampf(total / float(cells.size()), 0.0, 1.0)

func _repair_selected() -> void:
	if not has_selected_cell:
		return
	var run_state := _run_state()
	if run_state == null:
		return
	if bool(run_state.call("repair_cell", selected_position)):
		_refresh()

func _repair_all() -> void:
	var run_state := _run_state()
	if run_state == null:
		return
	run_state.call("repair_all")
	_refresh()

func _enter_refit() -> void:
	get_tree().set_meta(RUN_REFIT_META, true)
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)

func _next_battle() -> void:
	var run_state := _run_state()
	if run_state == null:
		return
	var next_path := String(run_state.call("advance_to_next_battle"))
	if next_path.is_empty():
		return
	get_tree().set_meta(BATTLE_DEFINITION_META, next_path)
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)

func _end_run() -> void:
	var run_state := _run_state()
	if run_state == null or not run_state.run_active:
		return
	run_state.call("reset_run")
	get_tree().set_meta(&"restore_ship_design", true)
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)
