class_name ShipGridView
extends Control

signal ship_changed
signal status_message(text: String)
signal selected_module_changed(module: ShipModuleInstance)

const CELL_SIZE := 48.0
const MIN_ZOOM := 0.5
const MAX_ZOOM := 2.5
const ZOOM_STEP := 1.15

@export var module_database: ModuleDatabase

var ship := ShipData.new()
var definitions: Dictionary = {}
var selected_definition: ShipModuleDefinition
var selected_module: ShipModuleInstance
var moving_selected := false
var placing_hull := false
var preview_cell := Vector2i.ZERO
var rotation_quarters := 0
var pan_offset := Vector2.ZERO
var zoom := 1.0
var is_panning := false
var run_inventory_enabled := false

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func set_run_inventory_enabled(enabled: bool) -> void:
	run_inventory_enabled = enabled
	queue_redraw()

func _get_run_module_count(module_id: StringName) -> int:
	var run_state := _run_state()
	if not run_inventory_enabled or run_state == null:
		return 0
	return int(run_state.call("get_module_inventory_count", module_id))

func _can_take_run_module(module_id: StringName) -> bool:
	var run_state := _run_state()
	return (
		not run_inventory_enabled
		or (
			run_state != null
			and bool(run_state.call("has_module_in_inventory", module_id, 1))
		)
	)

func _take_run_module(module_id: StringName) -> bool:
	if not run_inventory_enabled:
		return true
	var run_state := _run_state()
	return run_state != null and bool(run_state.call("take_module_from_inventory", module_id, 1))

func _return_run_module(module_id: StringName) -> void:
	if not run_inventory_enabled:
		return
	var run_state := _run_state()
	if run_state != null:
		run_state.call("add_module_to_inventory", module_id, 1)

func _can_take_run_hull() -> bool:
	if not run_inventory_enabled:
		return true
	var run_state := _run_state()
	return run_state != null and int(run_state.get("hull_stock")) > 0

func _take_run_hull() -> bool:
	if not run_inventory_enabled:
		return true
	var run_state := _run_state()
	return run_state != null and bool(run_state.call("take_hull_stock", 1))

func _return_run_hull() -> void:
	if not run_inventory_enabled:
		return
	var run_state := _run_state()
	if run_state != null:
		run_state.call("add_hull_stock", 1)

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
	_set_selected_module(null)
	moving_selected = false
	ship_changed.emit()
	queue_redraw()

func select_definition(id: String) -> void:
	if definitions.has(id):
		selected_definition = definitions[id]
		placing_hull = false
		_set_selected_module(null)
		moving_selected = false
		if run_inventory_enabled:
			status_message.emit("安装设备：%s｜库存 %d" % [
				selected_definition.display_name,
				_get_run_module_count(selected_definition.id)
			])
		else:
			status_message.emit("安装设备：%s" % selected_definition.display_name)
		queue_redraw()

func select_hull() -> void:
	placing_hull = true
	selected_definition = null
	_set_selected_module(null)
	moving_selected = false
	if run_inventory_enabled:
		var run_state := _run_state()
		var stock := 0 if run_state == null else int(run_state.get("hull_stock"))
		status_message.emit("放置基础船体格｜库存 %d" % stock)
	else:
		status_message.emit("放置基础船体格")
	queue_redraw()

func select_installed_module(module: ShipModuleInstance) -> void:
	if module == null or not ship.modules.has(module):
		_set_selected_module(null)
		return
	moving_selected = false
	_set_selected_module(module)
	status_message.emit("已选中：%s｜可移动或旋转" % module.definition.display_name)
	queue_redraw()

func begin_move_selected() -> void:
	if selected_module == null or not ship.modules.has(selected_module):
		status_message.emit("请先点击飞船上的模块")
		return
	moving_selected = true
	preview_cell = selected_module.grid_position
	status_message.emit("移动 %s：点击目标格，右键可取消" % selected_module.definition.display_name)
	queue_redraw()

func cancel_move_selected() -> void:
	if not moving_selected:
		return
	moving_selected = false
	status_message.emit("已取消移动")
	queue_redraw()

func move_selected_to(cell: Vector2i) -> bool:
	if selected_module == null or not ship.modules.has(selected_module):
		moving_selected = false
		status_message.emit("没有可移动的已选模块")
		return false
	var check := ship.can_relocate(selected_module, cell, selected_module.rotation_quarters)
	if not check["ok"]:
		status_message.emit(check["reason"])
		queue_redraw()
		return false
	var name := selected_module.definition.display_name
	if not ship.relocate(selected_module, cell, selected_module.rotation_quarters):
		return false
	moving_selected = false
	ship_changed.emit()
	selected_module_changed.emit(selected_module)
	status_message.emit("已移动：%s → (%d, %d)" % [name, cell.x, cell.y])
	queue_redraw()
	return true

