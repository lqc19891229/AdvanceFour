class_name WeaponRuntime
extends Node2D

signal fired(
	weapon_runtime: WeaponRuntime,
	module_instance: ShipModuleInstance,
	firepower: float,
	world_position: Vector2,
	world_direction: Vector2
)

var owner_ship: ShipRuntime
var module_instance: ShipModuleInstance
var weapon_definition: WeaponModuleDefinition

func setup(ship: ShipRuntime, module: ShipModuleInstance, local_position: Vector2) -> void:
	owner_ship = ship
	module_instance = module
	weapon_definition = module.definition as WeaponModuleDefinition
	position = local_position
	rotation = deg_to_rad(float(module.rotation_quarters) * 90.0)

func fire_once() -> void:
	if owner_ship == null or not is_instance_valid(owner_ship):
		return
	if module_instance == null or weapon_definition == null:
		return

	var direction := Vector2.UP.rotated(global_rotation).normalized()
	fired.emit(
		self,
		module_instance,
		weapon_definition.firepower,
		global_position,
		direction
	)
