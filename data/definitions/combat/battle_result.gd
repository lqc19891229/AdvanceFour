class_name BattleResult
extends RefCounted

enum Outcome { VICTORY, DEFEAT }

var outcome := Outcome.DEFEAT
var battle_id: StringName = &""
var battle_path := ""
var next_battle_path := ""
var ship_after_battle: ShipData
var reward_credits := 0
var reward_module_ids: Array[StringName] = []
var reward_module_counts: Array[int] = []
var loot_resolved: Array[bool] = []
var loot_taken: Array[bool] = []
var reward_hull_cells := 0
var reward_choices: Array[Resource] = []
var reward_choice_claimed := false
var selected_reward_choice := -1
var enemies_destroyed := 0
var elapsed_seconds := 0.0

func is_victory() -> bool:
	return outcome == Outcome.VICTORY


func initialize_loot_state() -> void:
	loot_resolved.clear()
	loot_taken.clear()
	for _index in range(reward_module_ids.size()):
		loot_resolved.append(false)
		loot_taken.append(false)

func has_pending_loot() -> bool:
	if reward_module_ids.is_empty():
		return false
	if loot_resolved.size() != reward_module_ids.size():
		return true
	for resolved in loot_resolved:
		if not resolved:
			return true
	return false
