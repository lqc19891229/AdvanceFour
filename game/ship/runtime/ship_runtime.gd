class_name ShipRuntime
extends Node2D

signal weapon_fired(
	module_instance: ShipModuleInstance,
	firepower: float,
	world_position: Vector2,
	world_direction: Vector2
)
signal projectile_spawned(projectile: ProjectileRuntime)
signal projectile_hit(target: Node2D, firepower: float)
signal hull_cell_damaged(
	hull_cell: ShipHullCell,
	amount: float,
	current_hp: float
)
signal hull_cell_destroyed(hull_cell: ShipHullCell)
signal equipment_efficiency_changed(
	module_instance: ShipModuleInstance,
	efficiency: float
)
signal energy_state_changed(
	energy_output: float,
	energy_cost: float,
	sufficient: bool
)
signal destroyed

const WEAPON_RUNTIME_SCENE := preload("res://game/ship/weapon/weapon_runtime.tscn")
const PROJECTILE_RUNTIME_SCENE := preload("res://game/ship/projectile/projectile_runtime.tscn")

@export var cell_size := 36.0
@export var speed_scale := 2.5
@export var acceleration_scale := 1.0
@export var deceleration_scale := 1.5
@export var turn_speed_degrees := 120.0
@export var reverse_thrust_ratio := 0.5
@export var weapon_target_group: StringName = &"enemy_targets"

var ship_data: ShipData
var velocity := Vector2.ZERO
var throttle_input := 0.0
var turn_input := 0.0
var local_origin_offset := Vector2.ZERO
var core_origin_valid := false

var appearance_renderer: ShipAppearanceRenderer
var hull_runtimes: Array[HullCellRuntime] = []
var hull_runtime_by_position: Dictionary = {}
var module_runtimes: Array[ShipModuleRuntime] = []
var module_runtime_by_uid: Dictionary = {}
var weapon_runtimes: Array[WeaponRuntime] = []
var weapon_runtime_by_uid: Dictionary = {}
var module_powered_by_uid: Dictionary = {}
var energy_sufficient := true
var removed_from_battle := false

func setup(data: ShipData) -> void:
	_clear_weapon_runtimes()
	_clear_module_runtimes()
	_clear_appearance_renderer()
	_clear_hull_runtimes()
	ship_data = data
	removed_from_battle = false
	velocity = Vector2.ZERO
	throttle_input = 0.0
	turn_input = 0.0
	rotation = 0.0
	local_origin_offset = _calculate_core_origin_offset()
	_build_hull_runtimes()
	_build_appearance_renderer()
	_build_module_runtimes()
	_build_weapon_runtimes()
	module_powered_by_uid.clear()
	_refresh_equipment_state()

func set_control_input(throttle: float, turn: float) -> void:
	if removed_from_battle:
		return
	throttle_input = clampf(throttle, -1.0, 1.0)
	turn_input = clampf(turn, -1.0, 1.0)

func request_fire() -> void:
	if removed_from_battle:
		return
	for weapon_runtime in weapon_runtimes:
		if is_instance_valid(weapon_runtime):
			weapon_runtime.fire_once()

func get_weapon_count() -> int:
	return weapon_runtimes.size()

func get_operational_weapon_count() -> int:
	var count := 0
	for weapon_runtime in weapon_runtimes:
		if is_instance_valid(weapon_runtime) and weapon_runtime.is_operational():
			count += 1
	return count

func get_active_weapon_count() -> int:
	var count := 0
	for weapon_runtime in weapon_runtimes:
		if is_instance_valid(weapon_runtime) and weapon_runtime.is_active():
			count += 1
	return count

func get_module_runtime_count() -> int:
	return module_runtimes.size()

func get_module_runtime(module: ShipModuleInstance) -> ShipModuleRuntime:
	if module == null:
		return null
	return module_runtime_by_uid.get(module.uid, null) as ShipModuleRuntime

func get_hull_runtime(cell: ShipHullCell) -> HullCellRuntime:
	if cell == null:
		return null
	return hull_runtime_by_position.get(cell.grid_position, null) as HullCellRuntime

func get_module_efficiency(module: ShipModuleInstance) -> float:
	if ship_data == null or module == null or module.definition == null:
		return 0.0
	var cells := module.get_cells()
	if cells.is_empty():
		return 0.0

	var total := 0.0
	for position in cells:
		var hull := ship_data.get_hull_cell_at(position)
		if hull == null:
			return 0.0
		total += hull.get_health_ratio()
	return clampf(total / float(cells.size()), 0.0, 1.0)

func has_operational_modules() -> bool:
	if removed_from_battle or ship_data == null:
		return false
	for cell in ship_data.get_hull_cells():
		if not cell.is_destroyed():
			return true
	return false

