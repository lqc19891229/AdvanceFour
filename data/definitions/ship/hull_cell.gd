class_name ShipHullCell
extends RefCounted

const DEFAULT_MAX_HP := 20.0
const DEFAULT_MASS := 2.0

var grid_position: Vector2i
var hull_type: StringName
var max_hp: float
var current_hp: float
var mass: float

func _init(
	p_grid_position: Vector2i,
	p_hull_type: StringName = &"basic_hull",
	p_max_hp: float = DEFAULT_MAX_HP,
	p_mass: float = DEFAULT_MASS,
	p_current_hp: float = -1.0
) -> void:
	grid_position = p_grid_position
	hull_type = p_hull_type
	max_hp = maxf(p_max_hp, 0.0)
	mass = maxf(p_mass, 0.0)
	current_hp = max_hp if p_current_hp < 0.0 else clampf(p_current_hp, 0.0, max_hp)

func get_health_ratio() -> float:
	if max_hp <= 0.0:
		return 0.0
	return clampf(current_hp / max_hp, 0.0, 1.0)

func is_destroyed() -> bool:
	return current_hp <= 0.0

func apply_damage(amount: float) -> float:
	var incoming := maxf(amount, 0.0)
	if incoming <= 0.0:
		return 0.0
	if is_destroyed():
		return incoming

	var hp_before := current_hp
	current_hp = maxf(current_hp - incoming, 0.0)
	return maxf(incoming - hp_before, 0.0)

func repair_full() -> void:
	current_hp = max_hp
