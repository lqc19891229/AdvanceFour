class_name WeaponTargetDummy
extends Area2D

signal damaged(amount: float, current_hp: float)
signal destroyed

@export var max_hp := 20.0

var damage_receiver: DamageReceiver

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group(&"enemy_targets")

	var collision_shape := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	collision_shape.shape = shape
	add_child(collision_shape)

	damage_receiver = DamageReceiver.new()
	add_child(damage_receiver)
	damage_receiver.setup(max_hp)
	damage_receiver.damaged.connect(_on_damage_receiver_damaged)
	damage_receiver.destroyed.connect(_on_damage_receiver_destroyed)

	queue_redraw()

func apply_damage(amount: float) -> void:
	if damage_receiver != null:
		damage_receiver.apply_damage(amount)

func get_hp() -> float:
	return 0.0 if damage_receiver == null else damage_receiver.get_hp()

func is_destroyed() -> bool:
	return damage_receiver != null and damage_receiver.is_destroyed()

func _on_damage_receiver_damaged(amount: float, current_hp: float) -> void:
	damaged.emit(amount, current_hp)

func _on_damage_receiver_destroyed() -> void:
	destroyed.emit()
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color.WHITE, false, 2.0)
	draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), Color.WHITE, 1.0)
	draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0), Color.WHITE, 1.0)
