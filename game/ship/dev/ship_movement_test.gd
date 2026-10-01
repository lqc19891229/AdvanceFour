extends Node2D

const SAVE_PATH := "user://ships/test_ship.json"
const RUNTIME_SCENE := preload("res://game/ship/runtime/ship_runtime.tscn")

@export var module_database: ModuleDatabase

var ship: ShipData
var runtime_ship: ShipRuntime

func _ready() -> void:
	var result := ShipSerializer.load_from_file(SAVE_PATH, module_database)
	if not result["ok"]:
		$CanvasLayer/Info.text = "加载失败：%s\n请先在飞船编辑器中保存设计。" % result["error"]
		set_process(false)
		return

	ship = result["ship"] as ShipData
	runtime_ship = RUNTIME_SCENE.instantiate() as ShipRuntime
	add_child(runtime_ship)
	runtime_ship.position = get_viewport_rect().size * 0.5
	runtime_ship.setup(ship)
	$CanvasLayer/Info.text = _build_info_text()

func _process(_delta: float) -> void:
	if runtime_ship == null or ship == null:
		return

	var throttle := 0.0
	var turn := 0.0

	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		throttle -= 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		turn -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		turn += 1.0

	runtime_ship.set_control_input(throttle, turn)
	$CanvasLayer/Info.text = _build_info_text()

func _build_info_text() -> String:
	return """RuntimeShip 朝向 / 推进测试
W / ↑：沿舰首前进
S / ↓：沿舰尾倒车
A / ←：左转
D / →：右转

模块：%d
质量：%.1f
推力：%.1f
推重比：%.3f
速度：%.1f
朝向：%.1f°
旋转中心：%s

结构规则：模块可分开放置，不要求相邻、连通或填满格子。""" % [
		ship.modules.size(),
		ship.get_mass(),
		ship.get_thrust(),
		ship.get_acceleration_score(),
		runtime_ship.get_speed(),
		runtime_ship.get_heading_degrees(),
		"舰桥核心" if runtime_ship.has_core_origin() else "未找到核心（回退到网格原点）"
	]
