extends Control

const BATTLE_SCENE_PATH := "res://game/combat/battle.tscn"
const EDITOR_SCENE_PATH := "res://game/ship/editor/ship_editor.tscn"
const BATTLE_DEFINITION_META := &"battle_definition_path"
const RUN_REFIT_META := &"run_refit_mode"

@onready var title: Label = $Center/Panel/Margin/Content/Title
@onready var summary: Label = $Center/Panel/Margin/Content/Summary
@onready var repair_button: Button = $Center/Panel/Margin/Content/RepairAll
@onready var refit_button: Button = $Center/Panel/Margin/Content/Refit
@onready var next_button: Button = $Center/Panel/Margin/Content/NextBattle
@onready var end_run_button: Button = $Center/Panel/Margin/Content/EndRun

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	repair_button.pressed.connect(_repair_all)
	refit_button.pressed.connect(_enter_refit)
	next_button.pressed.connect(_next_battle)
	end_run_button.pressed.connect(_end_run)
	_refresh()

func _refresh() -> void:
	if _run_state() == null or not _run_state().run_active or _run_state().last_result == null:
		title.text = "没有可用的战斗结果"
		summary.text = "当前没有进行中的 Run。"
		repair_button.disabled = true
		refit_button.disabled = true
		next_button.disabled = true
		end_run_button.disabled = true
		return
	var result := _run_state().last_result as BattleResult
	var damaged := 0
	var destroyed := 0
	var intact := 0
	for cell in _run_state().current_ship.get_hull_cells():
		if cell.current_hp <= 0.0:
			destroyed += 1
		elif cell.current_hp < cell.max_hp:
			damaged += 1
		else:
			intact += 1
	var repair_cost := int(_run_state().call("get_total_repair_cost"))
	title.text = "战斗胜利"
	summary.text = "%s\n奖励：+%d Credits\n当前 Credits：%d\n\nHull 完整：%d  受损：%d  摧毁：%d\n全部维修费用：%d" % [
		String(result.battle_id),
		result.reward_credits,
		_run_state().currency,
		intact,
		damaged,
		destroyed,
		repair_cost
	]
	repair_button.text = "全部维修（%d Credits）" % repair_cost
	repair_button.disabled = repair_cost <= 0 or _run_state().currency < repair_cost
	refit_button.disabled = false
	var has_next := not String(_run_state().call("get_next_battle_path")).is_empty()
	next_button.visible = has_next
	next_button.disabled = not has_next
	end_run_button.visible = not has_next
	end_run_button.disabled = has_next

func _repair_all() -> void:
	_run_state().call("repair_all")
	_refresh()

func _enter_refit() -> void:
	get_tree().set_meta(RUN_REFIT_META, true)
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)

func _next_battle() -> void:
	var next_path := String(_run_state().call("advance_to_next_battle"))
	if next_path.is_empty():
		return
	get_tree().set_meta(BATTLE_DEFINITION_META, next_path)
	get_tree().change_scene_to_file(BATTLE_SCENE_PATH)


func _end_run() -> void:
	if _run_state() == null or not _run_state().run_active:
		return
	_run_state().call("reset_run")
	get_tree().set_meta(&"restore_ship_design", true)
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)
