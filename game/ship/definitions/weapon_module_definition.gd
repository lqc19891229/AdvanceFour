class_name WeaponModuleDefinition
extends ShipModuleDefinition

@export_group("类型专属参数")
@export var firepower: float = 0.0
@export var attack_range: float = 500.0
@export var fire_interval: float = 0.5
@export var turn_speed_degrees: float = 180.0
@export var projectile_speed: float = 700.0
@export var fire_angle_tolerance_degrees: float = 6.0

func _init() -> void:
	module_type = ModuleType.WEAPON
