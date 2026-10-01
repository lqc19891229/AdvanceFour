class_name WeaponTargetDummy
extends Area2D

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

	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color.WHITE, false, 2.0)
	draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), Color.WHITE, 1.0)
	draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0), Color.WHITE, 1.0)
