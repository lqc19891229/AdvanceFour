class_name EnemyShipDefinition
extends Resource

@export var enemy_id: StringName
@export var display_name := ""
@export var texture: Texture2D
@export var collision_radius := 24.0
@export var max_hp := 80.0
@export var move_speed := 160.0
@export var acceleration := 240.0
@export var turn_speed_degrees := 135.0
@export var approach_distance := 280.0
@export var retreat_distance := 180.0
@export var weapon_damage := 6.0
@export var weapon_range := 500.0
@export var weapon_interval := 1.0
@export var projectile_speed := 700.0
@export var muzzle_positions: Array[Vector2] = [Vector2(0, -24)]

func is_valid() -> bool:
	return enemy_id != &"" and not display_name.strip_edges().is_empty() and collision_radius > 0.0 and max_hp > 0.0 and move_speed >= 0.0 and acceleration >= 0.0 and turn_speed_degrees >= 0.0 and weapon_damage > 0.0 and weapon_range > 0.0 and weapon_interval > 0.0 and projectile_speed > 0.0 and not muzzle_positions.is_empty()

func get_invalid_reason() -> String:
	return "" if is_valid() else "敌舰配置无效：需要有效 ID、名称、整体血量、碰撞半径、移动属性和武器参数。"
