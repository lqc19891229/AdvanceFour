class_name ShipModuleInstance
extends RefCounted

var uid: int
var definition: ShipModuleDefinition
var grid_position: Vector2i
var rotation_quarters: int
var hp: float

func _init(p_uid: int, p_definition: ShipModuleDefinition, p_grid_position: Vector2i, p_rotation_quarters: int = 0) -> void:
	uid = p_uid
	definition = p_definition
	grid_position = p_grid_position
	rotation_quarters = posmod(p_rotation_quarters, 4)
	hp = definition.max_hp

func get_rotated_size() -> Vector2i:
	if rotation_quarters % 2 == 1:
		return Vector2i(definition.size.y, definition.size.x)
	return definition.size

func get_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var s := get_rotated_size()
	for y in range(s.y):
		for x in range(s.x):
			result.append(grid_position + Vector2i(x, y))
	return result
