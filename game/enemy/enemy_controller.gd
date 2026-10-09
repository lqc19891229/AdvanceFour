class_name EnemyController
extends Node

@export var target_group: StringName = &"player_targets"
var ship: ShipRuntime
var definition: EnemyShipDefinition
var target: ShipRuntime

func setup(enemy: ShipRuntime, config: EnemyShipDefinition) -> void:
	ship = enemy
	definition = config
	process_physics_priority = -10

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(ship) or ship.is_removed_from_battle():
		return
	if not is_instance_valid(target) or target.is_removed_from_battle():
		target = _find_target()
	if target == null:
		ship.set_control_input(0.0, 0.0)
		return
	var offset := target.global_position - ship.global_position
	if offset.is_zero_approx():
		ship.set_control_input(0.0, 0.0)
		return
	var angle := Vector2.UP.rotated(ship.global_rotation).angle_to(offset)
	var turn := clampf(angle / deg_to_rad(45.0), -1.0, 1.0)
	var distance := offset.length()
	var thrust := 0.0
	if absf(angle) < deg_to_rad(60.0):
		if distance > definition.approach_distance:
			thrust = 1.0
		elif distance < definition.retreat_distance:
			thrust = -1.0
	ship.set_control_input(thrust, turn)

func _find_target() -> ShipRuntime:
	for candidate in get_tree().get_nodes_in_group(target_group):
		if candidate is ShipRuntime and not candidate.is_removed_from_battle():
			return candidate as ShipRuntime
	return null
