class_name StationCraftItemDefinition
extends Resource

const DATABASE := preload("res://data/modules/module_database.tres")

@export var item_id: StringName = &""
@export var display_name := ""
@export var module_id: StringName = &""
@export var module_count := 1
@export var parts_cost := 0

func is_valid() -> bool:
	return (
		item_id != &""
		and not display_name.strip_edges().is_empty()
		and module_id != &""
		and module_count > 0
		and parts_cost >= 0
		and DATABASE.get_by_id(module_id) != null
	)

func get_invalid_reason() -> String:
	if item_id == &"":
		return "制造项目 ID 不能为空。"
	if display_name.strip_edges().is_empty():
		return "制造项目名称不能为空。"
	if module_id == &"" or DATABASE.get_by_id(module_id) == null:
		return "制造模块 ID 无效：%s" % String(module_id)
	if module_count <= 0:
		return "制造数量必须大于 0。"
	if parts_cost < 0:
		return "零件成本不能为负数。"
	return ""

func get_contents_label() -> String:
	var definition := DATABASE.get_by_id(module_id)
	var name := String(module_id) if definition == null else definition.display_name
	return "%s ×%d" % [name, module_count]

func get_texture() -> Texture2D:
	var definition := DATABASE.get_by_id(module_id)
	return null if definition == null else definition.texture
