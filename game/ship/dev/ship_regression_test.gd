extends SceneTree

const DATABASE := preload("res://data/generated/module_database.tres")
const RUNTIME := preload("res://game/ship/runtime/ship_runtime.tscn")
const AI_TEST := preload("res://game/ship/dev/ship_ai_test.tscn")
const MOVEMENT_TEST := preload("res://game/ship/dev/ship_movement_test.tscn")
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
	editor.get_node("MainLayout/Center/Grid").set_ship(_design())
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
