class_name Battle
extends Node2D

signal finished(victory: bool)

enum Phase { PREPARING, FIGHTING, INTERMISSION, RESOLVING, VICTORY, DEFEAT, ERROR }

const PLAYER_SHIP_SAVE_PATH := "user://ships/test_ship.json"
const BATTLE_DEFINITION_META := &"battle_definition_path"
const RESULT_SCENE_PATH := "res://game/run/battle_result/battle_result_screen.tscn"
const SHIP_SCENE := preload("res://game/ship/runtime/ship_runtime.tscn")
const DATABASE := preload("res://data/modules/module_database.tres")
const PLAYER_LAYER := 4
const ENEMY_LAYER := 8

@export var battle_definition: BattleDefinition
@export var allow_debug_fallback_design := true

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
var battle_definition_error := ""
var pending_result: BattleResult

@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var hud: Label = $UI/HUD/Margin/Info
@onready var result_overlay: Control = $UI/ResultOverlay
@onready var result_title: Label = $UI/ResultOverlay/Center/Panel/Margin/Content/Title
@onready var result_summary: Label = $UI/ResultOverlay/Center/Panel/Margin/Content/Summary

func _init() -> void:
	process_physics_priority = 100

func _run_state() -> Node:
	return get_node_or_null("/root/RunState")

func _ready() -> void:
	$UI/ResultOverlay/Center/Panel/Margin/Content/Retry.pressed.connect(retry)
	$UI/ResultOverlay/Center/Panel/Margin/Content/Continue.pressed.connect(continue_after_victory)
	$UI/ResultOverlay/Center/Panel/Margin/Content/Return.pressed.connect(return_from_battle)
	$UI/Return.pressed.connect(return_from_battle)

	_resolve_battle_definition()
	if not battle_definition_error.is_empty():
		_show_error(battle_definition_error)
		return
	if battle_definition == null:
		_show_error("没有指定战斗配置。")
		return
	if not battle_definition.is_valid():
		_show_error(battle_definition.get_invalid_reason())
		return

	var design: ShipData
	var active_battle_path := _get_active_battle_path()
	if _run_state() != null and _run_state().run_active and not active_battle_path.is_empty():
		design = _run_state().get_ship_for_battle(active_battle_path)
		if design == null:
			_show_error("RunState 无法提供本场战斗的飞船状态。")
			return
		design_source = "Run 战损状态"
	elif FileAccess.file_exists(PLAYER_SHIP_SAVE_PATH):
		var loaded := ShipSerializer.load_from_file(PLAYER_SHIP_SAVE_PATH, DATABASE)
		if not loaded["ok"]:
			_show_error(loaded["error"])
			return
		design = loaded["ship"] as ShipData
		design_source = "已保存设计"
	elif allow_debug_fallback_design:
		design = build_starter_design()
		design_source = "调试示例设计"
	else:
		_show_error("没有可用于出航的玩家飞船。")
		return

	if not design.is_design_valid():
		_show_error(design.get_design_invalid_reason())
		return

	player = _spawn_ship(design, Vector2.ZERO, true)
	var controller := PlayerShipController.new()
	player.add_child(controller)
	controller.setup(player)
	player.destroyed.connect(_on_player_destroyed)
	countdown = battle_definition.preparation_seconds
	_update_hud()

func _get_active_battle_path() -> String:
	if battle_definition == null:
		return ""
	return battle_definition.resource_path

func _resolve_battle_definition() -> void:
	if not get_tree().has_meta(BATTLE_DEFINITION_META):
		return
	var definition_path := String(get_tree().get_meta(BATTLE_DEFINITION_META))
	get_tree().remove_meta(BATTLE_DEFINITION_META)
	if definition_path.is_empty():
		battle_definition = null
		battle_definition_error = "指定的战斗配置路径为空。"
		return
	if not ResourceLoader.exists(definition_path):
		battle_definition = null
		battle_definition_error = "指定的战斗配置不存在：%s" % definition_path
		return
	var loaded := ResourceLoader.load(definition_path)
	if not (loaded is BattleDefinition):
		battle_definition = null
		battle_definition_error = "指定资源不是 BattleDefinition：%s" % definition_path
		return
	battle_definition = loaded as BattleDefinition

