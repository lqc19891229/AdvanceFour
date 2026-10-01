class_name WeaponRuntime
extends Node2D

signal fired(
	module_instance: ShipModuleInstance,
	firepower: float,
	world_position: Vector2,
	world_direction: Vector2
)

@export var attack_range := 500.0
@export var fire_interval := 0.5
@export var turn_speed_degrees := 180.0
@export var fire_angle_tolerance_degrees := 6.0
var target_group: StringName = &"enemy_targets"

var owner_ship: Node2D
var module_instance: ShipModuleInstance
var weapon_definition: WeaponModuleDefinition
var target: Node2D
var cooldown_remaining := 0.0

func setup(
	ship: Node2D,
	module: ShipModuleInstance,
	local_position: Vector2,
	p_target_group: StringName = &"enemy_targets"
) -> void:
	owner_ship = ship
	module_instance = module
	weapon_definition = module.definition as WeaponModuleDefinition
	position = local_position
	target_group = p_target_group
	rotation = deg_to_rad(float(module.rotation_quarters) * 90.0)
	target = null
	cooldown_remaining = 0.0
	queue_redraw()

func fire_once() -> void:
	if not _can_fire():
		return
	_emit_fire()
	cooldown_remaining = maxf(fire_interval, 0.0)

func get_target() -> Node2D:
	return target

func has_target() -> bool:
	return _is_target_valid(target)

func _physics_process(delta: float) -> void:
	if owner_ship == null or not is_instance_valid(owner_ship):
		return
	if module_instance == null or weapon_definition == null:
		return

	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)

	if not _is_target_valid(target):
		target = _find_nearest_target()

	if target == null:
		return

	_aim_at_target(delta)

	if cooldown_remaining <= 0.0 and _is_aimed_at_target():
		_emit_fire()
		cooldown_remaining = maxf(fire_interval, 0.0)

func _find_nearest_target() -> Node2D:
	var best_target: Node2D
	var best_distance_squared := INF
	var max_distance_squared := attack_range * attack_range

	for candidate in get_tree().get_nodes_in_group(target_group):
		if not (candidate is Node2D):
			continue
		var node := candidate as Node2D
		if node == owner_ship or not is_instance_valid(node):
			continue

		var distance_squared := global_position.distance_squared_to(node.global_position)
		if distance_squared > max_distance_squared:
			continue
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_target = node

	return best_target

func _is_target_valid(candidate: Node2D) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if not candidate.is_inside_tree():
		return false
	if not candidate.is_in_group(target_group):
		return false
	return global_position.distance_squared_to(candidate.global_position) <= attack_range * attack_range

func _aim_at_target(delta: float) -> void:
	var to_target := target.global_position - global_position
	if to_target.is_zero_approx():
		return

	var desired_global_rotation := Vector2.UP.angle_to(to_target.normalized())
	var max_step := deg_to_rad(turn_speed_degrees) * delta
	global_rotation = rotate_toward(global_rotation, desired_global_rotation, max_step)

func _is_aimed_at_target() -> bool:
	if target == null:
		return false
	var to_target := target.global_position - global_position
	if to_target.is_zero_approx():
		return true

	var desired_global_rotation := Vector2.UP.angle_to(to_target.normalized())
	var difference := absf(wrapf(desired_global_rotation - global_rotation, -PI, PI))
	return difference <= deg_to_rad(fire_angle_tolerance_degrees)

func _can_fire() -> bool:
	return (
		owner_ship != null
		and is_instance_valid(owner_ship)
		and module_instance != null
		and weapon_definition != null
		and cooldown_remaining <= 0.0
	)

func _emit_fire() -> void:
	var direction := Vector2.UP.rotated(global_rotation).normalized()
	fired.emit(
		module_instance,
		weapon_definition.firepower,
		global_position,
		direction
	)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE, false, 1.0)
	draw_line(Vector2.ZERO, Vector2.UP * 16.0, Color.WHITE, 2.0)
