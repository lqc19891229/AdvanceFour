class_name ProjectileRuntime
extends Node2D

@export var speed := 700.0
@export var lifetime := 2.0

var direction := Vector2.UP
var firepower := 0.0
var lifetime_remaining := 0.0

func setup(
	world_position: Vector2,
	world_direction: Vector2,
	p_firepower: float
) -> void:
	global_position = world_position
	direction = world_direction.normalized()
	firepower = p_firepower
	lifetime_remaining = maxf(lifetime, 0.0)
	rotation = Vector2.UP.angle_to(direction)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if lifetime_remaining <= 0.0:
		queue_free()
		return

	global_position += direction * speed * delta
	lifetime_remaining -= delta

	if lifetime_remaining <= 0.0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
	draw_line(Vector2.ZERO, Vector2.DOWN * 10.0, Color.WHITE, 2.0)