func rotate_selection_or_preview() -> void:
	if selected_module == null or not ship.modules.has(selected_module):
		rotate_preview()
		return
	var next_rotation := posmod(selected_module.rotation_quarters + 1, 4)
	var check := ship.can_relocate(selected_module, selected_module.grid_position, next_rotation)
	if not check["ok"]:
		status_message.emit("无法旋转：%s" % check["reason"])
		return
	ship.relocate(selected_module, selected_module.grid_position, next_rotation)
	moving_selected = false
	ship_changed.emit()
	selected_module_changed.emit(selected_module)
	status_message.emit("已旋转：%s → %d°" % [
		selected_module.definition.display_name,
		selected_module.rotation_quarters * 90
	])
	queue_redraw()

func rotate_preview() -> void:
	rotation_quarters = posmod(rotation_quarters + 1, 4)
	status_message.emit("待放置模块旋转：%d°" % (rotation_quarters * 90))
	queue_redraw()

func clear_ship() -> void:
	if run_inventory_enabled:
		status_message.emit("Run 整备模式禁止一键清空，请逐个拆除以返还库存。")
		return
	ship.clear()
	_set_selected_module(null)
	moving_selected = false
	ship_changed.emit()
	status_message.emit("已清空飞船")
	queue_redraw()

func center_view() -> void:
	pan_offset = Vector2.ZERO
	zoom = 1.0
	queue_redraw()

func _set_selected_module(module: ShipModuleInstance) -> void:
	if selected_module == module:
		return
	selected_module = module
	selected_module_changed.emit(selected_module)

func get_cell_size() -> float:
	return CELL_SIZE * zoom

