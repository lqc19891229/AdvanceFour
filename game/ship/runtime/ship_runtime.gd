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
signal module_damaged(
	module_instance: ShipModuleInstance,
	amount: float,
	current_hp: float
)
signal module_destroyed(module_instance: ShipModuleInstance)
signal energy_state_changed(
	energy_output: float,
	energy_cost: float,
	sufficient: bool
)
signal destroyed

const WEAPON_RUNTIME_SCENE := preload("res://game/ship/weapon/weapon_runtime.tscn")
const PROJECTILE_RUNTIME_SCENE := preload("res://game/ship/projectile/projectile_runtime.tscn")

@export var cell_size := 36.0
@export var acceleration_scale := 180.0
@export var drag := 2.5
@export var turn_speed_degrees := 120.0
@export var reverse_thrust_ratio := 0.5
@export var weapon_target_group: StringName = &"enemy_targets"
@export var prototype_module_hp := 20.0

var ship_data: ShipData
var velocity := Vector2.ZERO
var throttle_input := 0.0
var turn_input := 0.0
var local_origin_offset := Vector2.ZERO
var core_origin_valid := false
var weapon_runtimes: Array[WeaponRuntime] = []
var weapon_runtime_by_uid: Dictionary = {}
var module_runtimes: Array[ShipModuleRuntime] = []
var module_runtime_by_uid: Dictionary = {}
var module_powered_by_uid: Dictionary = {}
var energy_sufficient := true
var removed_from_battle := false

func setup(data: ShipData) -> void:
	_clear_weapon_runtimes()
	_clear_module_runtimes()
	ship_data = data
	removed_from_battle = false
	velocity = Vector2.ZERO
	throttle_input = 0.0
	turn_input = 0.0
	rotation = 0.0
	local_origin_offset = _calculate_core_origin_offset()
	_build_module_runtimes()
	_build_weapon_runtimes()
	module_powered_by_uid.clear()
	_refresh_energy_state()
	queue_redraw()

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
		if is_instance_valid(weapon_runtime) and weapon_runtime.is_active():
			count += 1
	return count

func get_module_runtime_count() -> int:
	return module_runtimes.size()

func get_module_runtime(module: ShipModuleInstance) -> ShipModuleRuntime:
	if module == null:
		return null
	return module_runtime_by_uid.get(module.uid, null) as ShipModuleRuntime

func has_operational_modules() -> bool:
	if removed_from_battle:
		return false
	for module_runtime in module_runtimes:
		if is_instance_valid(module_runtime) and not module_runtime.is_destroyed():
			return true
	return false

func get_aim_point(from_world_position: Vector2) -> Vector2:
	var best_point := global_position
	var best_distance_squared := INF

	for module_runtime in module_runtimes:
		if not is_instance_valid(module_runtime) or module_runtime.is_destroyed():
			continue
		var point := module_runtime.global_position
		var distance_squared := from_world_position.distance_squared_to(point)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_point = point

	return best_point

func get_effective_energy_output() -> float:
	if ship_data == null:
		return 0.0

	var total := 0.0
	for module in ship_data.modules:
		if not (module.definition is EnergyModuleDefinition):
			continue
		if not _is_module_operational(module):
			continue
		total += (module.definition as EnergyModuleDefinition).energy_output
	return total

func get_effective_energy_cost() -> float:
	if ship_data == null:
		return 0.0

	var total := 0.0
	for module in ship_data.modules:
		if not _is_module_operational(module):
			continue
		total += module.definition.energy_cost
	return total

func get_powered_energy_cost() -> float:
	if ship_data == null:
		return 0.0

	var total := 0.0
	for module in ship_data.modules:
		if not is_module_powered(module):
			continue
		total += module.definition.energy_cost
	return total

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
		total += (module.definition as PropulsionModuleDefinition).thrust
	return total

func get_effective_acceleration_score() -> float:
	if ship_data == null:
		return 0.0
	var mass := ship_data.get_mass()
	return 0.0 if mass <= 0.0 else get_effective_thrust() / mass

func is_removed_from_battle() -> bool:
	return removed_from_battle

func get_speed() -> float:
	return velocity.length()

func get_heading_degrees() -> float:
	return wrapf(rad_to_deg(rotation), 0.0, 360.0)

func get_local_origin_offset() -> Vector2:
	return local_origin_offset

func has_core_origin() -> bool:
	return core_origin_valid

func _physics_process(delta: float) -> void:
	if removed_from_battle or ship_data == null:
		return

	if not is_zero_approx(turn_input):
		rotation += deg_to_rad(turn_speed_degrees) * turn_input * delta

	if not is_zero_approx(throttle_input):
		var thrust_ratio := 1.0 if throttle_input > 0.0 else reverse_thrust_ratio
		var acceleration := get_effective_acceleration_score() * acceleration_scale * thrust_ratio
		var forward := Vector2.UP.rotated(rotation)
		velocity += forward * acceleration * throttle_input * delta

	velocity = velocity.move_toward(Vector2.ZERO, velocity.length() * drag * delta)
	position += velocity * delta

