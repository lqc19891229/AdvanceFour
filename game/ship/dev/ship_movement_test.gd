extends Node2D

const SAVE_PATH := "user://ships/test_ship.json"
const RUNTIME_SCENE := preload("res://game/ship/runtime/ship_runtime.tscn")
const PLAYER_CONTROLLER_SCENE := preload("res://game/ship/controller/player_ship_controller.tscn")

@export var module_database: ModuleDatabase

var ship: ShipData
var runtime_ship: ShipRuntime
var target_runtime_ship: ShipRuntime
var player_controller: PlayerShipController
var weapon_fire_events := 0
var projectile_spawn_events := 0
var projectile_hit_events := 0
var module_damage_events := 0
var module_destroyed_events := 0
var target_ship_destroyed_events := 0
var target_removed_from_battle := false
var last_damage_amount := 0.0
var last_hit_firepower := 0.0
var last_firepower := 0.0
var last_fire_direction := Vector2.ZERO
var last_damaged_module: ShipModuleInstance
var last_module_hp := 0.0

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

	target_runtime_ship = RUNTIME_SCENE.instantiate() as ShipRuntime
	add_child(target_runtime_ship)
	target_runtime_ship.position = runtime_ship.position + Vector2(260.0, -120.0)
	target_runtime_ship.weapon_target_group = &"player_targets"
	target_runtime_ship.setup(ship)
	target_runtime_ship.add_to_group(&"enemy_targets")
	target_runtime_ship.module_damaged.connect(_on_target_module_damaged)
	target_runtime_ship.module_destroyed.connect(_on_target_module_destroyed)
	target_runtime_ship.destroyed.connect(_on_target_ship_destroyed)

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

func _on_projectile_hit(_target: Node2D, firepower: float) -> void:
	projectile_hit_events += 1
	last_hit_firepower = firepower

func _on_target_module_damaged(
	module_instance: ShipModuleInstance,
	amount: float,
	current_hp: float
) -> void:
	module_damage_events += 1
	last_damage_amount = amount
	last_damaged_module = module_instance
	last_module_hp = current_hp

func _on_target_module_destroyed(module_instance: ShipModuleInstance) -> void:
	module_destroyed_events += 1
	last_damaged_module = module_instance
	last_module_hp = 0.0

func _on_target_ship_destroyed() -> void:
	target_ship_destroyed_events += 1
	target_removed_from_battle = true
	target_runtime_ship = null

func _build_info_text() -> String:
	return """RuntimeShip / WeaponRuntime 模块受击测试
W / ↑：沿舰首前进
S / ↓：沿舰尾倒车
A / ←：左转
D / →：右转

右上方飞船：模块命中测试目标
玩家武器会自动搜索 enemy_targets，并向目标飞船开火。
目标飞船的每个模块都有独立碰撞体和独立 HP。

控制器：PlayerShipController（只负责移动）
玩家模块：%d
玩家武器：%d
质量：%.1f
推力：%.1f
火力：%.1f
推重比：%.3f
速度：%.1f
朝向：%.1f°
目标模块 Runtime：%d
目标可用武器：%d / %d
目标有效推力：%.1f / %.1f
目标有效供能：%.1f / %.1f
目标有效耗能：%.1f
目标已供电耗能：%.1f
目标供电模块：%d / %d
目标能源状态：%s
目标战斗状态：%s
整船移除事件：%d
模块 Prototype HP：%.1f
武器触发事件：%d
弹丸生成事件：%d
弹丸命中事件：%d
模块受伤事件：%d
模块摧毁事件：%d
最近受伤模块：%s
最近模块 HP：%.1f
最近伤害：%.1f
最近命中火力：%.1f
最近发射方向：(%.2f, %.2f)

当前阶段：Projectile 直接碰撞目标飞船的 ShipModuleRuntime，并自行调用 apply_damage(firepower)。
命中伤害不再依赖发射者 RuntimeShip 的 projectile_hit 转发，因此发射者先被摧毁时，已发射弹丸仍可造成伤害。
武器模块摧毁后对应 WeaponRuntime 停止；动力模块摧毁后有效推力下降。
能源模块摧毁后有效供能下降；供能不足时按 核心 > 能源 > 动力 > 防护 > 功能 > 武器 的 Prototype 优先级逐个供电。
未获供电的动力不贡献推力，未获供电的武器停止工作；不再采用整船全部断电。
核心模块摧毁后 RuntimeShip 发出 destroyed，并从战斗场景 queue_free() 移除。
炮塔始终瞄准距离自身最近的存活模块；已摧毁模块不会继续作为瞄准点。
结构规则：模块可分开放置，不要求相邻、连通或填满格子；空格不会生成碰撞体。""" % [
		ship.modules.size(),
		runtime_ship.get_weapon_count(),
		ship.get_mass(),
		ship.get_thrust(),
		ship.get_firepower(),
		ship.get_acceleration_score(),
		runtime_ship.get_speed(),
		runtime_ship.get_heading_degrees(),
		_get_target_module_runtime_count(),
		_get_target_operational_weapon_count(),
		_get_target_weapon_count(),
		_get_target_effective_thrust(),
		ship.get_thrust(),
		_get_target_effective_energy_output(),
		ship.get_energy_output(),
		_get_target_effective_energy_cost(),
		_get_target_powered_energy_cost(),
		_get_target_powered_module_count(),
		_get_target_module_runtime_count(),
		_get_target_energy_state_text(),
		"已移除" if target_removed_from_battle else "战斗中",
		target_ship_destroyed_events,
		_get_target_prototype_module_hp(),
		weapon_fire_events,
		projectile_spawn_events,
		projectile_hit_events,
		module_damage_events,
		module_destroyed_events,
		_get_last_module_name(),
		last_module_hp,
		last_damage_amount,
		last_hit_firepower,
		last_fire_direction.x,
		last_fire_direction.y
	]

func _get_last_module_name() -> String:
	if last_damaged_module == null or last_damaged_module.definition == null:
		return "无"
	return last_damaged_module.definition.display_name


func _has_target_runtime_ship() -> bool:
	return target_runtime_ship != null and is_instance_valid(target_runtime_ship)

func _get_target_module_runtime_count() -> int:
	return target_runtime_ship.get_module_runtime_count() if _has_target_runtime_ship() else 0

func _get_target_operational_weapon_count() -> int:
	return target_runtime_ship.get_operational_weapon_count() if _has_target_runtime_ship() else 0

func _get_target_weapon_count() -> int:
	return target_runtime_ship.get_weapon_count() if _has_target_runtime_ship() else 0

func _get_target_effective_thrust() -> float:
	return target_runtime_ship.get_effective_thrust() if _has_target_runtime_ship() else 0.0

func _get_target_prototype_module_hp() -> float:
	return target_runtime_ship.prototype_module_hp if _has_target_runtime_ship() else 0.0


func _get_target_effective_energy_output() -> float:
	return target_runtime_ship.get_effective_energy_output() if _has_target_runtime_ship() else 0.0

func _get_target_effective_energy_cost() -> float:
	return target_runtime_ship.get_effective_energy_cost() if _has_target_runtime_ship() else 0.0

func _get_target_energy_state_text() -> String:
	if not _has_target_runtime_ship():
		return "无"
	return "正常" if target_runtime_ship.is_energy_sufficient() else "能源不足"


func _get_target_powered_energy_cost() -> float:
	return target_runtime_ship.get_powered_energy_cost() if _has_target_runtime_ship() else 0.0

func _get_target_powered_module_count() -> int:
	return target_runtime_ship.get_powered_module_count() if _has_target_runtime_ship() else 0
