class_name ShopItemDefinition
extends Resource

const DATABASE := preload("res://data/modules/module_database.tres")
const BRIDGE := preload("res://data/bridge/bridge_database.tres")

@export var item_id: StringName = &""
@export var display_name := ""
@export var module_id: StringName = &""
@export var chip_id: StringName = &""
@export var module_count := 0
@export var hull_cells := 0
@export var price_energy_crystals := 0
@export var shop_groups: Array[StringName] = []

func is_valid() -> bool:
	if item_id == &"" or display_name.strip_edges().is_empty():
		return false
	if price_energy_crystals < 0 or module_count < 0 or hull_cells < 0:
		return false
	var has_module := module_id != &"" and module_count > 0
	var has_hull := hull_cells > 0
	var has_chip := chip_id != &""
	if int(has_module) + int(has_hull) + int(has_chip) != 1:
		return false
	if has_chip and (BRIDGE.find_chip(chip_id) == null or (BRIDGE.find_chip(chip_id) as BridgeChipDefinition).price <= 0):
		return false
	if has_module and DATABASE.get_by_id(module_id) == null:
		return false
	if module_id == &"" and module_count != 0:
		return false
	for group in shop_groups:
		if group == &"":
			return false
	return true

func get_invalid_reason() -> String:
	if item_id == &"":
		return "商品 ID 不能为空。"
	if display_name.strip_edges().is_empty():
		return "商品名称不能为空。"
	if price_energy_crystals < 0 or module_count < 0 or hull_cells < 0:
		return "商品数量与价格不能为负数。"
	var has_module := module_id != &"" and module_count > 0
	var has_hull := hull_cells > 0
	var has_chip := chip_id != &""
	if int(has_module) + int(has_hull) + int(has_chip) != 1:
		return "商品必须且只能提供模块或 Hull 中的一种。"
	if has_chip and BRIDGE.find_chip(chip_id) == null:
		return "商品芯片 ID 无效：%s" % String(chip_id)
	if has_module and DATABASE.get_by_id(module_id) == null:
		return "商品模块 ID 无效：%s" % String(module_id)
	if module_id == &"" and module_count != 0:
		return "没有模块 ID 时模块数量必须为 0。"
	for group in shop_groups:
		if group == &"":
			return "商品分组不能包含空值。"
	return ""

func matches_shop_group(group: StringName) -> bool:
	return group == &"any" or shop_groups.has(group)

func get_price() -> int:
	if chip_id != &"":
		var chip := BRIDGE.find_chip(chip_id)
		return chip.price if chip != null else 0
	return price_energy_crystals

func get_contents_label() -> String:
	if chip_id != &"":
		var chip := BRIDGE.find_chip(chip_id)
		return "%s ×1" % (chip.display_name if chip != null else String(chip_id))
	if module_id != &"" and module_count > 0:
		var definition := DATABASE.get_by_id(module_id)
		var name := String(module_id) if definition == null else definition.display_name
		return "%s ×%d" % [name, module_count]
	return "Hull ×%d" % hull_cells

func get_type_label() -> String:
	if chip_id != &"":
		return "芯片"
	if hull_cells > 0:
		return "舰体"
	var definition := DATABASE.get_by_id(module_id)
	return "模块" if definition == null else definition.get_type_name()

func get_texture() -> Texture2D:
	if chip_id != &"":
		var chip := BRIDGE.find_chip(chip_id)
		return chip.icon if chip != null else null
	if module_id == &"":
		return null
	var definition := DATABASE.get_by_id(module_id)
	return null if definition == null else definition.get_display_texture()

func get_button_label() -> String:
	return "%s｜%s｜%d 能量结晶" % [display_name, get_contents_label(), get_price()]