func _draw() -> void:
	if ship_data == null:
		return

	for module in ship_data.modules:
		var size := module.get_rotated_size()
		var rect := Rect2(
			Vector2(module.grid_position) * cell_size - local_origin_offset,
			Vector2(size) * cell_size
		)
		var module_runtime := get_module_runtime(module)
		var fill_color := _get_module_color(module.definition.module_type)
		if module_runtime != null and module_runtime.is_destroyed():
			fill_color = Color("#3a3a3a")
		draw_rect(rect.grow(-2.0), fill_color)
		draw_rect(rect.grow(-2.0), Color.WHITE, false, 1.0)

func _build_module_runtimes() -> void:
	if ship_data == null:
		return

	for module in ship_data.modules:
		var module_runtime := ShipModuleRuntime.new()
		add_child(module_runtime)
		module_runtime.setup(
			module,
			_get_module_local_center(module),
			Vector2(module.get_rotated_size()) * cell_size,
			prototype_module_hp
		)
		module_runtime.damaged.connect(_on_module_runtime_damaged)
		module_runtime.destroyed.connect(_on_module_runtime_destroyed)
		module_runtimes.append(module_runtime)
		module_runtime_by_uid[module.uid] = module_runtime

func _clear_module_runtimes() -> void:
	for module_runtime in module_runtimes:
		if is_instance_valid(module_runtime):
			module_runtime.queue_free()
	module_runtimes.clear()
	module_runtime_by_uid.clear()

func _build_weapon_runtimes() -> void:
	if ship_data == null:
		return

	for module in ship_data.modules:
		if not (module.definition is WeaponModuleDefinition):
			continue

		var weapon_runtime := WEAPON_RUNTIME_SCENE.instantiate() as WeaponRuntime
		add_child(weapon_runtime)
		weapon_runtime.setup(self, module, _get_module_local_center(module), weapon_target_group)
		weapon_runtime.fired.connect(_on_weapon_runtime_fired)
		weapon_runtimes.append(weapon_runtime)
		weapon_runtime_by_uid[module.uid] = weapon_runtime

func _clear_weapon_runtimes() -> void:
	for weapon_runtime in weapon_runtimes:
		if is_instance_valid(weapon_runtime):
			weapon_runtime.queue_free()
	weapon_runtimes.clear()
	weapon_runtime_by_uid.clear()

func _get_module_local_center(module: ShipModuleInstance) -> Vector2:
	var size := module.get_rotated_size()
	return (
		Vector2(module.grid_position)
		+ Vector2(size) * 0.5
	) * cell_size - local_origin_offset

func _on_module_runtime_damaged(
	module_instance: ShipModuleInstance,
	amount: float,
	current_hp: float
) -> void:
	module_damaged.emit(module_instance, amount, current_hp)

func _on_module_runtime_destroyed(module_instance: ShipModuleInstance) -> void:
	if module_instance == null or module_instance.definition == null:
		return

	if module_instance.definition is WeaponModuleDefinition:
		var weapon_runtime := weapon_runtime_by_uid.get(module_instance.uid, null) as WeaponRuntime
		if weapon_runtime != null and is_instance_valid(weapon_runtime):
			weapon_runtime.set_operational(false)

	_refresh_energy_state()
	module_destroyed.emit(module_instance)

	if module_instance.definition is CoreModuleDefinition:
		_remove_from_battle()
		return

	queue_redraw()

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

	energy_state_changed.emit(
		energy_output,
		energy_cost,
		energy_sufficient
	)

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
	weapon_fired.emit(
		module_instance,
		firepower,
		world_position,
		world_direction
	)
	_spawn_projectile(world_position, world_direction, firepower)

func _spawn_projectile(
	world_position: Vector2,
	world_direction: Vector2,
	firepower: float
) -> void:
	var projectile_parent := get_parent()
	if projectile_parent == null:
		return

	var projectile := PROJECTILE_RUNTIME_SCENE.instantiate() as ProjectileRuntime
	projectile_parent.add_child(projectile)
	projectile.setup(world_position, world_direction, firepower, self)
	projectile.hit.connect(_on_projectile_hit)
	projectile_spawned.emit(projectile)

func _on_projectile_hit(target: Node2D, firepower: float) -> void:
	projectile_hit.emit(target, firepower)

func _is_module_operational(module: ShipModuleInstance) -> bool:
	var module_runtime := get_module_runtime(module)
	return module_runtime != null and is_instance_valid(module_runtime) and not module_runtime.is_destroyed()

func _calculate_core_origin_offset() -> Vector2:
	core_origin_valid = false
	if ship_data == null:
		return Vector2.ZERO

	for module in ship_data.modules:
		if module.definition is CoreModuleDefinition:
			core_origin_valid = true
			var size := module.get_rotated_size()
			return (
				Vector2(module.grid_position)
				+ Vector2(size) * 0.5
			) * cell_size

	return Vector2.ZERO

func _get_module_color(module_type: ShipModuleDefinition.ModuleType) -> Color:
	match module_type:
		ShipModuleDefinition.ModuleType.ENERGY:
			return Color("#d9b84c")
		ShipModuleDefinition.ModuleType.PROPULSION:
			return Color("#5aa3d8")
		ShipModuleDefinition.ModuleType.WEAPON:
			return Color("#d65f5f")
		ShipModuleDefinition.ModuleType.DEFENSE:
			return Color("#65aa78")
		ShipModuleDefinition.ModuleType.FUNCTION:
			return Color("#9a79ca")
		ShipModuleDefinition.ModuleType.CORE:
			return Color("#d98c4a")
	return Color.GRAY
