extends Control

const RESULT_SCENE_PATH := "res://game/run/battle_result/battle_result_screen.tscn"
const DATABASE := preload("res://data/modules/module_database.tres")

@onready var capacity_label: Label = $Margin/Layout/Header/Capacity
@onready var status_label: Label = $Margin/Layout/Header/Status
@onready var loot_list: VBoxContainer = $Margin/Layout/LootScroll/LootList
@onready var continue_button: Button = $Margin/Layout/Footer/Continue

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	continue_button.pressed.connect(_continue)
	_refresh()

func _refresh() -> void:
	for child in loot_list.get_children():
		loot_list.remove_child(child)
		child.queue_free()

	var run_state := _run_state()
	if run_state == null or not run_state.run_active or run_state.last_result == null:
		capacity_label.text = "没有可处理的战利品"
		status_label.text = ""
		continue_button.disabled = false
		return

	var used := int(run_state.call("get_warehouse_used"))
	var capacity := int(run_state.call("get_warehouse_capacity"))
	capacity_label.text = "模块仓库：%d / %d｜剩余：%d" % [used, capacity, maxi(capacity - used, 0)]

	var result := run_state.last_result as BattleResult
	for index in range(result.reward_module_ids.size()):
		loot_list.add_child(_build_loot_card(result, index))

	var pending := bool(run_state.call("has_pending_loot"))
	continue_button.disabled = pending
	if pending:
		status_label.text = "请处理全部战利品后继续。仓库空间不足的物品可以放弃。"
	else:
		var taken := 0
		var discarded := 0
		for index in range(result.loot_resolved.size()):
			if result.loot_taken[index]:
				taken += 1
			else:
				discarded += 1
		status_label.text = "战利品处理完成：带走 %d，放弃 %d。" % [taken, discarded]

func _build_loot_card(result: BattleResult, index: int) -> Control:
	var module_id := result.reward_module_ids[index]
	var definition := DATABASE.get_by_id(module_id)
	var count := int(_run_state().call("get_loot_count", index))
	var resolved := index < result.loot_resolved.size() and result.loot_resolved[index]
	var taken := resolved and index < result.loot_taken.size() and result.loot_taken[index]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 112)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var texture := TextureRect.new()
	texture.custom_minimum_size = Vector2(96, 96)
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture = null if definition == null else definition.texture
	row.add_child(texture)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 20)
	title.text = String(module_id) if definition == null else definition.display_name
	info.add_child(title)

	var detail := Label.new()
	if definition == null:
		detail.text = "未知模块"
	else:
		var storage := int(_run_state().call("get_module_storage_cost", module_id, count))
		detail.text = "%s｜%d×%d｜×%d｜仓储占用 %d" % [
			definition.get_type_name(),
			definition.size.x,
			definition.size.y,
			count,
			storage
		]
	info.add_child(detail)

	var rarity := LootTableEntry.Rarity.COMMON
	if index < result.reward_module_rarities.size():
		rarity = result.reward_module_rarities[index]
	var rarity_label := LootTableEntry.new()
	rarity_label.rarity = rarity
	var state := Label.new()
	state.text = "%s｜%s" % [rarity_label.get_rarity_label(), "已带走" if taken else ("已放弃" if resolved else "待处理")]
	info.add_child(state)

	var actions := VBoxContainer.new()
	actions.custom_minimum_size = Vector2(130, 0)
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

func _continue() -> void:
	var run_state := _run_state()
	if run_state == null or bool(run_state.call("has_pending_loot")):
		return
	get_tree().change_scene_to_file(RESULT_SCENE_PATH)
