extends HBoxContainer

const BRIDGE_DB: BridgeDatabase = preload("res://data/bridge/bridge_database.tres")

var ship_grid: ShipGridView
var run_state: Node
var selected_kind := ""
var selected_id := ""
var inventory_filter := "crew"

@onready var inventory_items: VBoxContainer = $Inventory/InventoryScroll/InventoryItems
@onready var crew_row: HBoxContainer = $Slots/CrewRow
@onready var chip_row: HBoxContainer = $Slots/ChipRow
@onready var hint: Label = $Slots/Hint

func bind_editor(grid: ShipGridView, state: Node) -> void:
	ship_grid = grid
	run_state = state
	refresh()

func set_inventory_filter(kind: String) -> void:
	inventory_filter = kind
	refresh()

func refresh() -> void:
	if not is_node_ready() or ship_grid == null:
		return
	_clear(inventory_items)
	_clear(crew_row)
	_clear(chip_row)
	var core: CoreModuleDefinition
	for module in ship_grid.ship.modules:
		if module.definition is CoreModuleDefinition:
			core = module.definition as CoreModuleDefinition
			break
	var crew_count := core.crew_slots if core != null else 0
	var chip_count := core.chip_slots if core != null else 0
	var active := run_state != null and bool(run_state.get("run_active"))
	if inventory_filter == "crew":
		_add_inventory_heading("机组")
	for item in BRIDGE_DB.crew:
		var count := int(run_state.call("get_bridge_item_count", "crew", String(item.crew_id))) if active else 0
		if count > 0 and inventory_filter == "crew":
			_add_inventory_item("crew", String(item.crew_id), item.display_name, count)
	if inventory_filter == "chip":
		_add_inventory_heading("芯片")
	for item in BRIDGE_DB.chips:
		var count := int(run_state.call("get_bridge_item_count", "chip", String(item.chip_id))) if active else 0
		if count > 0 and inventory_filter == "chip":
			_add_inventory_item("chip", String(item.chip_id), item.display_name, count)
	_make_slots(crew_row, "crew", crew_count, "机组")
	_make_slots(chip_row, "chip", chip_count, "芯片")
	hint.text = "无 Core 模块" if core == null else ("Run 内可装配；当前为预览" if not active else _build_modifier_preview())

func _clear(target: Node) -> void:
	for child in target.get_children():
		target.remove_child(child)
		child.queue_free()

func _add_inventory_heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	inventory_items.add_child(label)

func _add_inventory_item(kind: String, id: String, name: String, count: int) -> void:
	var button := Button.new()
	button.text = "%s ×%d" % [name, count]
	button.custom_minimum_size.y = 24
	button.tooltip_text = "选择后点击对应舰桥插槽"
	button.pressed.connect(func():
		selected_kind = kind
		selected_id = id
		hint.text = "已选择：%s" % name
	)
	inventory_items.add_child(button)

func _make_slots(row: HBoxContainer, kind: String, capacity: int, title: String) -> void:
	var label := Label.new()
	label.text = "%s %d槽" % [title, capacity]
	label.custom_minimum_size.x = 70
	row.add_child(label)
	for index in range(capacity):
		var id := ""
		if run_state != null and bool(run_state.get("run_active")):
			id = String(run_state.call("get_bridge_equipped", kind, index))
		var button := Button.new()
		button.custom_minimum_size = Vector2(48, 30)
		button.text = "+" if id.is_empty() else _get_name(kind, id)
		button.tooltip_text = "点击卸下" if not id.is_empty() else "点击安装"
		button.pressed.connect(_on_slot_pressed.bind(kind, index, id))
		row.add_child(button)

func _get_name(kind: String, id: String) -> String:
	if kind == "crew":
		var entry := BRIDGE_DB.find_crew(StringName(id))
		return entry.display_name if entry != null else id
	var chip := BRIDGE_DB.find_chip(StringName(id))
	return chip.display_name if chip != null else id

func _on_slot_pressed(kind: String, index: int, equipped: String) -> void:
	if run_state == null or not bool(run_state.get("run_active")):
		hint.text = "请先进入 Run 后再配置舰桥"
		return
	if not equipped.is_empty():
		if kind == selected_kind and not selected_id.is_empty():
			if bool(run_state.call("replace_bridge_item", kind, selected_id, index)):
				selected_kind = ""
				selected_id = ""
				refresh()
			return
		if bool(run_state.call("unequip_bridge_item", kind, index)):
			refresh()
		return
	if kind != selected_kind or selected_id.is_empty():
		hint.text = "请先从左侧选择对应的机组或芯片"
		return
	if bool(run_state.call("equip_bridge_item", kind, selected_id, index)):
		selected_kind = ""
		selected_id = ""
		refresh()
	else:
		hint.text = "无法安装：库存不足或插槽不可用"

func _build_modifier_preview() -> String:
	var modifiers: Array = run_state.call("get_bridge_modifiers")
	if modifiers.is_empty():
		return "尚未装备机组或芯片"
	var names := {
		"weapon_damage": "伤害", "weapon_range": "射程",
		"weapon_fire_interval": "射击间隔", "thrust": "推力",
		"energy_output": "供能", "turn_speed": "转速",
		"protection": "防护", "repair_cost": "维修成本"
	}
	var sections: Array[String] = []
	for stat in names:
		var base := 100.0
		var modified := ShipModifierSystem.apply(base, StringName(stat), modifiers)
		if not is_equal_approx(base, modified):
			sections.append("%s %.0f→%.1f*" % [names[stat], base, modified])
	return "效果预览（基准100，*非最终战斗值）：%s" % ("，".join(sections) if not sections.is_empty() else "无通用属性变化")
