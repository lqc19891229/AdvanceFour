class_name ShipGridView
extends Control

signal ship_changed
signal status_message(text: String)

const CELL_SIZE := 48.0
const GRID_HALF_EXTENT := 30

@export var module_database: ModuleDatabase

var ship := ShipData.new()
var definitions: Dictionary = {}
var selected_definition: ShipModuleDefinition
var preview_cell := Vector2i.ZERO
var rotation_quarters := 0
var pan_offset := Vector2.ZERO
var is_panning := false

var type_colors := {
	ShipModuleDefinition.ModuleType.ENERGY: Color("#d9b84c"),
	ShipModuleDefinition.ModuleType.PROPULSION: Color("#5aa3d8"),
	ShipModuleDefinition.ModuleType.WEAPON: Color("#d65f5f"),
	ShipModuleDefinition.ModuleType.DEFENSE: Color("#65aa78"),
	ShipModuleDefinition.ModuleType.FUNCTION: Color("#9a79ca"),
	ShipModuleDefinition.ModuleType.CORE: Color("#d98c4a")
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_load_module_database()
	queue_redraw()

func _load_module_database() -> void:
	definitions.clear()
	if module_database == null:
		push_error("ShipGridView 没有配置 ModuleDatabase")
		return

	for definition in module_database.modules:
		if definition == null:
			continue
		definitions[String(definition.id)] = definition

	if not module_database.modules.is_empty():
		selected_definition = module_database.modules[0]

func get_all_definitions() -> Array[ShipModuleDefinition]:
	if module_database == null:
		return []
	return module_database.modules

func set_ship(new_ship: ShipData) -> void:
	if new_ship == null:
		return
	ship = new_ship
	ship_changed.emit()
	queue_redraw()

func select_definition(id: String) -> void:
	if definitions.has(id):
		selected_definition = definitions[id]
		status_message.emit("已选择：%s" % selected_definition.display_name)
		queue_redraw()

func rotate_preview() -> void:
	rotation_quarters = posmod(rotation_quarters + 1, 4)
	status_message.emit("模块旋转：%d°" % (rotation_quarters * 90))
	queue_redraw()

func clear_ship() -> void:
	ship.clear()
	ship_changed.emit()
	status_message.emit("已清空飞船")
	queue_redraw()

func center_view() -> void:
	pan_offset = Vector2.ZERO
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if is_panning:
			pan_offset += event.relative
		preview_cell = screen_to_grid(event.position)
		queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			accept_event()
			return
		if not event.pressed:
			return
		var cell := screen_to_grid(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			var check := ship.can_place(selected_definition, cell, rotation_quarters)
			if check["ok"]:
				ship.place(selected_definition, cell, rotation_quarters)
				ship_changed.emit()
				status_message.emit("已放置：%s" % selected_definition.display_name)
			else:
				status_message.emit(check["reason"])
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var m := ship.get_module_at(cell)
			var check := ship.can_remove(m)
			if check["ok"]:
				var n := m.definition.display_name
				ship.remove(m)
				ship_changed.emit()
				status_message.emit("已删除：%s" % n)
			else:
				status_message.emit(check["reason"])
			queue_redraw()
			accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_R:
		rotate_preview()

func screen_to_grid(p: Vector2) -> Vector2i:
	var origin := size * 0.5 + pan_offset
	var local := p - origin
	return Vector2i(floor(local.x / CELL_SIZE), floor(local.y / CELL_SIZE))

func grid_to_screen(c: Vector2i) -> Vector2:
	return size * 0.5 + pan_offset + Vector2(c) * CELL_SIZE

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#11161e"))
	var origin := size * 0.5 + pan_offset
	var grid_color := Color(0.24, 0.29, 0.36, 0.7)
	var axis_color := Color(0.42, 0.49, 0.58, 0.9)
	for i in range(-GRID_HALF_EXTENT, GRID_HALF_EXTENT + 1):
		var x := origin.x + float(i) * CELL_SIZE
		var y := origin.y + float(i) * CELL_SIZE
		draw_line(Vector2(x, 0), Vector2(x, size.y), axis_color if i == 0 else grid_color, 2.0 if i == 0 else 1.0)
		draw_line(Vector2(0, y), Vector2(size.x, y), axis_color if i == 0 else grid_color, 2.0 if i == 0 else 1.0)
	for m in ship.modules:
		_draw_module(m)
	_draw_preview()

func _draw_module(m: ShipModuleInstance) -> void:
	var rect := Rect2(grid_to_screen(m.grid_position), Vector2(m.get_rotated_size()) * CELL_SIZE)
	var color: Color = type_colors[m.definition.module_type]
	draw_rect(rect.grow(-3), color)
	draw_rect(rect.grow(-3), color.lightened(0.22), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(7, rect.size.y * 0.5 + 5), m.definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#101319"))

func _draw_preview() -> void:
	if selected_definition == null:
		return
	var temp := ShipModuleInstance.new(-1, selected_definition, preview_cell, rotation_quarters)
	var check := ship.can_place(selected_definition, preview_cell, rotation_quarters)
	var color := Color(0.35, 0.85, 0.55, 0.36) if check["ok"] else Color(0.95, 0.25, 0.25, 0.36)
	var rect := Rect2(grid_to_screen(preview_cell), Vector2(temp.get_rotated_size()) * CELL_SIZE)
	draw_rect(rect.grow(-4), color)
	draw_rect(rect.grow(-4), Color(color.r, color.g, color.b, 0.9), false, 2.0)
