extends SceneTree

const DATABASE := preload("res://data/generated/module_database.tres")
const RUNTIME := preload("res://game/ship/runtime/ship_runtime.tscn")
const AI_TEST := preload("res://game/ship/dev/ship_ai_test.tscn")
const MOVEMENT_TEST := preload("res://game/ship/dev/ship_movement_test.tscn")
const PROJECTILE := preload("res://game/ship/projectile/projectile_runtime.tscn")
const SAVE_PATH := "user://ships/test_ship.json"

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(1152, 648)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _design() -> ShipData:
	var ship := ShipData.new()
	ship.place(DATABASE.get_by_id(&"core_bridge"), Vector2i.ZERO, 0)
	ship.place(DATABASE.get_by_id(&"energy_smallreactor"), Vector2i(-1, 1), 0)
	ship.place(DATABASE.get_by_id(&"energy_smallreactor"), Vector2i(2, 1), 0)
	ship.place(DATABASE.get_by_id(&"propulsion_smallengine"), Vector2i(0, 2), 0)
	ship.place(DATABASE.get_by_id(&"propulsion_smallengine"), Vector2i(1, 2), 0)
	ship.place(DATABASE.get_by_id(&"weapon_cannon"), Vector2i(0, -1), 0)
	return ship

func _spawn(world: Node2D, location: Vector2, group: StringName = &"") -> ShipRuntime:
	var ship := RUNTIME.instantiate() as ShipRuntime
	world.add_child(ship)
	ship.position = location
	ship.weapon_target_group = &"unused_test_group"
	ship.setup(_design())
	if group != &"":
		ship.add_to_group(group)
	return ship