func get_aim_point(from_world_position: Vector2) -> Vector2:
	var best_point := global_position
	var best_distance_squared := INF
	for hull_runtime in hull_runtimes:
		if not is_instance_valid(hull_runtime) or hull_runtime.is_destroyed():
			continue
		var point := hull_runtime.global_position
		var distance_squared := from_world_position.distance_squared_to(point)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_point = point
	return best_point

func get_current_hull_hp() -> float:
	return 0.0 if ship_data == null else ship_data.get_total_hull_hp()

func get_core_efficiency() -> float:
	var core := _get_core_module()
	return 0.0 if core == null else get_module_efficiency(core)

func get_max_hull_hp() -> float:
	return 0.0 if ship_data == null else ship_data.get_total_hull_max_hp()

func get_effective_energy_output() -> float:
	if ship_data == null:
		return 0.0
	var total := 0.0
	for module in ship_data.modules:
		if module.definition is EnergyModuleDefinition:
			total += (
				module.definition as EnergyModuleDefinition
			).energy_output * get_module_efficiency(module)
	return total

func get_effective_energy_cost() -> float:
	if ship_data == null:
		return 0.0
	var total := 0.0
	for module in ship_data.modules:
		if _is_module_operational(module):
			total += module.definition.energy_cost
	return total

func get_powered_energy_cost() -> float:
	if ship_data == null:
		return 0.0
	var total := 0.0
	for module in ship_data.modules:
		if is_module_powered(module):
			total += module.definition.energy_cost
	return total

func get_effective_protection() -> float:
	if ship_data == null:
		return 0.0
	var total := 0.0
	for module in ship_data.modules:
		if not (module.definition is DefenseModuleDefinition):
			continue
		if not _is_module_operational(module) or not is_module_powered(module):
			continue
		total += (
			module.definition as DefenseModuleDefinition
		).protection * get_module_efficiency(module)
	return clampf(total, 0.0, 100.0)

func is_energy_sufficient() -> bool:
	return energy_sufficient

func is_module_powered(module: ShipModuleInstance) -> bool:
	if module == null:
		return false
	return bool(module_powered_by_uid.get(module.uid, false))

func get_powered_module_count() -> int:
	if ship_data == null:
		return 0
	var count := 0
	for module in ship_data.modules:
		if is_module_powered(module):
			count += 1
	return count

func get_effective_thrust() -> float:
	if ship_data == null:
		return 0.0
	var total := 0.0
	for module in ship_data.modules:
		if not (module.definition is PropulsionModuleDefinition):
			continue
		if not _is_module_operational(module) or not is_module_powered(module):
			continue
		total += (
			module.definition as PropulsionModuleDefinition
		).thrust * get_module_efficiency(module)
	return total

func get_effective_acceleration_score() -> float:
	# Movement is intentionally thrust-only; Hull size and Equipment do not add movement mass.
	return get_effective_thrust()

func is_removed_from_battle() -> bool:
	return removed_from_battle

func get_speed() -> float:
	return velocity.length()

func get_max_speed() -> float:
	return get_effective_acceleration_score() * speed_scale

func get_acceleration() -> float:
	return get_effective_acceleration_score() * acceleration_scale

func get_deceleration() -> float:
	return get_effective_acceleration_score() * deceleration_scale

func estimate_design_top_speed(design: ShipData) -> float:
	return 0.0 if design == null else design.get_thrust() * speed_scale

func get_heading_degrees() -> float:
	return wrapf(rad_to_deg(rotation), 0.0, 360.0)

func get_local_origin_offset() -> Vector2:
	return local_origin_offset

func has_core_origin() -> bool:
	return core_origin_valid

func apply_hull_projectile_damage(hull_cell: ShipHullCell, amount: float) -> float:
	if removed_from_battle or hull_cell == null or ship_data == null:
		return maxf(amount, 0.0)
	if ship_data.get_hull_cell_at(hull_cell.grid_position) != hull_cell:
		return maxf(amount, 0.0)

	var incoming := maxf(amount, 0.0)
	if incoming <= 0.0:
		return 0.0

	var protection := get_effective_protection()
	var damage_after_protection := incoming * (1.0 - protection / 100.0)
	var effective_max_hp := ship_data.get_hull_cell_effective_max_hp(hull_cell)
	var effective_hp_before := ship_data.get_hull_cell_effective_hp(hull_cell)
	var base_max_hp := maxf(hull_cell.max_hp, 0.0)

	var leftover := damage_after_protection
	if effective_max_hp > 0.0 and base_max_hp > 0.0:
		var hp_scale := effective_max_hp / base_max_hp
		var base_damage := damage_after_protection / hp_scale
		var base_leftover := hull_cell.apply_damage(base_damage)
		leftover = base_leftover * hp_scale

	var effective_hp_after := ship_data.get_hull_cell_effective_hp(hull_cell)
	var actual_damage := maxf(effective_hp_before - effective_hp_after, 0.0)

	var runtime := get_hull_runtime(hull_cell)
	if runtime != null:
		runtime.notify_damage(actual_damage)
	hull_cell_damaged.emit(hull_cell, actual_damage, effective_hp_after)

	_refresh_equipment_state()
	if appearance_renderer != null:
		appearance_renderer.refresh()

	if hull_cell.is_destroyed():
		hull_cell_destroyed.emit(hull_cell)
		var core := _get_core_module()
		if core != null and get_module_efficiency(core) <= 0.0:
			_remove_from_battle()

	return leftover

