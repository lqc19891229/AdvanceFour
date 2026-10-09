class_name EnemyController
extends Node

@export var target_group: StringName = &"player_targets"
var ship: EnemyRuntime

func setup(enemy: EnemyRuntime) -> void:
	ship = enemy
	process_physics_priority = -10

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(ship) or ship.is_removed_from_battle():
		return
	if not is_instance_valid(ship.target) or ship.target.is_removed_from_battle():
		ship.target = _find_target()
	if ship.target == null:
		ship.set_control_input(0.0, 0.0)
		return
	var offset := ship.target.global_position - ship.global_position
	if offset.is_zero_approx():
		return
	var angle := Vector2.UP.rotated(ship.global_rotation).angle_to(offset)
	var turn := clampf(angle / deg_to_rad(45.0), -1.0, 1.0)
	var distance := offset.length()
	var thrust := 0.0
	if absf(angle) < deg_to_rad(60.0):
		if distance > ship.definition.approach_distance:
			thrust = 1.0
		elif distance < ship.definition.retreat_distance:
			thrust = -1.0
	ship.set_control_input(thrust, turn)

func _find_target() -> Node2D:
	for candidate in get_tree().get_nodes_in_group(target_group):
		if candidate is Node2D and candidate.has_method("is_removed_from_battle") and not candidate.is_removed_from_battle():
			return candidate
	return null