func zoom_at(mouse_position: Vector2, direction: int) -> void:
	var next_zoom := clampf(zoom * (ZOOM_STEP if direction > 0 else 1.0 / ZOOM_STEP), MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, zoom):
		return
	var origin := size * 0.5 + pan_offset
	pan_offset = mouse_position - size * 0.5 - (mouse_position - origin) * (next_zoom / zoom)
	zoom = next_zoom
	preview_cell = screen_to_grid(mouse_position)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if is_panning:
			pan_offset += event.relative
		preview_cell = screen_to_grid(event.position)
		queue_redraw()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_at(event.position, 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			accept_event()
			return
		if not event.pressed:
			return

		var cell := screen_to_grid(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if moving_selected:
				move_selected_to(cell)
				accept_event()
				return

			if placing_hull:
				var hull_check := ship.can_add_hull_cell(cell)
				if not _can_take_run_hull():
					status_message.emit("Hull 库存不足。")
				elif hull_check["ok"]:
					if _take_run_hull():
						ship.add_hull_cell(cell)
						ship_changed.emit()
						status_message.emit("已添加船体格：(%d, %d)" % [cell.x, cell.y])
				else:
					status_message.emit(hull_check["reason"])
				queue_redraw()
				accept_event()
				return

			var installed := ship.get_module_at(cell)
			if installed != null:
				select_installed_module(installed)
				accept_event()
				return

			if selected_definition == null:
				status_message.emit("请先选择要安装的设备。")
				queue_redraw()
				accept_event()
				return
			var check := ship.can_place(selected_definition, cell, rotation_quarters)
			if run_inventory_enabled and not _can_take_run_module(selected_definition.id):
				status_message.emit("库存不足：%s" % selected_definition.display_name)
			elif check["ok"]:
				if _take_run_module(selected_definition.id):
					var placed := ship.place(selected_definition, cell, rotation_quarters)
					if placed == null:
						_return_run_module(selected_definition.id)
					else:
						_set_selected_module(null)
						ship_changed.emit()
						status_message.emit("已放置：%s" % placed.definition.display_name)
			else:
				status_message.emit(check["reason"])
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if moving_selected:
				cancel_move_selected()
				accept_event()
				return
			var module := ship.get_module_at(cell)
			if module != null:
				var check := ship.can_remove(module)
				if check["ok"]:
					var name := module.definition.display_name
					var was_selected := module == selected_module
					ship.remove(module)
					_return_run_module(module.definition.id)
					if was_selected:
						_set_selected_module(null)
					ship_changed.emit()
					status_message.emit("已拆除设备：%s" % name)
				else:
					status_message.emit(check["reason"])
			else:
				var hull_check := ship.can_remove_hull_cell(cell)
				if hull_check["ok"]:
					ship.remove_hull_cell(cell)
					_return_run_hull()
					ship_changed.emit()
					status_message.emit("已拆除船体格：(%d, %d)" % [cell.x, cell.y])
				else:
					status_message.emit(hull_check["reason"])
			queue_redraw()
			accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_R:
		rotate_selection_or_preview()

func screen_to_grid(p: Vector2) -> Vector2i:
	var origin := size * 0.5 + pan_offset
	var local := p - origin
	return Vector2i(floor(local.x / get_cell_size()), floor(local.y / get_cell_size()))

func grid_to_screen(c: Vector2i) -> Vector2:
	return size * 0.5 + pan_offset + Vector2(c) * get_cell_size()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#11161e"))
	var origin := size * 0.5 + pan_offset
	var grid_color := Color(0.24, 0.29, 0.36, 0.7)
	var axis_color := Color(0.42, 0.49, 0.58, 0.9)
	# Draw enough grid lines to fill the viewport at any zoom and pan offset.
	# A fixed +/-30-cell extent leaves large blank areas when zoomed out.
	var cell_size := get_cell_size()
	var first_x := floori(-origin.x / cell_size)
	var last_x := ceili((size.x - origin.x) / cell_size)
	var first_y := floori(-origin.y / cell_size)
	var last_y := ceili((size.y - origin.y) / cell_size)
	for i in range(first_x, last_x + 1):
		var x := origin.x + float(i) * cell_size
		draw_line(Vector2(x, 0), Vector2(x, size.y), axis_color if i == 0 else grid_color, 2.0 if i == 0 else 1.0)
	for i in range(first_y, last_y + 1):
		var y := origin.y + float(i) * cell_size
		draw_line(Vector2(0, y), Vector2(size.x, y), axis_color if i == 0 else grid_color, 2.0 if i == 0 else 1.0)
	for hull_cell in ship.get_hull_cells():
		_draw_hull_cell(hull_cell)
	for module in ship.modules:
		_draw_module(module)
	for module in ship.modules:
		_draw_module_turret(module)
	if selected_module != null:
		var selected_rect := Rect2(grid_to_screen(selected_module.grid_position), Vector2(selected_module.get_rotated_size()) * get_cell_size())
		draw_rect(selected_rect.grow(-1), Color.WHITE, false, 3.0)
	_draw_preview()

func _draw_hull_cell(hull_cell: ShipHullCell) -> void:
	if hull_cell == null:
		return
	var rect := Rect2(grid_to_screen(hull_cell.grid_position), Vector2.ONE * get_cell_size())
	var health := hull_cell.get_health_ratio()
	var fill := Color(0.16, 0.20, 0.26, 1.0).lerp(
		Color(0.08, 0.08, 0.08, 1.0),
		1.0 - health
	)
	var edge := Color(0.56, 0.64, 0.72, 1.0).lerp(
		Color(0.55, 0.18, 0.16, 1.0),
		1.0 - health
	)
	draw_rect(rect.grow(-2.0), fill)
	draw_rect(rect.grow(-2.0), edge, false, 2.0)


func _draw_module(module: ShipModuleInstance) -> void:
	var rect := Rect2(
		grid_to_screen(module.grid_position),
		Vector2(module.get_rotated_size()) * get_cell_size()
	)

	var base_drawn := false
	if module.definition != null:
		var base_texture := ModuleArtLibrary.get_base_texture(module.definition)
		if base_texture != null:
			var base_rotation := 0.0
			if not (module.definition is WeaponModuleDefinition):
				base_rotation = float(module.rotation_quarters) * PI * 0.5
			_draw_module_texture(base_texture, rect, base_rotation)
			base_drawn = true

	if not base_drawn:
		_draw_module_fallback(module, rect)


func _draw_module_turret(module: ShipModuleInstance) -> void:
	if module.definition is WeaponModuleDefinition:
		var rect := Rect2(grid_to_screen(module.grid_position), Vector2(module.get_rotated_size()) * get_cell_size())
		var turret_rotation := float(module.rotation_quarters) * PI * 0.5
		var turret_texture := ModuleArtLibrary.get_turret_texture(module.definition)
		if turret_texture != null:
			_draw_turret(module.definition as WeaponModuleDefinition, rect.get_center(), turret_rotation)
		else:
			_draw_weapon_turret_fallback(rect, turret_rotation)

func _draw_turret(definition: WeaponModuleDefinition, center: Vector2, rotation_radians: float) -> void:
	draw_set_transform(center, rotation_radians, Vector2.ONE)
	draw_texture_rect(ModuleArtLibrary.get_turret_texture(definition), ModuleArtLibrary.get_turret_draw_rect(definition, get_cell_size() - 6.0), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_module_texture(
	texture: Texture2D,
	rect: Rect2,
	rotation_radians: float
) -> void:
	var target_rect := rect.grow(-3.0)
	draw_set_transform(target_rect.get_center(), rotation_radians, Vector2.ONE)
	draw_texture_rect(
		texture,
		Rect2(-target_rect.size * 0.5, target_rect.size),
		false
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_weapon_turret_fallback(rect: Rect2, rotation_radians: float) -> void:
	draw_set_transform(rect.get_center(), rotation_radians, Vector2.ONE)
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE, false, 1.0)
	draw_line(Vector2.ZERO, ModuleArtLibrary.WEAPON_FORWARD * 16.0, Color.WHITE, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_module_fallback(module: ShipModuleInstance, rect: Rect2) -> void:
	var color: Color = type_colors[module.definition.module_type]
	draw_rect(rect.grow(-3), color)
	draw_rect(rect.grow(-3), color.lightened(0.22), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		rect.position + Vector2(7, rect.size.y * 0.5 + 5),
		module.definition.display_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color("#101319")
	)

func get_preview_textures(definition: ShipModuleDefinition) -> Dictionary:
	if definition == null:
		return {"base": null, "turret": null}
	return {
		"base": ModuleArtLibrary.get_base_texture(definition),
		"turret": ModuleArtLibrary.get_turret_texture(definition)
	}


func _draw_module_preview(
	definition: ShipModuleDefinition,
	rect: Rect2,
	rotation_quarters_value: int,
	valid: bool
) -> void:
	if definition == null:
		return

	var preview_color := (
		Color(0.35, 0.85, 0.55, 0.28)
		if valid
		else Color(0.95, 0.25, 0.25, 0.28)
	)
	var border_color := (
		Color(0.35, 0.85, 0.55, 0.95)
		if valid
		else Color(0.95, 0.25, 0.25, 0.95)
	)
	var rotation_radians := float(rotation_quarters_value) * PI * 0.5
	var textures := get_preview_textures(definition)

	var base_texture: Texture2D = textures["base"]
	if base_texture != null:
		var base_rotation := rotation_radians
		if definition is WeaponModuleDefinition:
			base_rotation = 0.0
		_draw_module_texture(base_texture, rect, base_rotation)

	if definition is WeaponModuleDefinition:
		var turret_texture: Texture2D = textures["turret"]
		if turret_texture != null:
			_draw_turret(definition as WeaponModuleDefinition, rect.get_center(), rotation_radians)
		else:
			_draw_weapon_turret_fallback(rect, rotation_radians)

	draw_rect(rect.grow(-3.0), preview_color)
	draw_rect(rect.grow(-3.0), border_color, false, 2.0)


func _draw_preview() -> void:
	if placing_hull:
		var hull_check := ship.can_add_hull_cell(preview_cell)
		var hull_color := (
			Color(0.35, 0.85, 0.55, 0.34)
			if hull_check["ok"]
			else Color(0.95, 0.25, 0.25, 0.34)
		)
		var hull_rect := Rect2(grid_to_screen(preview_cell), Vector2.ONE * get_cell_size())
		draw_rect(hull_rect.grow(-3.0), hull_color)
		draw_rect(
			hull_rect.grow(-3.0),
			Color(hull_color.r, hull_color.g, hull_color.b, 0.95),
			false,
			2.0
		)
		return

	if moving_selected and selected_module != null:
		var temp := ShipModuleInstance.new(
			selected_module.uid,
			selected_module.definition,
			preview_cell,
			selected_module.rotation_quarters
		)
		var check := ship.can_relocate(
			selected_module,
			preview_cell,
			selected_module.rotation_quarters
		)
		var move_rect := Rect2(
			grid_to_screen(preview_cell),
			Vector2(temp.get_rotated_size()) * get_cell_size()
		)
		_draw_module_preview(
			selected_module.definition,
			move_rect,
			selected_module.rotation_quarters,
			check["ok"]
		)
		return

	if selected_module != null or selected_definition == null:
		return
	var temp := ShipModuleInstance.new(-1, selected_definition, preview_cell, rotation_quarters)
	var check := ship.can_place(selected_definition, preview_cell, rotation_quarters)
	var rect := Rect2(
		grid_to_screen(preview_cell),
		Vector2(temp.get_rotated_size()) * get_cell_size()
	)
	_draw_module_preview(
		selected_definition,
		rect,
		rotation_quarters,
		check["ok"]
	)