func _physics_process(delta: float) -> void:
	if removed_from_battle or ship_data == null:
		return

	if not is_zero_approx(turn_input):
		rotation += deg_to_rad(turn_speed_degrees) * turn_input * delta

	var acceleration := get_acceleration()
	var max_speed := get_max_speed()

	if not is_zero_approx(throttle_input):
		var thrust_ratio := 1.0 if throttle_input > 0.0 else reverse_thrust_ratio
		var forward := Vector2.UP.rotated(rotation)
		velocity += forward * acceleration * thrust_ratio * throttle_input * delta
	else:
		velocity = velocity.move_toward(Vector2.ZERO, get_deceleration() * delta)

	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	position += velocity * delta

func _build_appearance_renderer() -> void:
	if ship_data == null:
		return
	appearance_renderer = ShipAppearanceRenderer.new()
	add_child(appearance_renderer)
	appearance_renderer.setup(ship_data, cell_size, local_origin_offset)

func _clear_appearance_renderer() -> void:
	if appearance_renderer != null and is_instance_valid(appearance_renderer):
		appearance_renderer.queue_free()
	appearance_renderer = null

func _build_hull_runtimes() -> void:
	if ship_data == null:
		return
	for cell in ship_data.get_hull_cells():
		var runtime := HullCellRuntime.new()
		add_child(runtime)
		runtime.setup(
			cell,
			self,
			(Vector2(cell.grid_position) + Vector2(0.5, 0.5)) * cell_size - local_origin_offset,
			Vector2.ONE * cell_size
		)
		hull_runtimes.append(runtime)
		hull_runtime_by_position[cell.grid_position] = runtime

func _clear_hull_runtimes() -> void:
	for runtime in hull_runtimes:
		if is_instance_valid(runtime):
			runtime.queue_free()
	hull_runtimes.clear()
	hull_runtime_by_position.clear()

func _build_module_runtimes() -> void:
	if ship_data == null:
		return
	for module in ship_data.modules:
		var runtime := ShipModuleRuntime.new()
		add_child(runtime)
		runtime.setup(
			module,
			_get_module_local_center(module),
			Vector2(module.get_rotated_size()) * cell_size
		)
		module_runtimes.append(runtime)
		module_runtime_by_uid[module.uid] = runtime

func _clear_module_runtimes() -> void:
	for runtime in module_runtimes:
		if is_instance_valid(runtime):
			runtime.queue_free()
	module_runtimes.clear()
	module_runtime_by_uid.clear()

func _build_weapon_runtimes() -> void:
	if ship_data == null:
		return
	for module in ship_data.modules:
		if not (module.definition is WeaponModuleDefinition):
			continue
		var runtime := WEAPON_RUNTIME_SCENE.instantiate() as WeaponRuntime
		add_child(runtime)
		runtime.setup(self, module, _get_module_local_center(module), weapon_target_group)
		runtime.fired.connect(_on_weapon_runtime_fired)
		weapon_runtimes.append(runtime)
		weapon_runtime_by_uid[module.uid] = runtime

func _clear_weapon_runtimes() -> void:
	for runtime in weapon_runtimes:
		if is_instance_valid(runtime):
			runtime.queue_free()
	weapon_runtimes.clear()
	weapon_runtime_by_uid.clear()

func _get_module_local_center(module: ShipModuleInstance) -> Vector2:
	var size := module.get_rotated_size()
	return (
		Vector2(module.grid_position) + Vector2(size) * 0.5
	) * cell_size - local_origin_offset

