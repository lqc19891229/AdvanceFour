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
var hull_damage_events := 0
var hull_destroyed_events := 0
var target_ship_destroyed_events := 0
var target_removed_from_battle := false
var last_damage_amount := 0.0
var last_hit_firepower := 0.0
var last_firepower := 0.0
var last_fire_direction := Vector2.ZERO
var last_damaged_hull: ShipHullCell
var last_hull_hp := 0.0
var last_hull_max_hp := 0.0
var last_effective_protection := 0.0

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
	target_runtime_ship.hull_cell_damaged.connect(_on_target_hull_damaged)
	target_runtime_ship.hull_cell_destroyed.connect(_on_target_hull_destroyed)
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

func _on_target_hull_damaged(
	hull_cell: ShipHullCell,
	amount: float,
	current_hp: float
) -> void:
	hull_damage_events += 1
	last_damage_amount = amount
	last_damaged_hull = hull_cell
	last_hull_hp = current_hp
	_update_last_hull_info(hull_cell)

func _on_target_hull_destroyed(hull_cell: ShipHullCell) -> void:
	hull_destroyed_events += 1
	last_damaged_hull = hull_cell
	last_hull_hp = 0.0
	_update_last_hull_info(hull_cell)

func _on_target_ship_destroyed() -> void:
	target_ship_destroyed_events += 1
	target_removed_from_battle = true
	target_runtime_ship = null

func _build_info_text() -> String:
	return """RuntimeShip / WeaponRuntime Hull 局部受击测试
W / ↑：沿舰首前进
S / ↓：沿舰尾倒车
A / ←：左转
D / →：右转

右上方飞船：Hull 命中测试目标
玩家武器会自动搜索 enemy_targets，并向目标飞船开火。
目标飞船的每个 Hull Cell 都有独立碰撞体；区域 HP = ShipHullCell HP + 覆盖 Defense HP。

控制器：PlayerShipController（只负责移动）
玩家模块：%d
玩家武器：%d
推力：%.1f
火力：%.1f
推进评分：%.1f
最高速度：%.1f
当前加速度：%.1f
当前减速度：%.1f
速度：%.1f
朝向：%.1f°
目标 Equipment Runtime：%d
目标可用武器：%d
目标存活武器：%d / %d
目标有效推力：%.1f / %.1f
目标有效供能：%.1f / %.1f
目标有效耗能：%.1f
目标已供电耗能：%.1f
目标供电模块：%d / %d
目标能源状态：%s
目标战斗状态：%s
整船移除事件：%d
区域 HP：ShipHullCell + Defense.hp；设备效率取覆盖 Hull 健康度平均值
武器触发事件：%d
弹丸生成事件：%d
弹丸命中事件：%d
Hull 受伤事件：%d
Hull 摧毁事件：%d
最近受伤 Hull：%s
最近 Hull HP：%.1f / %.1f
当前有效防御系统：%.1f%%
最近伤害：%.1f
最近命中火力：%.1f
最近发射方向：(%.2f, %.2f)

当前阶段：Projectile 使用 swept ray 命中具体 Hull Cell。
Defense Equipment 的 hp 会平均附加到其覆盖的 Hull 区域；protection 仍按对应 Hull 健康度缩放后作用于整船受击减伤。
命中先计算 damage_after_protection，再扣具体 Hull Cell HP。
如果 Hull Cell 被击穿，则把剩余伤害交回 Projectile 继续穿透。
Projectile 会携带 leftover 在同一弹道继续向内查询，因此同一发高伤害弹丸仍可连续击穿低血量模块。
如果伤害被当前 Hull Cell 完全吸收，则该发 Projectile 在这里结束。
命中伤害不再依赖发射者 RuntimeShip 的 projectile_hit 转发，因此发射者先被摧毁时，已发射弹丸仍可造成伤害。
Hull 受损会线性降低其覆盖 Equipment 效率；武器火力/射速、动力、供能与防御都会随效率下降。
供能不足时仍按 核心 > 能源 > 动力 > 防护 > 功能 > 武器 的 Prototype 优先级逐个供电。
未获供电的动力不贡献推力，未获供电的武器停止工作；不再采用整船全部断电。
核心 Equipment 覆盖的 Hull 全部损毁后 RuntimeShip 发出 destroyed，并从战斗场景移除。
炮塔瞄准距离自身最近的存活 Hull Cell；已摧毁 Hull 不再作为瞄准点。
结构规则：Hull Layout 决定结构与碰撞；Equipment 必须完整安装在 Hull 上。""" % [
		ship.modules.size(),
		runtime_ship.get_weapon_count(),
		ship.get_thrust(),
		ship.get_firepower(),
		ship.get_acceleration_score(),
		runtime_ship.get_max_speed(),
		runtime_ship.get_acceleration(),
		runtime_ship.get_deceleration(),
		runtime_ship.get_speed(),
		runtime_ship.get_heading_degrees(),
		_get_target_module_runtime_count(),
		_get_target_active_weapon_count(),
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
		weapon_fire_events,
		projectile_spawn_events,
		projectile_hit_events,
		hull_damage_events,
		hull_destroyed_events,
		_get_last_hull_name(),
		last_hull_hp,
		last_hull_max_hp,
		last_effective_protection,
		last_damage_amount,
		last_hit_firepower,
		last_fire_direction.x,
		last_fire_direction.y
	]

func _get_last_hull_name() -> String:
	if last_damaged_hull == null:
		return "无"
	return "(%d, %d)" % [
		last_damaged_hull.grid_position.x,
		last_damaged_hull.grid_position.y
	]


func _has_target_runtime_ship() -> bool:
	return target_runtime_ship != null and is_instance_valid(target_runtime_ship)

func _get_target_module_runtime_count() -> int:
	return target_runtime_ship.get_module_runtime_count() if _has_target_runtime_ship() else 0

func _get_target_active_weapon_count() -> int:
	return target_runtime_ship.get_active_weapon_count() if _has_target_runtime_ship() else 0

func _get_target_operational_weapon_count() -> int:
	return target_runtime_ship.get_operational_weapon_count() if _has_target_runtime_ship() else 0

func _get_target_weapon_count() -> int:
	return target_runtime_ship.get_weapon_count() if _has_target_runtime_ship() else 0

func _get_target_effective_thrust() -> float:
	return target_runtime_ship.get_effective_thrust() if _has_target_runtime_ship() else 0.0

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


func _update_last_hull_info(hull_cell: ShipHullCell) -> void:
	last_hull_max_hp = 0.0
	last_effective_protection = 0.0
	if not _has_target_runtime_ship() or hull_cell == null:
		return
	last_hull_max_hp = target_runtime_ship.ship_data.get_hull_cell_effective_max_hp(hull_cell)
	last_effective_protection = target_runtime_ship.get_effective_protection()

