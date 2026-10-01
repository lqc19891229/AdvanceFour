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
var projectile_hit_events := 0
var damage_events := 0
var target_destroyed_events := 0
var last_damage_amount := 0.0
var last_hit_firepower := 0.0
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
	runtime_ship.projectile_hit.connect(_on_projectile_hit)

	player_controller = PLAYER_CONTROLLER_SCENE.instantiate() as PlayerShipController
	add_child(player_controller)
	player_controller.setup(runtime_ship)

	target_dummy = TARGET_DUMMY_SCRIPT.new() as WeaponTargetDummy
	add_child(target_dummy)
	target_dummy.position = runtime_ship.position + Vector2(260.0, -120.0)
	target_dummy.damaged.connect(_on_target_damaged)
	target_dummy.destroyed.connect(_on_target_destroyed)

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

func _on_projectile_hit(target: Node2D, firepower: float) -> void:
	projectile_hit_events += 1
	last_hit_firepower = firepower

	if target != null and is_instance_valid(target) and target.has_method("apply_damage"):
		target.apply_damage(firepower)

func _on_target_damaged(amount: float, _current_hp: float) -> void:
	damage_events += 1
	last_damage_amount = amount

func _on_target_destroyed() -> void:
	target_destroyed_events += 1

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
弹丸命中事件：%d
伤害事件：%d
目标摧毁事件：%d
目标 HP：%s
最近伤害：%.1f
最近命中火力：%.1f
最近武器火力：%.1f
最近发射方向：(%.2f, %.2f)

当前阶段：Projectile 命中后由测试层把 firepower 作为伤害交给 DamageReceiver；目标 HP 归零后发出 destroyed 并销毁。
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
		projectile_hit_events,
		damage_events,
		target_destroyed_events,
		_build_target_hp_text(),
		last_damage_amount,
		last_hit_firepower,
		last_firepower,
		last_fire_direction.x,
		last_fire_direction.y
	]


func _build_target_hp_text() -> String:
	if target_dummy == null or not is_instance_valid(target_dummy):
		return "已摧毁"
	return "%.1f / %.1f" % [target_dummy.get_hp(), target_dummy.max_hp]
