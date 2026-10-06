extends Node2D

const SAVE_PATH := "user://ships/test_ship.json"
const EDITOR_SCENE := "res://game/ship/editor/ship_editor.tscn"
const RUNTIME_SCENE := preload("res://game/ship/runtime/ship_runtime.tscn")
const MODULE_DATABASE := preload("res://data/modules/module_database.tres")

var player: ShipRuntime
var enemy: ShipRuntime
var ai: AIShipController
var design_source := ""
var battle_status := "交火中"
var player_hits := 0
var enemy_hits := 0

func _ready() -> void:
	var design: ShipData
	if FileAccess.file_exists(SAVE_PATH):
		var result := ShipSerializer.load_from_file(SAVE_PATH, MODULE_DATABASE)
		if not result["ok"]:
			_show_load_error(result["error"])
			return
		design = result["ship"] as ShipData
		design_source = "已保存设计"
	else:
		design = _build_sample_design()
		design_source = "示例设计（未找到存档）"

	if not design.is_design_valid():
		_show_load_error(design.get_design_invalid_reason())
		return

	player = _spawn_ship(design, Vector2.ZERO, &"player_targets", &"enemy_targets")
	var controller := PlayerShipController.new()
	player.add_child(controller)
	controller.setup(player)
	player.destroyed.connect(_on_player_destroyed)
	player.projectile_hit.connect(func(_target: Node2D, _damage: float): player_hits += 1)

	# This opponent copies the layout for system testing, but must own independent Hull HP.
	var enemy_copy_result := ShipSerializer.from_dictionary(
		ShipSerializer.to_dictionary(design),
		MODULE_DATABASE
	)
	if not enemy_copy_result["ok"]:
		_show_load_error(enemy_copy_result["error"])
		return
	var enemy_design := enemy_copy_result["ship"] as ShipData
	enemy = _spawn_ship(enemy_design, Vector2(420.0, -120.0), &"enemy_targets", &"player_targets")
	ai = AIShipController.new()
	enemy.add_child(ai)
	ai.setup(enemy)
	enemy.destroyed.connect(_on_enemy_destroyed)
	enemy.projectile_hit.connect(func(_target: Node2D, _damage: float): enemy_hits += 1)

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	player.add_child(camera)
	$CanvasLayer/Info.text = _build_info_text()

func _spawn_ship(data: ShipData, spawn_position: Vector2, own_group: StringName, targets: StringName) -> ShipRuntime:
	var ship := RUNTIME_SCENE.instantiate() as ShipRuntime
	add_child(ship)
	ship.position = spawn_position
	ship.weapon_target_group = targets
	ship.add_to_group(own_group)
	ship.setup(data)
	return ship

func _build_sample_design() -> ShipData:
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
		var definition := MODULE_DATABASE.get_by_id(placement[0])
		var position: Vector2i = placement[1]
		var rotation: int = placement[2]
		design.ensure_hull_for_equipment(definition, position, rotation)
		design.place(definition, position, rotation)
	return design

func _process(_delta: float) -> void:
	$CanvasLayer/Info.text = _build_info_text()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.keycode == KEY_ESCAPE:
		get_tree().set_meta(&"restore_ship_design", true)
		get_tree().change_scene_to_file(EDITOR_SCENE)

func _on_player_destroyed() -> void:
	battle_status = "玩家核心被摧毁"
	# Camera must survive the player's queue_free so the result remains visible.
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reparent(self, true)
	$CanvasLayer/Info.text = _build_info_text()

func _on_enemy_destroyed() -> void:
	battle_status = "敌舰核心被摧毁"

func _show_load_error(message: String) -> void:
	$CanvasLayer/Info.text = "无法进入敌舰 AI 测试：%s\nEsc：返回编辑器修正设计" % message
	set_process(false)

func _build_info_text() -> String:
	var player_alive := is_instance_valid(player) and not player.is_removed_from_battle()
	var enemy_alive := is_instance_valid(enemy) and not enemy.is_removed_from_battle()
	return """敌舰 AI 交火测试｜%s
WASD / 方向键：移动与转向
R：重开测试   Esc：返回编辑器

状态：%s
玩家：%s   敌舰：%s
敌舰行为：%s
玩家命中：%d   敌舰命中：%d

敌舰转向追踪玩家，接近后保持距离，过近时倒车。
双方武器自动开火；Hull 局部损伤会降低对应设备效率；能源分配与核心失效共用正式规则。
本场是系统测试，不包含奖励、波次或正式阵营规则。""" % [
		design_source, battle_status,
		"存活" if player_alive else "已移除", "存活" if enemy_alive else "已移除",
		"追踪 / 保持距离" if enemy_alive and is_instance_valid(ai) and is_instance_valid(ai.target) else "无目标",
		player_hits, enemy_hits
	]
