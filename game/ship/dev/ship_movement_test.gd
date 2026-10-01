extends Node2D

const SAVE_PATH := "user://ships/test_ship.json"
const RUNTIME_SCENE := preload("res://game/ship/runtime/ship_runtime.tscn")
const PLAYER_CONTROLLER_SCENE := preload("res://game/ship/controller/player_ship_controller.tscn")
const TARGET_DUMMY_SCRIPT := preload("res://game/ship/dev/weapon_target_dummy.gd")

@export var module_database: ModuleDatabase

var ship: ShipData
var runtime_ship: ShipRuntime
var player_controller: PlayerShipController
var target_dummy: WeaponTargetDummy
var weapon_fire_events := 0
var projectile_spawn_events := 0
var last_firepower := 0.0
var last_fire_direction := Vector2.ZERO

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
	runtime_ship.weapon_fired.connect(_on_weapon_fired)
	runtime_ship.projectile_spawned.connect(_on_projectile_spawned)

	player_controller = PLAYER_CONTROLLER_SCENE.instantiate() as PlayerShipController
	add_child(player_controller)
	player_controller.setup(runtime_ship)

	target_dummy = TARGET_DUMMY_SCRIPT.new() as WeaponTargetDummy
	add_child(target_dummy)
	target_dummy.position = runtime_ship.position + Vector2(260.0, -120.0)

	$CanvasLayer/Info.text = _build_info_text()

func _process(_delta: float) -> void:
	if runtime_ship == null or ship == null:
		return

	$CanvasLayer/Info.text = _build_info_text()

func _on_weapon_fired(
	_module_instance: ShipModuleInstance,
	firepower: float,
	_world_position: Vector2,
	world_direction: Vector2
) -> void:
	weapon_fire_events += 1
	last_firepower = firepower
	last_fire_direction = world_direction

func _on_projectile_spawned(_projectile: ProjectileRuntime) -> void:
	projectile_spawn_events += 1

func _build_info_text() -> String:
	return """RuntimeShip / WeaponRuntime 自动炮塔测试
W / ↑：沿舰首前进
S / ↓：沿舰尾倒车
A / ←：左转
D / →：右转

白色十字圆：自动瞄准测试目标
武器会自动搜索 enemy_targets 组内、攻击范围内最近的目标。

控制器：PlayerShipController（只负责移动）
模块：%d
武器：%d
质量：%.1f
推力：%.1f
火力：%.1f
推重比：%.3f
速度：%.1f
朝向：%.1f°
旋转中心：%s
武器触发事件：%d
弹丸生成事件：%d
最近武器火力：%.1f
最近发射方向：(%.2f, %.2f)

当前阶段：炮塔自动选目标、转向并生成 Projectile；Projectile 直线飞行并在生命周期结束后自动销毁。
结构规则：模块可分开放置，不要求相邻、连通或填满格子。""" % [
		ship.modules.size(),
		runtime_ship.get_weapon_count(),
		ship.get_mass(),
		ship.get_thrust(),
		ship.get_firepower(),
		ship.get_acceleration_score(),
		runtime_ship.get_speed(),
		runtime_ship.get_heading_degrees(),
		"舰桥核心" if runtime_ship.has_core_origin() else "未找到核心（回退到网格原点）",
		weapon_fire_events,
		projectile_spawn_events,
		last_firepower,
		last_fire_direction.x,
		last_fire_direction.y
	]