func _run() -> void:
	# Preserve any existing design even when this runner is launched outside an isolated user directory.
	var previous_save := FileAccess.get_file_as_bytes(SAVE_PATH) if FileAccess.file_exists(SAVE_PATH) else PackedByteArray()
	var had_save := FileAccess.file_exists(SAVE_PATH)
	await _test_ai_and_damage()
	await _test_projectile_range()
	if had_save:
		DirAccess.remove_absolute(SAVE_PATH)
	await _test_battle_scene()
	await _test_saved_design_and_editor()
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(previous_save)
		file.close()
	else:
		DirAccess.remove_absolute(SAVE_PATH)
	print("Ship regression: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _range_target(world: Node2D, location: Vector2, hp: float) -> ShipModuleRuntime:
	var module := ShipModuleInstance.new(1, DATABASE.get_by_id(&"function_radar"), Vector2i.ZERO)
	var target := ShipModuleRuntime.new()
	world.add_child(target)
	target.setup(module, location, Vector2(0.2, 2.0), hp)
	return target

func _range_projectile(world: Node2D, location: Vector2, shot_range: float) -> ProjectileRuntime:
	var projectile := PROJECTILE.instantiate() as ProjectileRuntime
	world.add_child(projectile)
	projectile.setup(location, Vector2.RIGHT, 20.0, null, shot_range)
	projectile.set_physics_process(false)
	return projectile

func _test_projectile_range() -> void:
	var world := Node2D.new()
	root.add_child(world)
	# A long step must clip collision queries, including the continuation after penetration.
	var inside := _range_target(world, Vector2(99.5, 0.0), 1.0)
	var outside := _range_target(world, Vector2(100.5, 0.0), 20.0)
	var projectile := _range_projectile(world, Vector2.ZERO, 100.0)
	await physics_frame
	await physics_frame
	projectile._physics_process(1.0)
	_check(inside.is_destroyed(), "A projectile must hit a collider just inside its attack range")
	_check(is_equal_approx(outside.get_hp(), 20.0), "Overkill must not hit a collider just outside attack range in the final step")
	_check(projectile.finished and projectile.global_position.is_equal_approx(Vector2(100.0, 0.0)), "A long final step must retire the projectile at exactly its range")
	await process_frame

	# Normal frames consume the same range; changing speed changes flight time only.
	projectile = _range_projectile(world, Vector2(0.0, 100.0), 500.0)
	projectile._physics_process(0.5)
	_check(not projectile.finished and projectile.global_position.is_equal_approx(Vector2(350.0, 100.0)), "A default shot must still fly before traveling 500 pixels")
	projectile.speed = 100.0
	projectile._physics_process(1.0)
	_check(not projectile.finished and projectile.global_position.is_equal_approx(Vector2(450.0, 100.0)), "Changing projectile speed must preserve its remaining range")
	projectile._physics_process(1.0)
	_check(projectile.finished and projectile.global_position.is_equal_approx(Vector2(500.0, 100.0)), "A slower shot must still retire after the same total distance")
	await process_frame

	# Reaching the per-step collision limit must preserve the untraveled range.
	var first := _range_target(world, Vector2(40.0, 200.0), 1.0)
	var beyond := _range_target(world, Vector2(110.0, 200.0), 20.0)
	projectile = _range_projectile(world, Vector2(0.0, 200.0), 100.0)
	projectile.max_impacts_per_step = 1
	await physics_frame
	await physics_frame
	projectile._physics_process(1.0)
	_check(first.is_destroyed() and not projectile.finished and projectile.distance_remaining > 60.0, "The impact limit must only consume distance actually traveled")
	await physics_frame
	await physics_frame
	projectile._physics_process(1.0)
	_check(projectile.finished and projectile.global_position.is_equal_approx(Vector2(100.0, 200.0)) and is_equal_approx(beyond.get_hp(), 20.0), "A penetration paused across frames must still finish at its range without hitting beyond it")
	await process_frame

	var owner := _spawn(world, Vector2(200.0, 300.0))
	owner.set_physics_process(false)
	var weapon := owner.weapon_runtime_by_uid.values()[0] as WeaponRuntime
	var weapon_definition := weapon.weapon_definition
	_check(
		weapon_definition != null
		and is_equal_approx(weapon_definition.attack_range, 500.0)
		and is_equal_approx(weapon_definition.fire_interval, 0.5)
		and is_equal_approx(weapon_definition.turn_speed_degrees, 180.0)
		and is_equal_approx(weapon_definition.projectile_speed, 700.0)
		and is_equal_approx(weapon_definition.fire_angle_tolerance_degrees, 6.0),
		"Weapon combat stats must come from generated weapon data"
	)
	_check(
		is_equal_approx(weapon.attack_range, weapon_definition.attack_range)
		and is_equal_approx(weapon.fire_interval, weapon_definition.fire_interval)
		and is_equal_approx(weapon.turn_speed_degrees, weapon_definition.turn_speed_degrees)
		and is_equal_approx(weapon.projectile_speed, weapon_definition.projectile_speed)
		and is_equal_approx(weapon.fire_angle_tolerance_degrees, weapon_definition.fire_angle_tolerance_degrees),
		"WeaponRuntime must load its own definition stats during setup"
	)
	weapon.set_physics_process(false)
	weapon.global_rotation = PI / 2.0
	weapon.attack_range = 1600.0
	var shots: Array[ProjectileRuntime] = []
	owner.projectile_spawned.connect(func(shot: ProjectileRuntime) -> void:
		shot.set_physics_process(false)
		shots.append(shot)
	)
	owner.request_fire()
	_check(
		shots.size() == 1
		and is_equal_approx(shots[0].max_distance, 1600.0)
		and is_equal_approx(shots[0].speed, 700.0),
		"ShipRuntime must pass the firing weapon's range and projectile speed into its projectile"
	)
	if not shots.is_empty():
		projectile = shots[0]
		var origin := projectile.global_position
		weapon.attack_range = 200.0
		weapon.projectile_speed = 350.0
		weapon.cooldown_remaining = 0.0
		owner.request_fire()
		_check(
			shots.size() == 2
			and is_equal_approx(shots[1].max_distance, 200.0)
			and is_equal_approx(shots[1].speed, 350.0)
			and is_equal_approx(projectile.max_distance, 1600.0)
			and is_equal_approx(projectile.speed, 700.0),
			"Each shot must snapshot its own range and speed without changing shots already in flight"
		)
		owner.position += Vector2(2000.0, 1000.0)
		owner.rotation = PI
		projectile._physics_process(2.01)
		_check(not projectile.finished and projectile.global_position.is_equal_approx(origin + Vector2(1407.0, 0.0)), "A long-range shot must survive beyond the old two-second lifetime and ignore source movement")
		owner.free()
		projectile._physics_process(1.0)
		_check(projectile.finished and projectile.global_position.is_equal_approx(origin + Vector2(1600.0, 0.0)), "Destroying the source must not change a projectile's independent flight or range")
	else:
		owner.free()
	await process_frame

	# Large world coordinates must not leave a tiny residual distance alive forever.
	projectile = _range_projectile(world, Vector2(100000.0, -100000.0), 500.0)
	for step in range(43):
		projectile._physics_process(1.0 / 60.0)
	_check(projectile.finished and projectile.global_position.distance_to(Vector2(100500.0, -100000.0)) < 0.1, "Default-range shots must retire at distant world coordinates without a residual-distance stall")
	await process_frame
	projectile = _range_projectile(world, Vector2.ZERO, 0.0)
	projectile._physics_process(1.0)
	_check(projectile.finished and projectile.global_position == Vector2.ZERO, "A zero-range projectile must retire without moving or dealing damage")
	await process_frame
	projectile = _range_projectile(world, Vector2.ZERO, 500.0)
	projectile.speed = 0.0
	projectile._physics_process(1.0)
	_check(projectile.finished, "A stationary projectile must retire rather than prevent battle resolution indefinitely")
	world.queue_free()
	await process_frame

func _test_ai_and_damage() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var enemy := _spawn(world, Vector2.ZERO)
	var player := _spawn(world, Vector2(500.0, 0.0), &"ai_test_targets")
	var farther := _spawn(world, Vector2(900.0, 0.0), &"ai_test_targets")
	var ai := AIShipController.new()
	ai.target_group = &"ai_test_targets"
	enemy.add_child(ai)
	ai.setup(enemy)
	var original_distance := enemy.position.distance_to(player.position)
	for frame in range(180):
		await physics_frame
	_check(ai.target == player, "AI must acquire the nearest living target")
	_check(enemy.position.distance_to(player.position) < original_distance - 10.0, "AI must turn and physically approach a target off its bow")

	ai.set_physics_process(false)
	enemy.position = Vector2.ZERO
	enemy.rotation = 0.0
	enemy.velocity = Vector2.ZERO
	player.position = Vector2(0.0, -100.0)
	ai._physics_process(1.0 / 60.0)
	_check(enemy.throttle_input < 0.0, "AI must reverse when a target is too close")
	player.position = Vector2(0.0, -220.0)
	ai._physics_process(1.0 / 60.0)
	_check(is_zero_approx(enemy.throttle_input), "AI must stop thrust inside its distance band")
	player.remove_from_group(&"ai_test_targets")
	ai._physics_process(1.0 / 60.0)
	_check(ai.target == farther, "AI must reacquire after a target leaves its group")
	farther.queue_free()
	ai._physics_process(1.0 / 60.0)
	_check(ai.target == null and is_zero_approx(enemy.throttle_input) and is_zero_approx(enemy.turn_input), "Queued target removal must clear stale controls")
	player.add_to_group(&"ai_test_targets")
	player.position = Vector2(0.0, -2000.0)
	ai._physics_process(1.0 / 60.0)
	_check(ai.target == null, "AI must respect acquisition range")
	player.position = Vector2(0.0, -500.0)
	ai._physics_process(1.0 / 60.0)
	_check(ai.target == player and enemy.throttle_input > 0.0, "AI must resume tracking when a target returns")

	var definition := DATABASE.get_by_id(&"function_radar").duplicate() as ShipModuleDefinition
	definition.hp = 37.0
	var isolated := enemy.ship_data.place(definition, Vector2i(9, 9), 0)
	enemy.setup(enemy.ship_data)
	_check(is_equal_approx(enemy.get_module_runtime(isolated).get_max_hp(), 37.0), "Module HP must come from its own definition")
	_check(enemy.ship_data.get_module_at(Vector2i(5, 5)) == null, "Sparse layouts must retain empty space")
	for module in enemy.ship_data.modules:
		if module.definition is PropulsionModuleDefinition:
			enemy.get_module_runtime(module).apply_damage(100.0)
	_check(is_zero_approx(enemy.get_effective_thrust()), "Destroyed engines must remove AI ship thrust")
	enemy.velocity = Vector2.ZERO
	enemy.set_control_input(1.0, 0.0)
	var position_before := enemy.position
	for frame in range(5):
		await physics_frame
	_check(enemy.position.is_equal_approx(position_before), "AI must not bypass destroyed propulsion")
	ai.setup(player)
	_check(is_zero_approx(enemy.throttle_input) and is_zero_approx(enemy.turn_input), "Rebinding AI must reset its old ship controls")
	ai.clear_target()
	_check(ai.runtime_ship == null and ai.target == null, "Clearing AI must release both references")
	world.queue_free()
	await process_frame

func _test_battle_scene() -> void:
	var battle = AI_TEST.instantiate()
	root.add_child(battle)
	_check(battle.player != null and battle.enemy != null, "AI scene must run on a clean checkout without a save")
	_check(battle.player.ship_data.is_design_valid(), "Fallback design must have valid core and power")
	for frame in range(900):
		await physics_frame
		if battle.player_hits > 0 and battle.enemy_hits > 0:
			break
	_check(battle.player_hits > 0 and battle.enemy_hits > 0, "Both ships must hit opposing modules in a real physics battle (player=%d enemy=%d)" % [battle.player_hits, battle.enemy_hits])
	if is_instance_valid(battle.player) and not battle.player.is_removed_from_battle():
		for module in battle.player.ship_data.modules:
			if module.definition is CoreModuleDefinition:
				battle.player.get_module_runtime(module).apply_damage(1000.0)
		_check(battle.battle_status == "玩家核心被摧毁", "Player core destruction must report the battle result")
		await process_frame
		_check(battle.get_node_or_null("Camera2D") != null, "Result camera must survive player removal")
		await physics_frame
		if is_instance_valid(battle.ai):
			_check(battle.ai.target == null, "Enemy AI must lose a destroyed player")
	battle.queue_free()
	await process_frame

func _test_saved_design_and_editor() -> void:
	_check(ShipSerializer.save_to_file(_design(), SAVE_PATH)["ok"], "Regression design must save")
	var movement = MOVEMENT_TEST.instantiate()
	root.add_child(movement)
	await process_frame
	_check(movement.get_node("CanvasLayer/Info").text.contains("ModuleDefinition.hp"), "Legacy movement HUD must use data-driven HP without the removed property")
	movement.queue_free()
	await process_frame
	var editor = load("res://game/ship/editor/ship_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene = editor
	await process_frame
	var launch_button: Button = editor.get_node("MainLayout/RightPanel/RightMargin/RightVBox/AITestButton")
	_check(launch_button.get_global_rect().end.y <= root.get_visible_rect().end.y, "Editor battle entry must fit inside the viewport")
	editor.get_node("MainLayout/RightPanel/RightMargin/RightVBox/AITestButton").pressed.emit()
	_check(current_scene == editor, "Editor must reject an empty design without leaving")
	_check(editor.speed_label.text.contains("预计最高速度：0.0 px/s"), "Empty design must show zero predicted speed")
	_check(root.get_visible_rect().encloses(editor.speed_label.get_global_rect()), "Predicted speed must be visible without scrolling")
	var editable_design := _design()
	editor.get_node("MainLayout/Center/Grid").set_ship(editable_design)
	var editor_grid := editor.grid as ShipGridView
	var installed_weapon := editable_design.get_module_at(Vector2i(0, -1))
	var installed_weapon_uid := installed_weapon.uid
	editor_grid.select_installed_module(installed_weapon)
	_check(
		editor.stats_label.text.contains("已选模块：机炮")
		and editor.stats_label.text.contains("射程：500.0")
		and editor.stats_label.text.contains("射击间隔：0.50 秒")
		and editor.stats_label.text.contains("弹速：700.0 px/s"),
		"Selecting an installed weapon must show its complete combat details"
	)
	editor_grid.begin_move_selected()
	_check(
		not editor_grid.move_selected_to(Vector2i.ZERO)
		and installed_weapon.grid_position == Vector2i(0, -1),
		"Moving an installed module onto an occupied cell must be rejected"
	)
	_check(
		editor_grid.move_selected_to(Vector2i(4, -1))
		and installed_weapon.uid == installed_weapon_uid
		and editable_design.get_module_at(Vector2i(0, -1)) == null
		and editable_design.get_module_at(Vector2i(4, -1)) == installed_weapon,
		"Moving an installed module must preserve its instance and rebuild occupancy"
	)
	editor_grid.rotate_selection_or_preview()
	_check(
		installed_weapon.rotation_quarters == 1
		and editor.stats_label.text.contains("旋转：90°"),
		"Rotating an installed module must update its stored rotation and detail view"
	)
	var move_button: Button = editor.get_node("MainLayout/RightPanel/RightMargin/RightVBox/MoveButton")
	_check(
		root.get_visible_rect().encloses(move_button.get_global_rect())
		and root.get_visible_rect().encloses(launch_button.get_global_rect()),
		"Installed-module editing controls and battle entry must remain visible in the default viewport"
	)
	var flight_world := Node2D.new()
	root.add_child(flight_world)
	var runtime := _spawn(flight_world, Vector2.ZERO)
	runtime.set_physics_process(false)
	runtime.set_control_input(1.0, 0.0)
	for step in range(600):
		runtime._physics_process(1.0 / float(Engine.physics_ticks_per_second))
	_check(is_equal_approx(runtime.get_speed(), runtime.get_max_speed()), "Forward thrust must stop at the explicit max speed")
	_check(editor.speed_label.text.contains("预计最高速度：%.1f px/s" % runtime.get_speed()), "Editor estimate must match the actual explicit max speed")
	var cruising_speed := runtime.get_speed()
	runtime.set_control_input(0.0, 0.0)
	runtime._physics_process(0.5)
	_check(runtime.get_speed() < cruising_speed, "Releasing throttle must decelerate using the independent deceleration rate")
	var heavy := _design()
	heavy.place(DATABASE.get_by_id(&"defense_lightarmor"), Vector2i(8, 8), 0)
	editor.grid.set_ship(heavy)
	_check(editor.speed_label.text.contains("预计最高速度：%.1f px/s" % runtime.estimate_design_top_speed(heavy)) and runtime.estimate_design_top_speed(heavy) < runtime.get_speed(), "Adding mass must immediately lower the editor's predicted speed")
	var underpowered := _design()
	underpowered.place(DATABASE.get_by_id(&"function_radar"), Vector2i(8, 8), 0)
	editor.grid.set_ship(underpowered)
	_check(editor.speed_label.text.contains("预计最高速度：—（供能不足）"), "Insufficient power must not present a misleading full-power speed")
	flight_world.queue_free()
	editor.grid.clear_ship()
	_check(editor.speed_label.text.contains("预计最高速度：0.0 px/s"), "Clearing the design must reset predicted speed")
	editor.grid.set_ship(_design())
	editor.get_node("MainLayout/RightPanel/RightMargin/RightVBox/AITestButton").pressed.emit()
	await scene_changed
	_check(current_scene.scene_file_path.ends_with("ship_ai_test.tscn"), "Valid editor design must enter AI test")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	current_scene._unhandled_key_input(event)
	await scene_changed
	_check(current_scene.scene_file_path.ends_with("ship_editor.tscn"), "Escape must return to the editor")
	_check(current_scene.get_node("MainLayout/Center/Grid").ship.modules.size() == _design().modules.size(), "Return to editor must restore the saved layout")
	current_scene.queue_free()
	current_scene = null
	await process_frame
