class_name LootTableEntry
extends Resource

const DATABASE := preload("res://data/modules/module_database.tres")

@export var module_id: StringName = &""
@export var weight := 1.0
@export var min_count := 1
@export var max_count := 1

func is_valid() -> bool:
	return (
		module_id != &""
		and DATABASE.get_by_id(module_id) != null
		and weight > 0.0
		and min_count > 0
		and max_count >= min_count
	)

func get_invalid_reason() -> String:
	if module_id == &"":
		return "掉落模块 ID 不能为空。"
	if DATABASE.get_by_id(module_id) == null:
		return "掉落模块 ID 无效：%s" % String(module_id)
	if weight <= 0.0:
		return "掉落权重必须大于 0。"
	if min_count <= 0 or max_count < min_count:
		return "掉落数量范围无效。"
	return ""
