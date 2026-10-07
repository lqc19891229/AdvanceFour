extends Control

const RESULT_SCENE_PATH := "res://game/run/battle_result/battle_result_screen.tscn"
const ROUTE_MAP_SCENE_PATH := "res://game/run/route/route_map_screen.tscn"
const FALLBACK_SHOP := preload("res://data/shops/basic_shop.tres")

var shop_definition: ShopDefinition

@onready var title: Label = $Center/Panel/Margin/Content/Title
@onready var credits_label: Label = $Center/Panel/Margin/Content/Credits
@onready var slots: HBoxContainer = $Center/Panel/Margin/Content/Slots
@onready var inventory_label: Label = $Center/Panel/Margin/Content/Inventory
@onready var status_label: Label = $Center/Panel/Margin/Content/Status
@onready var return_button: Button = $Center/Panel/Margin/Content/Return

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	return_button.pressed.connect(_return_from_shop)
	shop_definition = _resolve_shop_definition()
	_refresh()

func _resolve_shop_definition() -> ShopDefinition:
	var run_state := _run_state()
	if run_state != null and bool(run_state.call("is_route_active")):
		var node := run_state.call("get_current_route_node") as RunRouteNodeDefinition
		if node != null and node.node_type == RunRouteNodeDefinition.NodeType.SHOP and ResourceLoader.exists(node.target_path):
			var loaded := ResourceLoader.load(node.target_path)
			if loaded is ShopDefinition:
				return loaded as ShopDefinition
	return FALLBACK_SHOP

func _refresh() -> void:
	var run_state := _run_state()
	if run_state == null or not run_state.run_active:
		title.text = "商店不可用"
		credits_label.text = "当前没有进行中的 Run。"
		return_button.disabled = false
		return
	if not shop_definition.is_valid():
		title.text = "商店配置错误"
		credits_label.text = shop_definition.get_invalid_reason()
		return_button.disabled = false
		return

	title.text = shop_definition.display_name
	credits_label.text = "Credits：%d" % int(run_state.get("currency"))
	_refresh_slots()
	_refresh_inventory()

func _refresh_slots() -> void:
	for child in slots.get_children():
		slots.remove_child(child)
		child.queue_free()

	var run_state := _run_state()
	if run_state == null:
		return
	var generated_slots: Array = run_state.call("get_shop_slots", shop_definition)
	for index in range(generated_slots.size()):
		var item := generated_slots[index] as ShopItemDefinition
		if item == null:
			continue
		var purchased := bool(run_state.call("is_shop_slot_purchased", shop_definition, index))
		slots.add_child(_build_item_card(item, index, purchased))

func _build_item_card(item: ShopItemDefinition, slot_index: int, purchased: bool) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Slot%d" % (slot_index + 1)
	panel.custom_minimum_size = Vector2(235, 300)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var slot_label := Label.new()
	slot_label.text = "商品槽 %d" % (slot_index + 1)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(slot_label)

	var texture_rect := TextureRect.new()
	texture_rect.custom_minimum_size = Vector2(180, 110)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture = item.get_texture()
	content.add_child(texture_rect)

	var name_label := Label.new()
	name_label.text = item.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	content.add_child(name_label)

	var type_label := Label.new()
	type_label.text = "%s｜%s" % [item.get_type_label(), item.get_contents_label()]
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(type_label)

	var price_label := Label.new()
	price_label.text = "%d Credits" % item.price_credits
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(price_label)

	var buy_button := Button.new()
	buy_button.name = "Buy"
	buy_button.custom_minimum_size = Vector2(0, 42)
	buy_button.text = "SOLD" if purchased else "购买"
	buy_button.disabled = purchased or not bool(_run_state().call("can_purchase_shop_slot", shop_definition, slot_index))
	buy_button.tooltip_text = "购买后直接进入当前 Run Inventory。"
	buy_button.pressed.connect(_purchase_slot.bind(slot_index))
	content.add_child(buy_button)
	return panel

func _refresh_inventory() -> void:
	var run_state := _run_state()
	if run_state == null:
		inventory_label.text = ""
		return
	var lines: Array[String] = []
	lines.append("当前库存｜Hull：%d" % int(run_state.get("hull_stock")))
	var inventory: Dictionary = run_state.get("module_inventory")
	if inventory.is_empty():
		lines.append("模块：无")
	else:
		var ids := inventory.keys()
		ids.sort()
		var parts: Array[String] = []
		for raw_id in ids:
			var module_id := StringName(raw_id)
			var definition := ShopItemDefinition.DATABASE.get_by_id(module_id)
			var name := String(module_id) if definition == null else definition.display_name
			parts.append("%s ×%d" % [name, int(inventory[module_id])])
		lines.append("模块：" + "｜".join(parts))
	inventory_label.text = "\n".join(lines)

func _purchase_slot(slot_index: int) -> void:
	var run_state := _run_state()
	if run_state == null:
		return
	var generated_slots: Array = run_state.call("get_shop_slots", shop_definition)
	var item: ShopItemDefinition = null
	if slot_index >= 0 and slot_index < generated_slots.size():
		item = generated_slots[slot_index] as ShopItemDefinition
	if bool(run_state.call("purchase_shop_slot", shop_definition, slot_index)):
		status_label.text = "已购买：%s" % item.get_contents_label()
	else:
		status_label.text = "购买失败：Credits 不足、商品已售出或商品无效。"
	_refresh()

func _return_from_shop() -> void:
	var run_state := _run_state()
	if run_state != null and bool(run_state.call("is_route_active")):
		var node := run_state.call("get_current_route_node") as RunRouteNodeDefinition
		if node != null and node.node_type == RunRouteNodeDefinition.NodeType.SHOP:
			run_state.call("complete_current_route_node")
			get_tree().change_scene_to_file(ROUTE_MAP_SCENE_PATH)
			return
	get_tree().change_scene_to_file(RESULT_SCENE_PATH)
