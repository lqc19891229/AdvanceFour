class_name BattleDefinition
extends Resource

@export var battle_id: StringName = &"stage_001"
@export var display_name := "第一战"
@export var wave_enemy_counts: Array[int] = [1, 1, 2]
@export var preparation_seconds := 2.0
@export var intermission_seconds := 3.0
@export var spawn_interval_seconds := 1.25
@export var spawn_radius := 460.0
@export_file("*.tscn") var return_scene_path := "res://game/ship/editor/ship_editor.tscn"

func is_valid() -> bool:
	if battle_id == &"":
		return false
	if display_name.strip_edges().is_empty():
		return false
	if wave_enemy_counts.is_empty():
		return false
	if wave_enemy_counts.any(func(count: int): return count <= 0):
		return false
	if preparation_seconds < 0.0 or intermission_seconds < 0.0 or spawn_interval_seconds < 0.0:
		return false
	if spawn_radius <= 0.0:
		return false
	if return_scene_path.is_empty():
		return false
	return true

func get_invalid_reason() -> String:
	if battle_id == &"":
		return "战斗 ID 不能为空。"
	if display_name.strip_edges().is_empty():
		return "战斗名称不能为空。"
	if wave_enemy_counts.is_empty():
		return "战斗至少需要一波敌舰。"
	if wave_enemy_counts.any(func(count: int): return count <= 0):
		return "每波敌舰数量必须大于零。"
	if preparation_seconds < 0.0 or intermission_seconds < 0.0 or spawn_interval_seconds < 0.0:
		return "战斗计时参数不能为负数。"
	if spawn_radius <= 0.0:
		return "敌舰生成半径必须大于零。"
	if return_scene_path.is_empty():
		return "战斗返回场景不能为空。"
	return ""
