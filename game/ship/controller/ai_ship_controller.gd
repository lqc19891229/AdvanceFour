class_name AIShipController
extends Node

# Controller parameters are Prototype tuning, not module source data.
@export var target_group: StringName = &"player_targets"
@export var acquisition_range := 1600.0
@export var approach_distance := 280.0
@export var retreat_distance := 180.0
@export var turn_dead_zone_degrees := 3.0
@export var full_turn_angle_degrees := 45.0
@export var thrust_angle_limit_degrees := 60.0

var runtime_ship: ShipRuntime
var target: ShipRuntime

func _init() -> void:
	# Sample before RuntimeShip executes movement in the same physics frame.
	process_physics_priority = -10

func setup(ship: ShipRuntime) -> void:
	clear_target()
	runtime_ship = ship

func clear_target() -> void:
	if is_instance_valid(runtime_ship):
		runtime_ship.set_control_input(0.0, 0.0)
	runtime_ship = null
	target = null

func _exit_tree() -> void:
	clear_target()

func _physics_process(_delta: float) -> void:
	if not _is_ship_valid(runtime_ship):
		target = null
		return

	if not _is_target_valid(target):
		target = _find_nearest_target()
	if target == null:
		runtime_ship.set_control_input(0.0, 0.0)
		return

	var offset := target.global_position - runtime_ship.global_position
	if offset.is_zero_approx():
		runtime_ship.set_control_input(0.0, 0.0)
		return

	var forward := Vector2.UP.rotated(runtime_ship.global_rotation)
	var angle := forward.angle_to(offset)
	var turn := 0.0
	if absf(angle) > deg_to_rad(maxf(turn_dead_zone_degrees, 0.0)):
		turn = clampf(angle / deg_to_rad(maxf(full_turn_angle_degrees, 1.0)), -1.0, 1.0)

	var throttle := 0.0
	if absf(angle) <= deg_to_rad(maxf(thrust_angle_limit_degrees, 0.0)):
		var distance := offset.length()
		var near_distance := maxf(retreat_distance, 0.0)
		var far_distance := maxf(approach_distance, near_distance)
		if distance > far_distance:
			throttle = 1.0
		elif distance < near_distance:
			throttle = -1.0

	runtime_ship.set_control_input(throttle, turn)

func _find_nearest_target() -> ShipRuntime:
	var best: ShipRuntime
	var best_distance_squared := INF
	for candidate in get_tree().get_nodes_in_group(target_group):
		var ship := candidate as ShipRuntime
		if not _is_target_valid(ship):
			continue
		var distance_squared := runtime_ship.global_position.distance_squared_to(ship.global_position)
		if distance_squared < best_distance_squared:
			best = ship
			best_distance_squared = distance_squared
	return best

# Accept Variant so a freed reference can reach is_instance_valid before type validation.
func _is_target_valid(ship) -> bool:
	return (
		_is_ship_valid(ship)
		and ship != runtime_ship
		and ship.is_in_group(target_group)
		and runtime_ship.global_position.distance_squared_to(ship.global_position)
			<= pow(maxf(acquisition_range, 0.0), 2.0)
	)

func _is_ship_valid(ship) -> bool:
	return (
		is_instance_valid(ship)
		and ship.is_inside_tree()
		and not ship.is_queued_for_deletion()
		and not ship.is_removed_from_battle()
		and ship.has_operational_modules()
	)
