class_name ShipModuleRuntime
extends Area2D

signal damaged(
	module_instance: ShipModuleInstance,
	amount: float,
	current_hp: float
)
signal destroyed(module_instance: ShipModuleInstance)

var module_instance: ShipModuleInstance
var damage_receiver: DamageReceiver
var collision_shape: CollisionShape2D

func setup(
	module: ShipModuleInstance,
	local_position: Vector2,
	pixel_size: Vector2,
	max_hp: float
) -> void:
	module_instance = module
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

	damage_receiver = DamageReceiver.new()
	add_child(damage_receiver)
	damage_receiver.setup(max_hp)
	damage_receiver.damaged.connect(_on_damage_receiver_damaged)
	damage_receiver.destroyed.connect(_on_damage_receiver_destroyed)

func apply_damage(amount: float) -> void:
	if damage_receiver != null:
		damage_receiver.apply_damage(amount)

func get_hp() -> float:
	return 0.0 if damage_receiver == null else damage_receiver.get_hp()

func get_max_hp() -> float:
	return 0.0 if damage_receiver == null else damage_receiver.max_hp

func is_destroyed() -> bool:
	return damage_receiver != null and damage_receiver.is_destroyed()

func _on_damage_receiver_damaged(amount: float, current_hp: float) -> void:
	damaged.emit(module_instance, amount, current_hp)

func _on_damage_receiver_destroyed() -> void:
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	destroyed.emit(module_instance)