static func build_starter_design() -> ShipData:
	var design := ShipData.new()
	var placements := [
		[&"core_bridge", Vector2i.ZERO, 0],
		[&"energy_smallreactor", Vector2i(-1, 1), 0],
		[&"energy_smallreactor", Vector2i(2, 1), 0],
		[&"propulsion_smallengine", Vector2i(0, 2), 0],
		[&"propulsion_smallengine", Vector2i(1, 2), 0],
		[&"weapon_cannon", Vector2i(0, -1), 3]
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
			var wave := battle_definition.get_wave(wave_index)
			if wave == null:
				_show_error("当前波次配置不存在。")
				return
			var wave_total := wave.get_total_enemy_count()
			spawn_countdown -= delta
			if spawned_in_wave < wave_total and spawn_countdown <= 0.0:
				_spawn_enemy()
				spawn_countdown = _get_current_spawn_interval()
			if spawned_in_wave == wave_total and enemies.is_empty():
				if wave_index == battle_definition.get_wave_count() - 1:
					phase = Phase.RESOLVING
				else:
					phase = Phase.INTERMISSION
					countdown = maxf(battle_definition.intermission_seconds, 0.0)
		Phase.RESOLVING:
			if not _has_live_projectiles():
				_finish_battle(true)

func _start_next_wave() -> void:
	wave_index += 1
	spawned_in_wave = 0
	spawn_countdown = 0.0
	phase = Phase.FIGHTING
	_spawn_enemy()
	spawn_countdown = _get_current_spawn_interval()

func _get_current_spawn_interval() -> float:
	var wave := battle_definition.get_wave(wave_index)
	if wave != null and wave.spawn_interval_seconds >= 0.0:
		return wave.spawn_interval_seconds
	return maxf(battle_definition.spawn_interval_seconds, 0.0)

func _spawn_enemy() -> void:
	var wave := battle_definition.get_wave(wave_index)
	if wave == null:
		_show_error("当前波次配置不存在。")
		return
	var wave_count := wave.get_total_enemy_count()
	var enemy_definition := wave.get_enemy_for_spawn_index(spawned_in_wave)
	if enemy_definition == null:
		_show_error("当前波次无法解析敌舰配置。")
		return
	var enemy_design := enemy_definition.build_design(DATABASE)
	if enemy_design == null:
		_show_error("敌舰蓝图无法生成有效飞船：%s" % enemy_definition.display_name)
		return
	var angle := float(wave_index) * 1.1 + TAU * float(spawned_in_wave) / float(wave_count)
	var location := player.global_position + Vector2.RIGHT.rotated(angle) * maxf(battle_definition.spawn_radius, 180.0)
	var enemy := _spawn_ship(enemy_design, location, false)
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
	pending_result = BattleResult.new()
	pending_result.outcome = BattleResult.Outcome.VICTORY if victory else BattleResult.Outcome.DEFEAT
	pending_result.battle_id = battle_definition.battle_id
	pending_result.battle_path = _get_active_battle_path()
	pending_result.next_battle_path = battle_definition.next_battle_path
	pending_result.reward_credits = battle_definition.reward_credits if victory else 0
	pending_result.reward_module_ids = battle_definition.reward_module_ids.duplicate() if victory else []
	pending_result.reward_module_counts = battle_definition.reward_module_counts.duplicate() if victory else []
	pending_result.reward_hull_cells = battle_definition.reward_hull_cells if victory else 0
	pending_result.enemies_destroyed = defeated_enemies
	pending_result.elapsed_seconds = elapsed_seconds
	if victory and is_instance_valid(player):
		var cloned := ShipSerializer.from_dictionary(ShipSerializer.to_dictionary(player.ship_data), DATABASE)
		if cloned["ok"]:
			pending_result.ship_after_battle = cloned["ship"] as ShipData
	if not victory and _run_state() != null and _run_state().run_active:
		_run_state().record_defeat(pending_result)

	result_title.text = "战斗胜利" if victory else "战斗失败"
	result_summary.text = "%s\n击毁敌舰：%d\n到达波次：%d / %d\n战斗时间：%.1f 秒\n%s\n\n%s" % [
		battle_definition.display_name,
		defeated_enemies,
		maxi(wave_index + 1, 0),
		battle_definition.get_wave_count(),
		elapsed_seconds,
		_format_battle_reward() if victory and _run_state() != null and _run_state().run_active else "",
		"全部波次已清除。" if victory else "核心承载船体被摧毁。"
	]
	$UI/ResultOverlay/Center/Panel/Margin/Content/Continue.visible = victory and _run_state().run_active
	result_overlay.show()
	_update_hud()
	finished.emit(victory)


func _format_battle_reward() -> String:
	var parts: Array[String] = []
	if battle_definition.reward_credits > 0:
		parts.append("%d Credits" % battle_definition.reward_credits)
	if battle_definition.reward_hull_cells > 0:
		parts.append("%d Hull" % battle_definition.reward_hull_cells)
	for index in range(battle_definition.reward_module_ids.size()):
		var module_id := battle_definition.reward_module_ids[index]
		var count := 1
		if index < battle_definition.reward_module_counts.size():
			count = battle_definition.reward_module_counts[index]
		var definition := DATABASE.get_by_id(module_id)
		var name := String(module_id) if definition == null else definition.display_name
		parts.append("%s ×%d" % [name, count])
	return "奖励：" + ("无" if parts.is_empty() else " / ".join(parts))

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
	if battle_definition == null:
		return
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
		var wave := battle_definition.get_wave(wave_index)
		if wave != null:
			remaining = maxi(wave.get_total_enemy_count() - spawned_in_wave, 0)

	hud.text = """前进四｜%s｜%s
%s  波次 %d / %d
场上敌舰：%d  本波待生成：%d  击毁：%d
Hull HP：%.0f / %.0f  核心效率：%.0f%%  可用设备：%d
可用武器：%d  供能 / 需求：%.0f / %.0f  有效推力：%.0f
速度：%.1f px/s  坐标：(%.1f, %.1f)
W/S 前进 / 倒车｜A/D 转向｜方向键同理｜R 重开｜Esc 返回""" % [
		battle_definition.display_name,
		design_source,
		status,
		maxi(wave_index + 1, 0),
		battle_definition.get_wave_count(),
		enemies.size(),
		remaining,
		defeated_enemies,
		hull_hp,
		hull_max_hp,
		core_efficiency * 100.0,
		active_equipment,
		weapons,
		energy_output,
		energy_cost,
		thrust,
		speed,
		location.x,
		location.y
	]

func continue_after_victory() -> void:
	if phase != Phase.VICTORY or _run_state() == null or not _run_state().run_active or pending_result == null:
		return
	if not _run_state().commit_victory(pending_result):
		_show_error("无法提交本场战斗结果。")
		return
	get_tree().change_scene_to_file(RESULT_SCENE_PATH)

func retry() -> void:
	if battle_definition != null and not battle_definition.resource_path.is_empty():
		get_tree().set_meta(BATTLE_DEFINITION_META, battle_definition.resource_path)
	get_tree().reload_current_scene()

func return_from_battle() -> void:
	if battle_definition == null or battle_definition.return_scene_path.is_empty():
		return
	if _run_state() != null and _run_state().run_active:
		_run_state().reset_run()
	if battle_definition.restore_saved_ship_on_return:
		get_tree().set_meta(&"restore_ship_design", true)
	get_tree().change_scene_to_file(battle_definition.return_scene_path)

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_R:
		retry()
	elif event.keycode == KEY_ESCAPE:
		return_from_battle()
