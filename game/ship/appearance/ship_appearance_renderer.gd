class_name ShipAppearanceRenderer
extends Node2D

const SHELL_FILL := Color("#3f4a58")
const SHELL_INNER := Color("#596777")
const SHELL_EDGE := Color("#93a5b7")
const SHELL_DAMAGE := Color("#2a1717")
const SHELL_DAMAGE_EDGE := Color("#8f3d35")
const INTERNAL_SEAM := Color(0.12, 0.15, 0.18, 0.40)

var ship_data: ShipData
var cell_size := 36.0
var local_origin_offset := Vector2.ZERO

func setup(data: ShipData, p_cell_size: float, origin_offset: Vector2) -> void:
	ship_data = data
	cell_size = p_cell_size
	local_origin_offset = origin_offset
	z_index = 0
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func get_neighbor_mask(cell: Vector2i) -> int:
	if ship_data == null:
		return 0
	var mask := 0
	if ship_data.has_hull_cell(cell + Vector2i.UP):
		mask |= 1
	if ship_data.has_hull_cell(cell + Vector2i.RIGHT):
		mask |= 2
	if ship_data.has_hull_cell(cell + Vector2i.DOWN):
		mask |= 4
	if ship_data.has_hull_cell(cell + Vector2i.LEFT):
		mask |= 8
	return mask

func is_exterior_cell(cell: Vector2i) -> bool:
	return get_neighbor_mask(cell) != 15

func _draw() -> void:
	if ship_data == null:
		return
	for hull_cell in ship_data.get_hull_cells():
		_draw_hull_cell(hull_cell)

func _draw_hull_cell(hull_cell: ShipHullCell) -> void:
	if hull_cell == null:
		return

	var rect := Rect2(
		Vector2(hull_cell.grid_position) * cell_size - local_origin_offset,
		Vector2.ONE * cell_size
	)
	var health := hull_cell.get_health_ratio()
	var fill := SHELL_FILL.lerp(SHELL_DAMAGE, 1.0 - health)
	var inner := SHELL_INNER.lerp(SHELL_DAMAGE, 1.0 - health)
	var edge := SHELL_EDGE.lerp(SHELL_DAMAGE_EDGE, 1.0 - health)

	# Adjacent cells touch edge-to-edge so the layer reads as one hull instead of tiles.
	draw_rect(rect.grow(0.35), fill)
	draw_rect(rect.grow(-3.0), inner)

	var mask := get_neighbor_mask(hull_cell.grid_position)
	var top := (mask & 1) != 0
	var right := (mask & 2) != 0
	var bottom := (mask & 4) != 0
	var left := (mask & 8) != 0

	# Interior seams stay subtle; only exposed sides receive the strong outer shell.
	if top:
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), INTERNAL_SEAM, 1.0)
	else:
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0.0), edge, 3.0)
	if right:
		draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.end, INTERNAL_SEAM, 1.0)
	else:
		draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.end, edge, 3.0)
	if bottom:
		draw_line(rect.end, rect.position + Vector2(0.0, rect.size.y), INTERNAL_SEAM, 1.0)
	else:
		draw_line(rect.end, rect.position + Vector2(0.0, rect.size.y), edge, 3.0)
	if left:
		draw_line(rect.position + Vector2(0.0, rect.size.y), rect.position, INTERNAL_SEAM, 1.0)
	else:
		draw_line(rect.position + Vector2(0.0, rect.size.y), rect.position, edge, 3.0)

	# Small corner caps soften the grid silhouette without changing the logical Hull shape.
	var cap := 3.0
	if not top and not left:
		draw_circle(rect.position + Vector2(cap, cap), cap, edge)
	if not top and not right:
		draw_circle(rect.position + Vector2(rect.size.x - cap, cap), cap, edge)
	if not bottom and not right:
		draw_circle(rect.end - Vector2(cap, cap), cap, edge)
	if not bottom and not left:
		draw_circle(rect.position + Vector2(cap, rect.size.y - cap), cap, edge)
