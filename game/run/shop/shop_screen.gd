extends Control

const RESULT_SCENE_PATH := "res://game/run/battle_result/battle_result_screen.tscn"
const ROUTE_MAP_SCENE_PATH := "res://game/run/route/route_map_screen.tscn"
const FALLBACK_SHOP := preload("res://data/shops/basic_shop.tres")

var shop_definition: ShopDefinition

@onready var title: Label = $Center/Panel/Margin/Content/Title
@onready var credits_label: Label = $Center/Panel/Margin/Content/Credits
@onready var item_list: VBoxContainer = $Center/Panel/Margin/Content/ItemScroll/ItemList
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
	_refresh_items()
	_refresh_inventory()

func _refresh_items() -> void:
	for child in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()

	var run_state := _run_state()
	if run_state == null:
		return
	for raw_item in shop_definition.items:
		var item := raw_item as ShopItemDefinition
		if item == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 46)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = item.get_button_label()
		button.disabled = not bool(run_state.call("can_purchase_shop_item", item))
		button.tooltip_text = "购买后直接进入当前 Run Inventory。"
		button.pressed.connect(_purchase.bind(item))
		item_list.add_child(button)

func _refresh_inventory() -> void:
	var run_state := _run_state()
	if run_state == null:
		inventory_label.text = ""
		return
	var lines: Array[String] = []
	lines.append("当前库存")
	lines.append("Hull：%d" % int(run_state.get("hull_stock")))
	var inventory: Dictionary = run_state.get("module_inventory")
	if inventory.is_empty():
		lines.append("模块：无")
	else:
		var ids := inventory.keys()
		ids.sort()
		for raw_id in ids:
			var module_id := StringName(raw_id)
			var definition := ShopItemDefinition.DATABASE.get_by_id(module_id)
			var name := String(module_id) if definition == null else definition.display_name
			lines.append("%s ×%d" % [name, int(inventory[module_id])])
	inventory_label.text = "\n".join(lines)

func _purchase(item: ShopItemDefinition) -> void:
	var run_state := _run_state()
	if run_state == null:
		return
	if bool(run_state.call("purchase_shop_item", item)):
		status_label.text = "已购买：%s" % item.get_contents_label()
	else:
		status_label.text = "购买失败：Credits 不足或商品无效。"
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
