class_name BattleResult
extends RefCounted

enum Outcome { VICTORY, DEFEAT }

var outcome := Outcome.DEFEAT
var battle_id: StringName = &""
var battle_path := ""
var next_battle_path := ""
var ship_after_battle: ShipData
var reward_credits := 0
var enemies_destroyed := 0
var elapsed_seconds := 0.0

func is_victory() -> bool:
	return outcome == Outcome.VICTORY