func _refresh_equipment_state() -> void:
	if ship_data == null:
		return
	for module in ship_data.modules:
		var efficiency := get_module_efficiency(module)
		var runtime := get_module_runtime(module)
		if runtime != null:
			runtime.set_efficiency(efficiency)
		var weapon := weapon_runtime_by_uid.get(module.uid, null) as WeaponRuntime
		if weapon != null and is_instance_valid(weapon):
			weapon.set_efficiency(efficiency)
		equipment_efficiency_changed.emit(module, efficiency)
	_refresh_energy_state()

func _refresh_energy_state() -> void:
	var energy_output := get_effective_energy_output()
	var energy_cost := get_effective_energy_cost()
	energy_sufficient = energy_output >= energy_cost
	module_powered_by_uid.clear()

	var remaining_energy := energy_output
	var candidates: Array[ShipModuleInstance] = []
	if ship_data != null:
		for module in ship_data.modules:
			if _is_module_operational(module):
				candidates.append(module)

	candidates.sort_custom(_compare_power_priority)
	for module in candidates:
		var cost := maxf(module.definition.energy_cost, 0.0)
		var powered := cost <= remaining_energy
		module_powered_by_uid[module.uid] = powered
		if powered:
			remaining_energy -= cost

	for weapon_runtime in weapon_runtimes:
		if not is_instance_valid(weapon_runtime):
			continue
		weapon_runtime.set_powered(is_module_powered(weapon_runtime.module_instance))

	energy_state_changed.emit(energy_output, energy_cost, energy_sufficient)

func _compare_power_priority(a: ShipModuleInstance, b: ShipModuleInstance) -> bool:
	var a_priority := _get_power_priority(a)
	var b_priority := _get_power_priority(b)
	if a_priority == b_priority:
		return a.uid < b.uid
	return a_priority < b_priority

func _get_power_priority(module: ShipModuleInstance) -> int:
	if module == null or module.definition == null:
		return 999
	match module.definition.module_type:
		ShipModuleDefinition.ModuleType.CORE:
			return 0
		ShipModuleDefinition.ModuleType.ENERGY:
			return 1
		ShipModuleDefinition.ModuleType.PROPULSION:
			return 2
		ShipModuleDefinition.ModuleType.DEFENSE:
			return 3
		ShipModuleDefinition.ModuleType.FUNCTION:
			return 4
		ShipModuleDefinition.ModuleType.WEAPON:
			return 5
	return 999

func _remove_from_battle() -> void:
	if removed_from_battle:
		return
	removed_from_battle = true
	throttle_input = 0.0
	turn_input = 0.0
	velocity = Vector2.ZERO
	for weapon_runtime in weapon_runtimes:
		if is_instance_valid(weapon_runtime):
			weapon_runtime.set_operational(false)
	destroyed.emit()
	queue_free()

func _on_weapon_runtime_fired(
	module_instance: ShipModuleInstance,
	firepower: float,
	world_position: Vector2,
	world_direction: Vector2
) -> void:
	var weapon := weapon_runtime_by_uid.get(module_instance.uid) as WeaponRuntime
	if not is_instance_valid(weapon):
		return
	var projectile_range := maxf(weapon.attack_range, 0.0)
	var projectile_speed := maxf(weapon.projectile_speed, 0.0)
	weapon_fired.emit(module_instance, firepower, world_position, world_direction)
	_spawn_projectile(
		world_position,
		world_direction,
		firepower,
		projectile_range,
		projectile_speed
	)

func _spawn_projectile(
	world_position: Vector2,
	world_direction: Vector2,
	firepower: float,
	projectile_range: float,
	projectile_speed: float
) -> void:
	var projectile_parent := get_parent()
	if projectile_parent == null:
		return
	var projectile := PROJECTILE_RUNTIME_SCENE.instantiate() as ProjectileRuntime
	projectile_parent.add_child(projectile)
	projectile.setup(
		world_position,
		world_direction,
		firepower,
		self,
		projectile_range,
		projectile_speed
	)
	projectile.hit.connect(_on_projectile_hit)
	projectile_spawned.emit(projectile)

func _on_projectile_hit(target: Node2D, firepower: float) -> void:
	projectile_hit.emit(target, firepower)

func _is_module_operational(module: ShipModuleInstance) -> bool:
	return get_module_efficiency(module) > 0.0

func _get_core_module() -> ShipModuleInstance:
	if ship_data == null:
		return null
	for module in ship_data.modules:
		if module.definition is CoreModuleDefinition:
			return module
	return null

func _calculate_core_origin_offset() -> Vector2:
	core_origin_valid = false
	if ship_data == null:
		return Vector2.ZERO
	var core := _get_core_module()
	if core == null:
		return Vector2.ZERO
	core_origin_valid = true
	var size := core.get_rotated_size()
	return (
		Vector2(core.grid_position) + Vector2(size) * 0.5
	) * cell_size
