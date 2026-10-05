class_name Battle
extends Node2D

signal finished(victory: bool)

enum Phase { PREPARING, FIGHTING, INTERMISSION, RESOLVING, VICTORY, DEFEAT, ERROR }

const SAVE_PATH := "user://ships/test_ship.json"
const EDITOR_SCENE := "res://game/ship/editor/ship_editor.tscn"
const SHIP_SCENE := preload("res://game/ship/runtime/ship_runtime.tscn")
const DATABASE := preload("res://data/generated/module_database.tres")
const PLAYER_LAYER := 4
const ENEMY_LAYER := 8

# Encounter tuning remains Prototype scene data; module statistics still come from Excel.
@export var wave_enemy_counts: Array[int] = [1, 1, 2]
@export var preparation_seconds := 2.0
@export var intermission_seconds := 3.0
@export var spawn_interval_seconds := 1.25
@export var spawn_radius := 460.0

var phase := Phase.PREPARING
var player: ShipRuntime
var enemies: Array[ShipRuntime] = []
var wave_index := -1
var spawned_in_wave := 0
var defeated_enemies := 0
var elapsed_seconds := 0.0
var countdown := 0.0
var spawn_countdown := 0.0
var design_source := ""

@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var hud: Label = $UI/HUD/Margin/Info
@onready var result_overlay: Control = $UI/ResultOverlay
@onready var result_title: Label = $UI/ResultOverlay/Center/Panel/Margin/Content/Title
@onready var result_summary: Label = $UI/ResultOverlay/Center/Panel/Margin/Content/Summary

func _init() -> void:
	# Evaluate outcomes after ships and projectiles have applied this physics frame's damage.
	process_physics_priority = 100

func _ready() -> void:
	$UI/ResultOverlay/Center/Panel/Margin/Content/Retry.pressed.connect(retry)
	$UI/ResultOverlay/Center/Panel/Margin/Content/Return.pressed.connect(return_to_editor)
	$UI/Return.pressed.connect(return_to_editor)
	if wave_enemy_counts.is_empty() or wave_enemy_counts.any(func(count: int): return count <= 0):
		_show_error("波次必须至少包含一波，且每波敌舰数量必须大于零。")
		return

	var design: ShipData
	if FileAccess.file_exists(SAVE_PATH):
		var loaded := ShipSerializer.load_from_file(SAVE_PATH, DATABASE)
		if not loaded["ok"]:
			_show_error(loaded["error"])
			return
		design = loaded["ship"] as ShipData
		design_source = "已保存设计"
	else:
		design = build_starter_design()
		design_source = "示例设计"
	if not design.is_design_valid():
		_show_error(design.get_design_invalid_reason())
		return

	player = _spawn_ship(design, Vector2.ZERO, true)
	var controller := PlayerShipController.new()
	player.add_child(controller)
	controller.setup(player)
	player.destroyed.connect(_on_player_destroyed)
	countdown = maxf(preparation_seconds, 0.0)
	_update_hud()

static func build_starter_design() -> ShipData:
	var design := ShipData.new()
	var placements := [
		[&"core_bridge", Vector2i.ZERO, 0],
		[&"energy_smallreactor", Vector2i(-1, 1), 0],
		[&"energy_smallreactor", Vector2i(2, 1), 0],
		[&"propulsion_smallengine", Vector2i(0, 2), 0],
		[&"propulsion_smallengine", Vector2i(1, 2), 0],
		[&"weapon_cannon", Vector2i(0, -1), 0]
	]
	for placement in placements:
		var definition := DATABASE.get_by_id(placement[0])
		var position: Vector2i = placement[1]
		var rotation: int = placement[2]
		design.ensure_hull_for_equipment(definition, position, rotation)
		design.place(definition, position, rotation)
	return design

func _spawn_ship(design: ShipData, location: Vector2, is_player: bool) -> ShipRuntime:
	var ship := SHIP_SCENE.instantiate() as ShipRuntime
	world.add_child(ship)
	ship.position = location
	ship.weapon_target_group = &"enemy_targets" if is_player else &"player_targets"
	ship.add_to_group(&"player_targets" if is_player else &"enemy_targets")
	ship.setup(design)
	for hull_runtime in ship.hull_runtimes:
		hull_runtime.collision_layer = PLAYER_LAYER if is_player else ENEMY_LAYER
	ship.projectile_spawned.connect(_configure_projectile.bind(is_player))
	return ship

func _configure_projectile(projectile: ProjectileRuntime, from_player: bool) -> void:
	# Keep the mask on the projectile, including after the firing ship is destroyed.
	projectile.collision_layer = 0
	projectile.collision_mask = ENEMY_LAYER if from_player else PLAYER_LAYER

func _physics_process(delta: float) -> void:
	if _is_terminal():
		return
	if not _player_alive():
		_finish_battle(false)
		return
	elapsed_seconds += delta
	match phase:
		Phase.PREPARING, Phase.INTERMISSION:
			countdown = maxf(countdown - delta, 0.0)
			if countdown <= 0.0:
				_start_next_wave()
		Phase.FIGHTING:
			spawn_countdown -= delta
			if spawned_in_wave < wave_enemy_counts[wave_index] and spawn_countdown <= 0.0:
				_spawn_enemy()
				spawn_countdown = maxf(spawn_interval_seconds, 0.0)
			if spawned_in_wave == wave_enemy_counts[wave_index] and enemies.is_empty():
				if wave_index == wave_enemy_counts.size() - 1:
					phase = Phase.RESOLVING
				else:
					phase = Phase.INTERMISSION
					countdown = maxf(intermission_seconds, 0.0)
		Phase.RESOLVING:
			if not _has_live_projectiles():
				_finish_battle(true)

