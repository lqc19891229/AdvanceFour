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
var firing_arc_degrees := 360.0
var fire_angle_tolerance_degrees := 6.0
var target_group: StringName = &"enemy_targets"

var owner_ship: Node2D
var module_instance: ShipModuleInstance
var weapon_definition: WeaponModuleDefinition
var target: Node2D
var turret_visual: Sprite2D
var mount_local_rotation := 0.0
var cooldown_remaining := 0.0
var operational := true
var powered := true
var efficiency := 1.0

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
		firing_arc_degrees = weapon_definition.firing_arc_degrees
		fire_angle_tolerance_degrees = weapon_definition.fire_angle_tolerance_degrees
	position = local_position
	z_index = 30
	target_group = p_target_group
	mount_local_rotation = deg_to_rad(float(module.rotation_quarters) * 90.0)
	rotation = mount_local_rotation
	target = null
	cooldown_remaining = 0.0
	operational = true
	powered = true
	efficiency = 1.0
	visible = true
	_build_turret_visual()
	queue_redraw()

func _build_turret_visual() -> void:
	if turret_visual != null and is_instance_valid(turret_visual):
		turret_visual.queue_free()
	turret_visual = null

	if weapon_definition == null or weapon_definition.size != Vector2i.ONE:
		return

	var texture := ModuleArtLibrary.get_turret_texture(weapon_definition)
	if texture == null:
		return

	turret_visual = Sprite2D.new()
	turret_visual.texture = texture
	turret_visual.centered = true
	turret_visual.scale = ModuleArtLibrary.get_texture_scale(
		texture,
		Vector2(32.0, 32.0)
	)
	add_child(turret_visual)

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

func set_efficiency(value: float) -> void:
	efficiency = clampf(value, 0.0, 1.0)
	if efficiency <= 0.0:
		target = null
	if turret_visual != null:
		var brightness := 0.35 + 0.65 * efficiency
		turret_visual.modulate = Color(brightness, brightness, brightness, 1.0)

func get_efficiency() -> float:
	return efficiency

func is_powered() -> bool:
	return powered

func is_active() -> bool:
	return operational and powered and efficiency > 0.0

func fire_once() -> void:
	if not _can_fire():
		return
	_emit_fire()
	cooldown_remaining = maxf(fire_interval / maxf(efficiency, 0.05), 0.0)

func get_target() -> Node2D:
	return target

func has_target() -> bool:
	return _is_target_valid(target)

func _physics_process(delta: float) -> void:
	if owner_ship == null or not is_instance_valid(owner_ship):
		return
	if module_instance == null or weapon_definition == null:
		return
	global_rotation = _clamp_global_rotation_to_firing_arc(global_rotation)
	if not is_active():
		return

	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)

	if not _is_target_valid(target):
		target = _find_nearest_target()

	if target == null:
		return

	_aim_at_target(delta)

	if _can_fire() and _is_aimed_at_target():
		fire_once()

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
		var to_target := aim_point - global_position
		var distance_squared := to_target.length_squared()
		if distance_squared > max_distance_squared:
			continue
		if not is_world_direction_inside_firing_arc(to_target):
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
	var to_target := aim_point - global_position
	return (
		to_target.length_squared() <= attack_range * attack_range
		and is_world_direction_inside_firing_arc(to_target)
	)

func get_firing_arc_center_global_rotation() -> float:
	if owner_ship == null or not is_instance_valid(owner_ship):
		return mount_local_rotation
	return owner_ship.global_rotation + mount_local_rotation

func get_muzzle_world_direction() -> Vector2:
	return ModuleArtLibrary.WEAPON_FORWARD.rotated(global_rotation).normalized()

func is_world_direction_inside_firing_arc(world_direction: Vector2) -> bool:
	if world_direction.is_zero_approx():
		return true
	var arc := clampf(firing_arc_degrees, 0.0, 360.0)
	if arc >= 359.999:
		return true
	var direction_rotation := ModuleArtLibrary.WEAPON_FORWARD.angle_to(world_direction.normalized())
	var center_rotation := get_firing_arc_center_global_rotation()
	var difference := absf(wrapf(direction_rotation - center_rotation, -PI, PI))
	return difference <= deg_to_rad(arc * 0.5) + 0.000001

func _clamp_global_rotation_to_firing_arc(desired_global_rotation: float) -> float:
	var arc := clampf(firing_arc_degrees, 0.0, 360.0)
	if arc >= 359.999:
		return desired_global_rotation
	var center_rotation := get_firing_arc_center_global_rotation()
	var relative_rotation := wrapf(desired_global_rotation - center_rotation, -PI, PI)
	var half_arc := deg_to_rad(arc * 0.5)
	return center_rotation + clampf(relative_rotation, -half_arc, half_arc)

func _aim_at_target(delta: float) -> void:
	var aim_point := _get_target_aim_point(target)
	var to_target := aim_point - global_position
	if to_target.is_zero_approx():
		return

	var desired_global_rotation := ModuleArtLibrary.WEAPON_FORWARD.angle_to(to_target.normalized())
	var allowed_global_rotation := _clamp_global_rotation_to_firing_arc(desired_global_rotation)
	var max_step := deg_to_rad(maxf(turn_speed_degrees * efficiency, 0.0)) * maxf(delta, 0.0)
	if clampf(firing_arc_degrees, 0.0, 360.0) >= 359.999:
		global_rotation = rotate_toward(global_rotation, allowed_global_rotation, max_step)
		return

	# A finite arc is an interval around the mount, not a circular shortest path.
	# Even for arcs wider than 180 degrees, never rotate through the forbidden sector.
	var center_rotation := get_firing_arc_center_global_rotation()
	var current_rotation := _clamp_global_rotation_to_firing_arc(global_rotation)
	var current_relative := wrapf(current_rotation - center_rotation, -PI, PI)
	var desired_relative := wrapf(allowed_global_rotation - center_rotation, -PI, PI)
	global_rotation = center_rotation + move_toward(current_relative, desired_relative, max_step)

func _is_aimed_at_target() -> bool:
	if target == null:
		return false

	var aim_point := _get_target_aim_point(target)
	var to_target := aim_point - global_position
	if to_target.is_zero_approx():
		return true

	if not is_world_direction_inside_firing_arc(to_target):
		return false

	var desired_global_rotation := ModuleArtLibrary.WEAPON_FORWARD.angle_to(to_target.normalized())
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
		and is_world_direction_inside_firing_arc(get_muzzle_world_direction())
	)

func _emit_fire() -> void:
	var direction := get_muzzle_world_direction()
	fired.emit(
		module_instance,
		weapon_definition.firepower * efficiency,
		global_position,
		direction
	)

func _draw() -> void:
	if turret_visual != null and is_instance_valid(turret_visual):
		return
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE, false, 1.0)
	draw_line(Vector2.ZERO, ModuleArtLibrary.WEAPON_FORWARD * 16.0, Color.WHITE, 2.0)
