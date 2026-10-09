class_name EnemyRuntime
extends Area2D

signal destroyed
signal projectile_spawned(projectile: ProjectileRuntime)

const PROJECTILE_SCENE := preload("res://game/ship/projectile/projectile_runtime.tscn")

var definition: EnemyShipDefinition
var current_hp := 0.0
var velocity := Vector2.ZERO
var throttle_input := 0.0
var turn_input := 0.0
var removed := false
var cooldown := 0.0
var weapon_runtimes: Array[Node2D] = []
var target: Node2D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true

func setup(data: EnemyShipDefinition) -> void:
	definition = data
	current_hp = data.max_hp
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = data.collision_radius
	shape_node.shape = circle
	add_child(shape_node)
	for muzzle in data.muzzle_positions:
		var mount := Node2D.new()
		mount.position = muzzle
		add_child(mount)
		weapon_runtimes.append(mount)
	queue_redraw()

func set_control_input(throttle: float, turn: float) -> void:
	throttle_input = clampf(throttle, -1.0, 1.0)
	turn_input = clampf(turn, -1.0, 1.0)

func _physics_process(delta: float) -> void:
	if removed or definition == null:
		return
	rotation += turn_input * deg_to_rad(definition.turn_speed_degrees) * delta
	velocity = velocity.move_toward(Vector2.UP.rotated(global_rotation) * throttle_input * definition.move_speed, definition.acceleration * delta)
	global_position += velocity * delta
	cooldown = maxf(cooldown - delta, 0.0)
	if is_instance_valid(target) and not target.is_queued_for_deletion() and global_position.distance_to(target.global_position) <= definition.weapon_range:
		request_fire()

func request_fire() -> void:
	if removed or definition == null or cooldown > 0.0:
		return
	for mount in weapon_runtimes:
		var direction := Vector2.UP.rotated(global_rotation)
		if is_instance_valid(target):
			direction = (target.global_position - mount.global_position).normalized()
		if direction.is_zero_approx():
			direction = Vector2.UP.rotated(global_rotation)
		var projectile := PROJECTILE_SCENE.instantiate() as ProjectileRuntime
		get_parent().add_child(projectile)
		projectile.setup(mount.global_position, direction, definition.weapon_damage, self, definition.weapon_range, definition.projectile_speed)
		projectile_spawned.emit(projectile)
	cooldown = definition.weapon_interval

func apply_projectile_damage(amount: float) -> float:
	if removed:
		return maxf(amount, 0.0)
	var applied := minf(maxf(amount, 0.0), current_hp)
	current_hp -= applied
	if current_hp <= 0.0:
		removed = true
		destroyed.emit()
		queue_free()
	# No penetration through the ship; the hull is one damage target.
	return 0.0

func get_hp() -> float:
	return current_hp

func is_removed_from_battle() -> bool:
	return removed

func get_aim_point(_from_world_position: Vector2) -> Vector2:
	return global_position

func _draw() -> void:
	if definition == null:
		return
	if definition.texture != null:
		draw_texture_rect(definition.texture, Rect2(Vector2.ONE * -definition.collision_radius, Vector2.ONE * definition.collision_radius * 2.0), false)
	else:
		var r := definition.collision_radius
		draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(-r * 0.8, r), Vector2(0, r * 0.5), Vector2(r * 0.8, r)]), Color(0.85, 0.25, 0.2))
