class_name BattleRewardOption
extends Resource

const DATABASE := preload("res://data/modules/module_database.tres")

@export var display_name := ""
@export var module_id: StringName = &""
@export var module_count := 0
@export var hull_cells := 0

func is_valid() -> bool:
	if module_count < 0 or hull_cells < 0:
		return false
	if module_id == &"":
		return module_count == 0 and hull_cells > 0
	if DATABASE.get_by_id(module_id) == null:
		return false
	return module_count > 0 or hull_cells > 0

func get_invalid_reason() -> String:
	if module_count < 0 or hull_cells < 0:
		return "奖励数量不能为负数。"
	if module_id == &"":
		if module_count != 0:
			return "没有模块 ID 时模块数量必须为 0。"
		if hull_cells <= 0:
			return "奖励选项至少需要模块或 Hull。"
		return ""
	if DATABASE.get_by_id(module_id) == null:
		return "奖励模块 ID 无效：%s" % String(module_id)
	if module_count <= 0 and hull_cells <= 0:
		return "奖励选项至少需要模块或 Hull。"
	return ""

func get_label() -> String:
	var parts: Array[String] = []
	if module_id != &"" and module_count > 0:
		var definition := DATABASE.get_by_id(module_id)
		var name := String(module_id) if definition == null else definition.display_name
		parts.append("%s ×%d" % [name, module_count])
	if hull_cells > 0:
		parts.append("Hull ×%d" % hull_cells)
	if not display_name.strip_edges().is_empty():
		return "%s｜%s" % [display_name, " + ".join(parts)]
	return " + ".join(parts)
