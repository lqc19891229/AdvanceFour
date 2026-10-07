extends Control

const BATTLE_SCENE_PATH := "res://game/combat/battle.tscn"
const EDITOR_SCENE_PATH := "res://game/ship/editor/ship_editor.tscn"
const SHOP_SCENE_PATH := "res://game/run/shop/shop_screen.tscn"
const ROUTE_MAP_SCENE_PATH := "res://game/run/route/route_map_screen.tscn"
const BATTLE_DEFINITION_META := &"battle_definition_path"
const RUN_REFIT_META := &"run_refit_mode"
const DATABASE := preload("res://data/modules/module_database.tres")

@onready var title: Label = %Title
@onready var summary: Label = %Summary
@onready var columns: BoxContainer = %Columns
@onready var capacity_label: Label = %Capacity
@onready var status_label: Label = %LootStatus
@onready var loot_list: VBoxContainer = %LootList
@onready var snapshot: ShipDamageSnapshot = %Snapshot
@onready var damage_summary: Label = %DamageSummary
@onready var selected_detail: Label = %SelectedDetail
@onready var repair_selected_button: Button = %RepairSelected
@onready var repair_button: Button = %RepairAll
@onready var shop_button: Button = %Shop
@onready var refit_button: Button = %Refit
@onready var next_button: Button = %NextBattle
@onready var end_run_button: Button = %EndRun

var has_selected_cell := false
var selected_position := Vector2i.ZERO

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	repair_selected_button.pressed.connect(_repair_selected)
	repair_button.pressed.connect(_repair_all)
	shop_button.pressed.connect(_open_shop)
	refit_button.pressed.connect(_enter_refit)
	next_button.pressed.connect(_next_battle)
	end_run_button.pressed.connect(_end_run)
	snapshot.cell_selected.connect(_select_cell)
	resized.connect(_update_layout)
	_update_layout()
	_refresh()

func _update_layout() -> void:
	columns.vertical = size.x < 900.0

func _refresh() -> void:
	var run_state := _run_state()
	if run_state == null or not run_state.run_active or run_state.last_result == null or not run_state.last_result.is_victory():
		title.text = "没有可用的战斗结果"
		summary.text = "当前没有待结算的胜利。"
		snapshot.set_ship(null)
		_clear_loot_list()
		capacity_label.text = ""
		status_label.text = ""
		damage_summary.text = ""
		selected_detail.text = ""
		repair_selected_button.disabled = true
		repair_button.disabled = true
		shop_button.disabled = true
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
	summary.text = "%s｜%s\n能量结晶：%d｜零件：%d" % [
		String(result.battle_id), _build_reward_text(result), run_state.energy_crystals, run_state.parts
	]
	damage_summary.text = "完好 %d｜受损 %d｜摧毁 %d" % [intact, damaged, destroyed]
	snapshot.set_ship(run_state.current_ship)
	_refresh_loot(result)
	_refresh_selected_detail()

	repair_button.text = "全部维修（%d 零件）" % repair_cost
	repair_button.disabled = repair_cost <= 0 or run_state.parts < repair_cost
	var pending_loot := bool(run_state.call("has_pending_loot"))
	if bool(run_state.call("is_route_active")):
		shop_button.visible = false
		refit_button.visible = false
		next_button.visible = true
		next_button.text = "返回星图"
		next_button.disabled = pending_loot or not bool(run_state.call("is_current_route_node_complete"))
		end_run_button.visible = false
		return

	var has_next_configured := not result.next_battle_path.is_empty()
	shop_button.visible = has_next_configured
	shop_button.disabled = pending_loot or not has_next_configured
	refit_button.visible = true
	refit_button.disabled = pending_loot
	var has_next := not String(run_state.call("get_next_battle_path")).is_empty()
	next_button.visible = has_next_configured
	next_button.text = "下一战"
	next_button.disabled = pending_loot or not has_next
	end_run_button.visible = not has_next_configured
	end_run_button.disabled = pending_loot


func _build_reward_text(result: BattleResult) -> String:
	var parts: Array[String] = []
	if result.reward_energy_crystals > 0:
		parts.append("+%d 能量结晶" % result.reward_energy_crystals)
	if result.reward_parts > 0:
		parts.append("+%d 零件" % result.reward_parts)
	if result.reward_hull_cells > 0:
		parts.append("+%d Hull" % result.reward_hull_cells)

	return "奖励：" + ("无" if parts.is_empty() else "｜".join(parts))


func _clear_loot_list() -> void:
	for child in loot_list.get_children():
		loot_list.remove_child(child)
		child.queue_free()

func _refresh_loot(result: BattleResult) -> void:
	_clear_loot_list()
	var run_state := _run_state()
	var used := int(run_state.call("get_warehouse_used"))
	var capacity := int(run_state.call("get_warehouse_capacity"))
	capacity_label.text = "模块仓库：%d / %d｜剩余：%d" % [used, capacity, maxi(capacity - used, 0)]
	for index in range(result.reward_module_ids.size()):
		loot_list.add_child(_build_loot_card(result, index))
	if result.reward_module_ids.is_empty():
		status_label.text = "本场没有模块战利品，可以继续。"
	elif bool(run_state.call("has_pending_loot")):
		status_label.text = "请逐件带走或放弃。全部处理后可继续，维修可跳过。"
	else:
		var taken := result.loot_taken.count(true)
		status_label.text = "已处理：带走 %d，放弃 %d。可以继续。" % [taken, result.loot_resolved.size() - taken]

