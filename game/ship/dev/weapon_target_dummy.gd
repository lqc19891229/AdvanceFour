class_name WeaponTargetDummy
extends Node2D

func _ready() -> void:
	add_to_group(&"enemy_targets")
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color.WHITE, false, 2.0)
	draw_line(Vector2(-8.0, 0.0), Vector2(8.0, 0.0), Color.WHITE, 1.0)
	draw_line(Vector2(0.0, -8.0), Vector2(0.0, 8.0), Color.WHITE, 1.0)
