class_name BattleDefinition
extends Resource

@export var battle_id: StringName = &"stage_001"
@export var display_name := "第一战"
@export var waves: Array[Resource] = []
@export var preparation_seconds := 2.0
@export var intermission_seconds := 3.0
@export var spawn_interval_seconds := 1.25
@export var spawn_radius := 460.0
@export var reward_credits := 0
@export var reward_module_ids: Array[StringName] = []
@export var reward_module_counts: Array[int] = []
@export var reward_hull_cells := 0
@export_file("*.tres") var next_battle_path := ""
@export_file("*.tscn") var return_scene_path := "res://game/ship/editor/ship_editor.tscn"
@export var restore_saved_ship_on_return := true

func is_valid() -> bool:
	if battle_id == &"":
		return false
	if display_name.strip_edges().is_empty():
		return false
	if waves.is_empty():
		return false
	for wave in waves:
		if not (wave is BattleWaveDefinition) or not (wave as BattleWaveDefinition).is_valid():
			return false
	if preparation_seconds < 0.0 or intermission_seconds < 0.0 or spawn_interval_seconds < 0.0:
		return false
	if spawn_radius <= 0.0 or reward_credits < 0 or reward_hull_cells < 0:
		return false
	if reward_module_counts.size() > reward_module_ids.size():
		return false
	for count in reward_module_counts:
		if count < 0:
			return false
	if return_scene_path.is_empty():
		return false
	return true

func get_invalid_reason() -> String:
	if battle_id == &"":
		return "战斗 ID 不能为空。"
	if display_name.strip_edges().is_empty():
		return "战斗名称不能为空。"
	if waves.is_empty():
		return "战斗至少需要一波敌舰。"
	for index in range(waves.size()):
		var wave := waves[index]
		if not (wave is BattleWaveDefinition):
			return "第 %d 波配置无效。" % (index + 1)
		var typed_wave := wave as BattleWaveDefinition
		if not typed_wave.is_valid():
			return "第 %d 波：%s" % [index + 1, typed_wave.get_invalid_reason()]
	if preparation_seconds < 0.0 or intermission_seconds < 0.0 or spawn_interval_seconds < 0.0:
		return "战斗计时参数不能为负数。"
	if spawn_radius <= 0.0:
		return "敌舰生成半径必须大于零。"
	if reward_credits < 0:
		return "战斗奖励不能为负数。"
	if reward_hull_cells < 0:
		return "Hull 奖励不能为负数。"
	if reward_module_counts.size() > reward_module_ids.size():
		return "模块奖励数量配置不能多于模块 ID。"
	for count in reward_module_counts:
		if count < 0:
			return "模块奖励数量不能为负数。"
	if return_scene_path.is_empty():
		return "战斗返回场景不能为空。"
	return ""

func get_wave_count() -> int:
	return waves.size()

func get_wave(index: int) -> BattleWaveDefinition:
	if index < 0 or index >= waves.size():
		return null
	return waves[index] as BattleWaveDefinition