func _build_loot_card(result: BattleResult, index: int) -> Control:
	var module_id := result.reward_module_ids[index]
	var definition := DATABASE.get_by_id(module_id)
	var count := int(_run_state().call("get_loot_count", index))
	var resolved := index < result.loot_resolved.size() and result.loot_resolved[index]
	var taken := resolved and index < result.loot_taken.size() and result.loot_taken[index]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 84)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var texture := TextureRect.new()
	texture.custom_minimum_size = Vector2(56, 56)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture = null if definition == null else definition.get_display_texture()
	row.add_child(texture)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.text = String(module_id) if definition == null else definition.display_name
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(title)

	var detail := Label.new()
	if definition == null:
		detail.text = "未知模块"
	else:
		var storage := int(_run_state().call("get_module_storage_cost", module_id, count))
		detail.text = "%s｜数量：%d｜仓储占用 %d" % [
			definition.get_type_name(),
			count,
			storage
		]
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)

	var state := Label.new()
	state.text = "已带走" if taken else ("已放弃" if resolved else "待处理")
	info.add_child(state)

	var actions := VBoxContainer.new()
	actions.custom_minimum_size = Vector2(72, 0)
	row.add_child(actions)

	var take := Button.new()
	take.name = "Take"
	take.text = "带走"
	take.disabled = resolved or not bool(_run_state().call("can_take_loot", index))
	if not resolved and take.disabled:
		take.tooltip_text = "仓库空间不足。"
	take.pressed.connect(_take.bind(index))
	actions.add_child(take)

	var discard := Button.new()
	discard.name = "Discard"
	discard.text = "放弃"
	discard.disabled = resolved
	discard.pressed.connect(_discard.bind(index))
	actions.add_child(discard)
	return panel

func _take(index: int) -> void:
	var run_state := _run_state()
	if run_state != null and bool(run_state.call("take_loot", index)):
		_refresh()

func _discard(index: int) -> void:
	var run_state := _run_state()
	if run_state != null and bool(run_state.call("discard_loot", index)):
		_refresh()

func _select_cell(position: Vector2i) -> void:
	has_selected_cell = true
	selected_position = position
	_refresh_selected_detail()

func _refresh_selected_detail() -> void:
	var run_state := _run_state()
	snapshot.set_selected_cell(selected_position, has_selected_cell)
	if run_state == null or run_state.current_ship == null:
		has_selected_cell = false
		selected_detail.text = ""
		repair_selected_button.disabled = true
		return

	if not has_selected_cell:
		selected_detail.text = "点击飞船上的船体格，查看战损和维修费用。"
		repair_selected_button.text = "维修选中船体"
		repair_selected_button.disabled = true
		return

	var cell: ShipHullCell = run_state.current_ship.get_hull_cell_at(selected_position)
	if cell == null:
		has_selected_cell = false
		snapshot.set_selected_cell(selected_position, false)
		selected_detail.text = "请选择飞船上的船体格。"
		repair_selected_button.disabled = true
		return

	var module := run_state.current_ship.get_module_at(selected_position) as ShipModuleInstance
	var cost := int(run_state.call("get_repair_cost_for_cell", selected_position))
	var current_efficiency := _get_module_efficiency(module)
	var repaired_efficiency := _get_module_efficiency_after_repair(module, selected_position)
	var effect_line := "该格未安装模块。"
	if module != null:
		effect_line = "覆盖模块：%s｜当前效率 %.0f%% → 维修后 %.0f%%" % [
			module.definition.display_name,
			current_efficiency * 100.0,
			repaired_efficiency * 100.0
		]

	selected_detail.text = "%s 船体 (%d,%d)：%.0f / %.0f HP\n%s" % [
		_get_damage_label(cell),
		selected_position.x,
		selected_position.y,
		cell.current_hp,
		cell.max_hp,
		effect_line
	]
	repair_selected_button.text = "维修此格（%d 零件）" % cost
	repair_selected_button.disabled = cost <= 0 or run_state.parts < cost
	repair_selected_button.tooltip_text = "零件不足。" if cost > run_state.parts else ""

func _get_damage_label(cell: ShipHullCell) -> String:
	if cell.current_hp <= 0.0:
		return "摧毁"
	var ratio := cell.get_health_ratio()
	if ratio < 0.5:
		return "重度受损"
	if ratio < 1.0:
		return "轻度受损"
	return "完好"

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

func _open_shop() -> void:
	var run_state := _run_state()
	if run_state == null or bool(run_state.call("has_pending_loot")):
		return
	get_tree().change_scene_to_file(SHOP_SCENE_PATH)

func _enter_refit() -> void:
	var run_state := _run_state()
	if run_state == null or bool(run_state.call("has_pending_loot")):
		return
	get_tree().set_meta(RUN_REFIT_META, true)
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)

func _next_battle() -> void:
	var run_state := _run_state()
	if run_state == null or bool(run_state.call("has_pending_loot")):
		return
	if bool(run_state.call("is_route_active")):
		get_tree().change_scene_to_file(ROUTE_MAP_SCENE_PATH)
		return
	var next_path := String(run_state.call("advance_to_next_battle"))
	if next_path.is_empty():
		return
	get_tree().set_meta(BATTLE_DEFINITION_META, next_path)
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)

func _end_run() -> void:
	var run_state := _run_state()
	if run_state == null or not run_state.run_active or bool(run_state.call("has_pending_loot")):
		return
	run_state.call("reset_run")
	get_tree().set_meta(&"restore_ship_design", true)
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)
