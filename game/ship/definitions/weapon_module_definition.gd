class_name WeaponModuleDefinition
extends ShipModuleDefinition

@export_group("类型专属参数")
@export var firepower: float = 0.0
@export var attack_range: float = 0.0 # px; also the projectile's maximum travel distance.
@export var fire_interval: float = 0.0 # Seconds between shots.
@export var turn_speed_degrees: float = 0.0 # Degrees per second.
@export var fire_angle_tolerance_degrees: float = 0.0 # Degrees from the aimed direction.
@export var projectile_speed: float = 0.0 # px/s.

func _init() -> void:
	module_type = ModuleType.WEAPON
