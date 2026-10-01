class_name ShipRuntime
extends Node2D

signal weapon_fired(
	module_instance: ShipModuleInstance,
	firepower: float,
	world_position: Vector2,
	world_direction: Vector2
)

const WEAPON_RUNTIME_SCENE := preload("res://game/ship/weapon/weapon_runtime.tscn")

@export var cell_size := 36.0
@export var acceleration_scale := 180.0
@export var drag := 2.5
@export var turn_speed_degrees := 120.0
@export var reverse_thrust_ratio := 0.5
@export var weapon_target_group: StringName = &"enemy_targets"

var ship_data: ShipData
var velocity := Vector2.ZERO
var throttle_input := 0.0
var turn_input := 0.0
var local_origin_offset := Vector2.ZERO
var core_origin_valid := false
var weapon_runtimes: Array[WeaponRuntime] = []

func setup(data: ShipData) -> void:
	_clear_weapon_runtimes()
	ship_data = data
	velocity = Vector2.ZERO
	throttle_input = 0.0
	turn_input = 0.0
	rotation = 0.0
	local_origin_offset = _calculate_core_origin_offset()
	_build_weapon_runtimes()
	queue_redraw()

func set_control_input(throttle: float, turn: float) -> void:
	throttle_input = clampf(throttle, -1.0, 1.0)
	turn_input = clampf(turn, -1.0, 1.0)

func request_fire() -> void:
	for weapon_runtime in weapon_runtimes:
		if is_instance_valid(weapon_runtime):
			weapon_runtime.fire_once()

func get_weapon_count() -> int:
	return weapon_runtimes.size()

func get_speed() -> float:
	return velocity.length()

func get_heading_degrees() -> float:
	return wrapf(rad_to_deg(rotation), 0.0, 360.0)

func get_local_origin_offset() -> Vector2:
	return local_origin_offset

func has_core_origin() -> bool:
	return core_origin_valid

func _physics_process(delta: float) -> void:
	if ship_data == null:
		return

	if not is_zero_approx(turn_input):
		rotation += deg_to_rad(turn_speed_degrees) * turn_input * delta

	if not is_zero_approx(throttle_input):
		var thrust_ratio := 1.0 if throttle_input > 0.0 else reverse_thrust_ratio
		var acceleration := ship_data.get_acceleration_score() * acceleration_scale * thrust_ratio
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
		draw_rect(rect.grow(-2.0), _get_module_color(module.definition.module_type))
		draw_rect(rect.grow(-2.0), Color.WHITE, false, 1.0)

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

func _clear_weapon_runtimes() -> void:
	for weapon_runtime in weapon_runtimes:
		if is_instance_valid(weapon_runtime):
			weapon_runtime.queue_free()
	weapon_runtimes.clear()

func _get_module_local_center(module: ShipModuleInstance) -> Vector2:
	var size := module.get_rotated_size()
	return (
		Vector2(module.grid_position)
		+ Vector2(size) * 0.5
	) * cell_size - local_origin_offset

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
