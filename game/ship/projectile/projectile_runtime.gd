class_name ProjectileRuntime
extends Area2D

signal hit(target: Node2D, firepower: float)

@export var speed := 700.0
@export var lifetime := 2.0

var direction := Vector2.UP
var firepower := 0.0
var lifetime_remaining := 0.0
var source_owner: Node2D
var has_hit := false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(
	world_position: Vector2,
	world_direction: Vector2,
	p_firepower: float,
	p_source_owner: Node2D
) -> void:
	global_position = world_position
	direction = world_direction.normalized()
	firepower = p_firepower
	source_owner = p_source_owner
	lifetime_remaining = maxf(lifetime, 0.0)
	rotation = Vector2.UP.angle_to(direction)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if has_hit:
		return
	if lifetime_remaining <= 0.0:
		queue_free()
		return

	global_position += direction * speed * delta
	lifetime_remaining -= delta

	if lifetime_remaining <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)

func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)

func _try_hit(candidate: Node2D) -> void:
	if has_hit or candidate == null or not is_instance_valid(candidate):
		return
	if _belongs_to_source(candidate):
		return

	has_hit = true

	if candidate.has_method("apply_damage"):
		candidate.apply_damage(firepower)

	hit.emit(candidate, firepower)
	queue_free()

func _belongs_to_source(candidate: Node) -> bool:
	if source_owner == null or not is_instance_valid(source_owner):
		return false
	return (
		candidate == source_owner
		or source_owner.is_ancestor_of(candidate)
		or candidate.is_ancestor_of(source_owner)
	)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
	draw_line(Vector2.ZERO, Vector2.DOWN * 10.0, Color.WHITE, 2.0)
