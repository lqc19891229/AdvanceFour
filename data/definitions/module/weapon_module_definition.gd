class_name WeaponModuleDefinition
extends ShipModuleDefinition

@export_group("类型专属参数")
@export var firepower: float = 0.0
@export var attack_range: float = 500.0
@export var fire_interval: float = 0.5
@export var turn_speed_degrees: float = 180.0
@export var projectile_speed: float = 700.0
@export_range(0.0, 360.0, 1.0) var firing_arc_degrees: float = 360.0
@export var fire_angle_tolerance_degrees: float = 6.0

@export_group("武器美术")
@export var turret_texture: Texture2D
@export var turret_size_cells := Vector2.ONE
# Coordinates in the upright canvas: left-bottom (0,0), right-top (1,1).
@export var turret_pivot := Vector2(0.5, 0.5)
@export var turret_muzzle := Vector2(0.5, 1.0)
# Compatibility for older source art. New textures point up and use zero.
@export var turret_art_rotation_degrees := 0.0

func get_display_texture() -> Texture2D:
	if icon_texture != null:
		return icon_texture
	return turret_texture if turret_texture != null else texture

func _init() -> void:
	module_type = ModuleType.WEAPON