func _start_next_wave() -> void:
	wave_index += 1
	spawned_in_wave = 0
	spawn_countdown = 0.0
	phase = Phase.FIGHTING
	_spawn_enemy()
	spawn_countdown = maxf(spawn_interval_seconds, 0.0)

func _spawn_enemy() -> void:
	var angle := float(wave_index) * 1.1 + TAU * float(spawned_in_wave) / float(wave_enemy_counts[wave_index])
	var location := player.global_position + Vector2.RIGHT.rotated(angle) * maxf(spawn_radius, 180.0)
	var enemy := _spawn_ship(build_starter_design(), location, false)
	enemy.rotation = Vector2.UP.angle_to(player.global_position - location)
	var controller := AIShipController.new()
	enemy.add_child(controller)
	controller.setup(enemy)
	enemy.destroyed.connect(_on_enemy_destroyed.bind(enemy))
	enemies.append(enemy)
	spawned_in_wave += 1

func _on_enemy_destroyed(enemy: ShipRuntime) -> void:
	if _is_terminal() or not enemies.has(enemy):
		return
	enemies.erase(enemy)
	defeated_enemies += 1

func _on_player_destroyed() -> void:
	_finish_battle(false)

func _has_live_projectiles() -> bool:
	for child in world.get_children():
		if child is ProjectileRuntime and not child.finished and not child.is_queued_for_deletion():
			return true
	return false

func _player_alive() -> bool:
	return is_instance_valid(player) and not player.is_removed_from_battle()

func _is_terminal() -> bool:
	return phase in [Phase.VICTORY, Phase.DEFEAT, Phase.ERROR]

func _finish_battle(victory: bool) -> void:
	if _is_terminal():
		return
	phase = Phase.VICTORY if victory else Phase.DEFEAT
	world.process_mode = Node.PROCESS_MODE_DISABLED
	result_title.text = "战斗胜利" if victory else "战斗失败"
	result_summary.text = "击毁敌舰：%d\n到达波次：%d / %d\n战斗时间：%.1f 秒\n\n%s" % [
		defeated_enemies, maxi(wave_index + 1, 0), wave_enemy_counts.size(), elapsed_seconds,
		"全部波次已清除。" if victory else "核心承载船体被摧毁。"
	]
	result_overlay.show()
	_update_hud()
	finished.emit(victory)

func _show_error(message: String) -> void:
	phase = Phase.ERROR
	world.process_mode = Node.PROCESS_MODE_DISABLED
	hud.text = "无法开始战斗"
	result_title.text = "无法出航"
	result_summary.text = message
	result_overlay.show()

func _process(_delta: float) -> void:
	if phase == Phase.ERROR:
		return
	if _player_alive():
		camera.global_position = player.global_position
	_update_hud()

func _update_hud() -> void:
	var hull_hp := 0.0
	var hull_max_hp := 0.0
	var core_efficiency := 0.0
	var active_equipment := 0
	var weapons := 0
	var energy_output := 0.0
	var energy_cost := 0.0
	var thrust := 0.0
	var speed := 0.0
	var location := camera.global_position
	if _player_alive():
		hull_hp = player.get_current_hull_hp()
		hull_max_hp = player.get_max_hull_hp()
		core_efficiency = player.get_core_efficiency()
		for module in player.ship_data.modules:
			if player.get_module_efficiency(module) > 0.0:
				active_equipment += 1
		weapons = player.get_active_weapon_count()
		energy_output = player.get_effective_energy_output()
		energy_cost = player.get_effective_energy_cost()
		thrust = player.get_effective_thrust()
		speed = player.get_speed()
		location = player.global_position
	var status := "交战中"
	match phase:
		Phase.PREPARING:
			status = "出航准备：%.1f 秒" % countdown
		Phase.INTERMISSION:
			status = "下一波：%.1f 秒" % countdown
		Phase.RESOLVING:
			status = "敌舰已清除，躲避残留弹丸"
		Phase.VICTORY:
			status = "战斗胜利"
		Phase.DEFEAT:
			status = "战斗失败"
	var remaining := 0
	if wave_index >= 0 and phase in [Phase.FIGHTING, Phase.RESOLVING]:
		remaining = maxi(wave_enemy_counts[wave_index] - spawned_in_wave, 0)
	hud.text = """前进四｜%s
%s  波次 %d / %d
场上敌舰：%d  本波待生成：%d  击毁：%d
Hull HP：%.0f / %.0f  核心效率：%.0f%%  可用设备：%d
可用武器：%d  供能 / 需求：%.0f / %.0f  有效推力：%.0f
速度：%.1f px/s  坐标：(%.1f, %.1f)
W/S 前进 / 倒车｜A/D 转向｜方向键同理｜R 重开｜Esc 返回""" % [
		design_source, status, maxi(wave_index + 1, 0), wave_enemy_counts.size(),
		enemies.size(), remaining, defeated_enemies,
		hull_hp, hull_max_hp, core_efficiency * 100.0, active_equipment,
		weapons, energy_output, energy_cost, thrust,
		speed, location.x, location.y
	]

func retry() -> void:
	get_tree().reload_current_scene()

func return_to_editor() -> void:
	get_tree().set_meta(&"restore_ship_design", true)
	get_tree().change_scene_to_file(EDITOR_SCENE)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_R:
		retry()
	elif event.keycode == KEY_ESCAPE:
		return_to_editor()
