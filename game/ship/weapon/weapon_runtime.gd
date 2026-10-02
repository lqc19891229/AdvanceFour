class_name WeaponRuntime
extends Node2D

signal fired(
	module_instance: ShipModuleInstance,
	firepower: float,
	world_position: Vector2,
	world_direction: Vector2
)

var attack_range := 500.0
var fire_interval := 0.5
var turn_speed_degrees := 180.0
var projectile_speed := 700.0
var fire_angle_tolerance_degrees := 6.0
var target_group: StringName = &"enemy_targets"

var owner_ship: Node2D
var module_instance: ShipModuleInstance
var weapon_definition: WeaponModuleDefinition
var target: Node2D
var cooldown_remaining := 0.0
var operational := true
var powered := true

func setup(
	ship: Node2D,
	module: ShipModuleInstance,
	local_position: Vector2,
	p_target_group: StringName = &"enemy_targets"
) -> void:
	owner_ship = ship
	module_instance = module
	weapon_definition = module.definition as WeaponModuleDefinition
	if weapon_definition != null:
		attack_range = weapon_definition.attack_range
		fire_interval = weapon_definition.fire_interval
		turn_speed_degrees = weapon_definition.turn_speed_degrees
		projectile_speed = weapon_definition.projectile_speed
		fire_angle_tolerance_degrees = weapon_definition.fire_angle_tolerance_degrees
	position = local_position
	target_group = p_target_group
	rotation = deg_to_rad(float(module.rotation_quarters) * 90.0)
	target = null
	cooldown_remaining = 0.0
	operational = true
	powered = true
	visible = true
	queue_redraw()

func set_operational(value: bool) -> void:
	operational = value
	if not operational:
		target = null
		visible = false

func is_operational() -> bool:
	return operational

func set_powered(value: bool) -> void:
	powered = value
	if not powered:
		target = null

func is_powered() -> bool:
	return powered

func is_active() -> bool:
	return operational and powered

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
	if not is_active():
		return
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
		if node.has_method("has_operational_modules") and not node.has_operational_modules():
			continue

		var aim_point := _get_target_aim_point(node)
		var distance_squared := global_position.distance_squared_to(aim_point)
		if distance_squared > max_distance_squared:
			continue
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_target = node

	return best_target

# A destroyed ship can be freed between physics frames; validate before using its type.
func _is_target_valid(candidate) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if not candidate.is_inside_tree():
		return false
	if candidate.is_queued_for_deletion():
		return false
	if not candidate.is_in_group(target_group):
		return false
	if candidate.has_method("has_operational_modules") and not candidate.has_operational_modules():
		return false

	var aim_point := _get_target_aim_point(candidate)
	return global_position.distance_squared_to(aim_point) <= attack_range * attack_range

func _aim_at_target(delta: float) -> void:
	var aim_point := _get_target_aim_point(target)
	var to_target := aim_point - global_position
	if to_target.is_zero_approx():
		return

	var desired_global_rotation := Vector2.UP.angle_to(to_target.normalized())
	var max_step := deg_to_rad(turn_speed_degrees) * delta
	global_rotation = rotate_toward(global_rotation, desired_global_rotation, max_step)

func _is_aimed_at_target() -> bool:
	if target == null:
		return false

	var aim_point := _get_target_aim_point(target)
	var to_target := aim_point - global_position
	if to_target.is_zero_approx():
		return true

	var desired_global_rotation := Vector2.UP.angle_to(to_target.normalized())
	var difference := absf(wrapf(desired_global_rotation - global_rotation, -PI, PI))
	return difference <= deg_to_rad(fire_angle_tolerance_degrees)

func _get_target_aim_point(candidate: Node2D) -> Vector2:
	if candidate != null and candidate.has_method("get_aim_point"):
		return candidate.get_aim_point(global_position)
	return candidate.global_position

func _can_fire() -> bool:
	return (
		is_active()
		and owner_ship != null
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
