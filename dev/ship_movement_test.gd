extends Node2D

const SAVE_PATH := "user://ships/test_ship.json"
const CELL_SIZE := 36.0
const TEST_ACCELERATION_SCALE := 180.0
const DRAG := 2.5

@export var module_database: ModuleDatabase

var ship: ShipData
var velocity := Vector2.ZERO

func _ready() -> void:
	var result := ShipSerializer.load_from_file(SAVE_PATH, module_database)
	if result["ok"]:
		ship = result["ship"]
		$CanvasLayer/Info.text = _build_info_text()
		queue_redraw()
	else:
		$CanvasLayer/Info.text = "加载失败：%s\n请先在飞船编辑器中保存设计。" % result["error"]
		set_process(false)

func _process(delta: float) -> void:
	if ship == null:
		return

	var input_direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_direction.y += 1.0

	if input_direction.length_squared() > 0.0:
		input_direction = input_direction.normalized()
		var acceleration := ship.get_acceleration_score() * TEST_ACCELERATION_SCALE
		velocity += input_direction * acceleration * delta

	velocity = velocity.move_toward(Vector2.ZERO, velocity.length() * DRAG * delta)
	position += velocity * delta
	$CanvasLayer/Info.text = _build_info_text()

func _build_info_text() -> String:
	return """飞船移动测试
WASD / 方向键：移动

模块：%d
质量：%.1f
推力：%.1f
推重比：%.3f
速度：%.1f

规则：模块可分开放置，不要求相邻、连通或填满格子。""" % [
		ship.modules.size(),
		ship.get_mass(),
		ship.get_thrust(),
		ship.get_acceleration_score(),
		velocity.length()
	]

func _draw() -> void:
	if ship == null:
		return

	for module in ship.modules:
		var size := module.get_rotated_size()
		var rect := Rect2(
			Vector2(module.grid_position) * CELL_SIZE,
			Vector2(size) * CELL_SIZE
		)
		draw_rect(rect.grow(-2.0), _get_module_color(module.definition.module_type))
		draw_rect(rect.grow(-2.0), Color.WHITE, false, 1.0)

func _get_module_color(module_type: ShipModuleDefinition.ModuleType) -> Color:
	match module_type:
		ShipModuleDefinition.ModuleType.ENERGY:
			return Color("#d9b84c")
		ShipModuleDefinition.ModuleType.PROPULSION:
			return Color("#5aa3d8")
		ShipModuleDefinition.ModuleType.WEAPON:
			return Color("#d65f5f")
		ShipModuleDefinition.ModuleType.DEFENSE:
			return Color("#65aa78")
		ShipModuleDefinition.ModuleType.FUNCTION:
			return Color("#9a79ca")
		ShipModuleDefinition.ModuleType.CORE:
			return Color("#d98c4a")
	return Color.GRAY
