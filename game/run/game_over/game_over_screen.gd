extends Control

const EDITOR_SCENE_PATH := "res://game/ship/editor/ship_editor.tscn"

@onready var summary: Label = %Summary
@onready var return_button: Button = %Return

func _ready() -> void:
	return_button.pressed.connect(_return_to_editor)
	var run_state := get_node_or_null("/root/RunState")
	if run_state == null or run_state.last_result == null:
		return
	var result := run_state.last_result as BattleResult
	if result.is_victory():
		return
	summary.text = "%s\n击毁敌舰：%d｜波次：%d / %d\n战斗时间：%.1f 秒" % [
		String(result.battle_id) if result.battle_name.is_empty() else result.battle_name,
		result.enemies_destroyed, result.waves_reached, result.total_waves, result.elapsed_seconds
	]

func _return_to_editor() -> void:
	var run_state := get_node_or_null("/root/RunState")
	if run_state != null:
		run_state.reset_run()
	get_tree().set_meta(&"restore_ship_design", true)
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)
