class_name ProjectileRuntime
extends Area2D

signal hit(target: Node2D, firepower: float)

var speed := 0.0
@export var max_impacts_per_step := 16

var direction := Vector2.UP
var launch_position := Vector2.ZERO
var firepower := 0.0
var remaining_damage := 0.0
var max_distance := 0.0
var distance_remaining := 0.0
var source_owner: Node2D
var finished := false

func _ready() -> void:
	monitoring = false

func setup(
	world_position: Vector2,
	world_direction: Vector2,
	p_firepower: float,
	p_source_owner: Node2D,
	p_max_distance: float,
	p_speed: float
) -> void:
	global_position = world_position
	launch_position = world_position
	direction = world_direction.normalized()
	firepower = maxf(p_firepower, 0.0)
	remaining_damage = firepower
	source_owner = p_source_owner
	max_distance = maxf(p_max_distance, 0.0)
	distance_remaining = max_distance
	speed = maxf(p_speed, 0.0)
	finished = false
	rotation = Vector2.UP.angle_to(direction)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if finished:
		return
	if distance_remaining <= 0.0 or remaining_damage <= 0.0 or speed <= 0.0:
		_finish()
		return

	# Clip the ray before querying collisions, including overkill hits in this step.
	var travel_distance := minf(speed * maxf(delta, 0.0), distance_remaining)
	if travel_distance > 0.0:
		var consumed := _sweep_move(travel_distance)
		distance_remaining = maxf(distance_remaining - consumed, 0.0)

	if not finished and distance_remaining <= 0.0:
		_finish()

func _sweep_move(travel_distance: float) -> float:
	var start := global_position
	# Reconstruct from the launch point to avoid accumulating world-coordinate rounding.
	var end := launch_position + direction * (max_distance - distance_remaining + travel_distance)
	var cursor := start
	var excluded_rids: Array[RID] = [get_rid()]
	_append_source_exclusions(excluded_rids)
	var impacts := 0

	while not finished and remaining_damage > 0.0 and impacts < max_impacts_per_step:
		var query := PhysicsRayQueryParameters2D.create(
			cursor,
			end,
			collision_mask,
			excluded_rids
		)
		query.collide_with_areas = true
		query.collide_with_bodies = true

		var result := get_world_2d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			global_position = end
			return travel_distance

		var candidate := result.get("collider") as Node2D
		var hit_position: Vector2 = result.get("position", cursor)
		global_position = hit_position

		if candidate == null or not is_instance_valid(candidate):
			global_position = end
			return travel_distance

		if candidate is CollisionObject2D:
			excluded_rids.append((candidate as CollisionObject2D).get_rid())

		if _belongs_to_source(candidate):
			cursor = hit_position
			continue

		var incoming_damage := remaining_damage
		var leftover := 0.0

		if candidate.has_method("apply_projectile_damage"):
			leftover = maxf(
				float(candidate.call("apply_projectile_damage", incoming_damage)),
				0.0
			)
		elif candidate.has_method("apply_damage"):
			candidate.apply_damage(incoming_damage)

		hit.emit(candidate, incoming_damage)
		impacts += 1

		if _is_target_ship_removed(candidate):
			_finish()
			return minf(start.distance_to(global_position), travel_distance)

		if leftover <= 0.0:
			_finish()
			return minf(start.distance_to(global_position), travel_distance)

		remaining_damage = leftover
		# The collider RID is already excluded; no nudge beyond the ray boundary is needed.
		cursor = hit_position
		if cursor.distance_squared_to(end) <= 0.0001:
			global_position = end
			return travel_distance

	global_position = cursor
	return minf(start.distance_to(global_position), travel_distance)

func _finish() -> void:
	if finished:
		return
	finished = true
	queue_free()

func _append_source_exclusions(excluded_rids: Array[RID]) -> void:
	if source_owner == null or not is_instance_valid(source_owner):
		return

	var stack: Array[Node] = []
	stack.append(source_owner)

	while not stack.is_empty():
		var node := stack.pop_back() as Node
		if node is CollisionObject2D:
			excluded_rids.append((node as CollisionObject2D).get_rid())
		for child in node.get_children():
			stack.append(child)

func _belongs_to_source(candidate: Node) -> bool:
	if source_owner == null or not is_instance_valid(source_owner):
		return false
	return (
		candidate == source_owner
		or source_owner.is_ancestor_of(candidate)
		or candidate.is_ancestor_of(source_owner)
	)

func _is_target_ship_removed(candidate: Node) -> bool:
	var node: Node = candidate
	while node != null:
		if node is ShipRuntime:
			return (node as ShipRuntime).is_removed_from_battle()
		node = node.get_parent()
	return false

func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
	draw_line(Vector2.ZERO, Vector2.DOWN * 10.0, Color.WHITE, 2.0)
