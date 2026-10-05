class_name HullCellRuntime
extends Area2D

signal damaged(hull_cell: ShipHullCell, amount: float, current_hp: float)
signal destroyed(hull_cell: ShipHullCell)

var hull_cell: ShipHullCell
var owner_ship: ShipRuntime
var collision_shape: CollisionShape2D

func setup(
	cell: ShipHullCell,
	ship: ShipRuntime,
	local_position: Vector2,
	pixel_size: Vector2
) -> void:
	hull_cell = cell
	owner_ship = ship
	position = local_position

	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true

	collision_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = pixel_size
	collision_shape.shape = shape
	add_child(collision_shape)

	if hull_cell != null and hull_cell.is_destroyed():
		collision_shape.set_deferred("disabled", true)

func apply_projectile_damage(amount: float) -> float:
	if owner_ship == null or not is_instance_valid(owner_ship) or hull_cell == null:
		return maxf(amount, 0.0)
	return owner_ship.apply_hull_projectile_damage(hull_cell, amount)

func get_hp() -> float:
	if hull_cell == null:
		return 0.0
	if owner_ship == null or not is_instance_valid(owner_ship) or owner_ship.ship_data == null:
		return hull_cell.current_hp
	return owner_ship.ship_data.get_hull_cell_effective_hp(hull_cell)

func get_max_hp() -> float:
	if hull_cell == null:
		return 0.0
	if owner_ship == null or not is_instance_valid(owner_ship) or owner_ship.ship_data == null:
		return hull_cell.max_hp
	return owner_ship.ship_data.get_hull_cell_effective_max_hp(hull_cell)

func is_destroyed() -> bool:
	return hull_cell == null or hull_cell.is_destroyed()

func notify_damage(amount: float) -> void:
	if hull_cell == null:
		return
	damaged.emit(hull_cell, amount, get_hp())
	if hull_cell.is_destroyed():
		if collision_shape != null:
			collision_shape.set_deferred("disabled", true)
		destroyed.emit(hull_cell)
