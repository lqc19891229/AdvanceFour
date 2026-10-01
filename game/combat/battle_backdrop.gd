extends Node2D

# World-space landmarks stay still as the camera follows the moving ship.
const GRID_SPACING := 72.0
const STAR_SPACING := 96.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var screen := get_viewport_rect()
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var bounds := Rect2(to_local * screen.position, Vector2.ZERO)
	for corner in [Vector2(screen.end.x, screen.position.y), screen.end, Vector2(screen.position.x, screen.end.y)]:
		bounds = bounds.expand(to_local * corner)
	bounds = bounds.grow(STAR_SPACING)
	for x in range(int(floor(bounds.position.x / GRID_SPACING)), int(ceil(bounds.end.x / GRID_SPACING)) + 1):
		var color := Color(0.20, 0.33, 0.43, 0.30 if x % 5 == 0 else 0.13)
		draw_line(Vector2(x * GRID_SPACING, bounds.position.y), Vector2(x * GRID_SPACING, bounds.end.y), color)
	for y in range(int(floor(bounds.position.y / GRID_SPACING)), int(ceil(bounds.end.y / GRID_SPACING)) + 1):
		var color := Color(0.20, 0.33, 0.43, 0.30 if y % 5 == 0 else 0.13)
		draw_line(Vector2(bounds.position.x, y * GRID_SPACING), Vector2(bounds.end.x, y * GRID_SPACING), color)
	for x in range(int(floor(bounds.position.x / STAR_SPACING)), int(ceil(bounds.end.x / STAR_SPACING)) + 1):
		for y in range(int(floor(bounds.position.y / STAR_SPACING)), int(ceil(bounds.end.y / STAR_SPACING)) + 1):
			# Seed each cell independently: revisiting a location preserves its stars.
			var random := RandomNumberGenerator.new()
			random.seed = hash(Vector2i(x, y))
			var point := Vector2(x, y) * STAR_SPACING + Vector2(random.randf_range(10.0, 86.0), random.randf_range(10.0, 86.0))
			var brightness := random.randf_range(0.35, 0.75)
			draw_circle(point, random.randf_range(0.8, 1.6), Color(0.62, 0.76, 0.88, brightness))
