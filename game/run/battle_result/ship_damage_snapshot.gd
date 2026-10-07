class_name ShipDamageSnapshot
extends Control

signal cell_selected(position: Vector2i)

const INTACT_COLOR := Color("#70869b")
const LIGHT_DAMAGE_COLOR := Color("#e4bd53")
const HEAVY_DAMAGE_COLOR := Color("#f16b57")
const DESTROYED_COLOR := Color("#8e3544")
const HULL_APPEARANCE := preload("res://data/appearances/hull/human_basic.tres")

var ship: ShipData
var has_selection := false
var selected_position := Vector2i.ZERO
var zoom := 1.0
var pan := Vector2.ZERO
var is_panning := false
var bounds := Rect2()

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	mouse_exited.connect(func() -> void: is_panning = false)

func set_ship(value: ShipData) -> void:
	if ship != value:
		center_view()
	ship = value
	bounds = Rect2()
	if ship != null:
		var cells := ship.get_hull_cells()
		if not cells.is_empty():
			bounds = Rect2(Vector2(cells[0].grid_position), Vector2.ONE)
			for cell in cells:
				bounds = bounds.merge(Rect2(Vector2(cell.grid_position), Vector2.ONE))
	queue_redraw()

func center_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	queue_redraw()

func set_selected_cell(position: Vector2i, selected: bool) -> void:
	selected_position = position
	has_selection = selected
	queue_redraw()

func get_cell_size() -> float:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 48.0
	var available := (size - Vector2.ONE * 40.0).max(Vector2.ONE)
	return maxf(minf(48.0, minf(available.x / bounds.size.x, available.y / bounds.size.y)) * zoom, 0.01)

func grid_to_screen(position: Vector2i) -> Vector2:
	return size * 0.5 + pan + (Vector2(position) - bounds.get_center()) * get_cell_size()

func screen_to_grid(position: Vector2) -> Vector2i:
	var local := (position - size * 0.5 - pan) / get_cell_size() + bounds.get_center()
	return Vector2i(floori(local.x), floori(local.y))

func get_damage_color(cell: ShipHullCell) -> Color:
	if cell.current_hp <= 0.0:
		return DESTROYED_COLOR
	if cell.get_health_ratio() < 0.5:
		return HEAVY_DAMAGE_COLOR
	if cell.current_hp < cell.max_hp:
		return LIGHT_DAMAGE_COLOR
	return INTACT_COLOR

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if is_panning:
			pan += event.relative
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.5, 8.0)
			queue_redraw()
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				center_view()
			elif ship != null:
				var position := screen_to_grid(event.position)
				if ship.has_hull_cell(position):
					set_selected_cell(position, true)
					cell_selected.emit(position)
			accept_event()

func _get_tooltip(at_position: Vector2) -> String:
	if ship == null:
		return ""
	var position := screen_to_grid(at_position)
	var cell := ship.get_hull_cell_at(position)
	if cell == null:
		return ""
	var module := ship.get_module_at(position)
	return "船体 (%d,%d)｜%.0f / %.0f HP\n%s" % [position.x, position.y, cell.current_hp, cell.max_hp, "无设备" if module == null else module.definition.display_name]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101923"))
	if ship == null:
		return
	var cell_size := get_cell_size()
	for cell in ship.get_hull_cells():
		var rect := Rect2(grid_to_screen(cell.grid_position), Vector2.ONE * cell_size)
		var mask := 0
		var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
		for index in range(directions.size()):
			if ship.has_hull_cell(cell.grid_position + directions[index]):
				mask |= 1 << index
		var texture := HULL_APPEARANCE.get_tile(mask)
		if texture != null:
			draw_texture_rect(texture, rect, false)
		else:
			draw_rect(rect, Color("#263747"))
	for module in ship.modules:
		_draw_module(module)
	# Damage overlays sit above the module art, so every covered Hull stays readable.
	for cell in ship.get_hull_cells():
		var rect := Rect2(grid_to_screen(cell.grid_position), Vector2.ONE * cell_size).grow(-cell_size * 0.04)
		var color := get_damage_color(cell)
		if cell.current_hp < cell.max_hp:
			draw_rect(rect, Color(color, 0.62 if cell.is_destroyed() else 0.26))
			draw_rect(rect, color, false, maxf(1.0, cell_size * 0.045))
			if cell.is_destroyed():
				draw_line(rect.position, rect.end, color.lightened(0.25), 1.5)
				draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), color.lightened(0.25), 1.5)
		else:
			draw_rect(rect, Color(color, 0.45), false, 1.0)
	if has_selection and ship.has_hull_cell(selected_position):
		var rect := Rect2(grid_to_screen(selected_position), Vector2.ONE * cell_size)
		draw_rect(rect.grow(-1.0), Color.WHITE, false, 3.0)

func _draw_module(module: ShipModuleInstance) -> void:
	if module.definition == null:
		return
	var rect := Rect2(grid_to_screen(module.grid_position), Vector2(module.get_rotated_size()) * get_cell_size())
	var rotation := float(module.rotation_quarters) * PI * 0.5
	var base := ModuleArtLibrary.get_base_texture(module.definition)
	if base != null:
		_draw_texture(base, rect, 0.0 if module.definition is WeaponModuleDefinition else rotation)
	else:
		draw_rect(rect.grow(-2.0), Color("#506a7b"))
	if module.definition is WeaponModuleDefinition:
		var turret := ModuleArtLibrary.get_turret_texture(module.definition)
		if turret != null:
			_draw_texture(turret, rect, rotation)
		else:
			draw_line(rect.get_center(), rect.get_center() + ModuleArtLibrary.WEAPON_FORWARD.rotated(rotation) * get_cell_size() * 0.35, Color.WHITE, 2.0)

func _draw_texture(texture: Texture2D, rect: Rect2, rotation: float) -> void:
	var texture_size := rect.size * 0.94
	# Swap local dimensions before quarter-turn rotation to preserve rectangular art.
	if absi(roundi(rotation / (PI * 0.5))) % 2 == 1:
		texture_size = Vector2(texture_size.y, texture_size.x)
	draw_set_transform(rect.get_center(), rotation, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-texture_size * 0.5, texture_size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
