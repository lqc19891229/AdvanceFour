class_name EnemyShipDefinition
extends Resource

@export var enemy_id: StringName
@export var display_name := ""
@export_file("*.json") var ship_template_path := ""
@export var approach_distance := 280.0
@export var retreat_distance := 180.0

func is_valid() -> bool:
	return enemy_id != &"" and not display_name.strip_edges().is_empty() and approach_distance >= 0.0 and retreat_distance >= 0.0 and (ship_template_path.is_empty() or ship_template_path.begins_with("res://"))

func get_invalid_reason() -> String:
	return "" if is_valid() else "敌舰配置无效：需要 ID、名称、有效的模板路径及 AI 距离。"
