extends SceneTree

const BATTLE_SCENE := preload("res://game/combat/battle.tscn")
const SAVE_PATH := "user://ships/test_ship.json"
const CUSTOM_BATTLE_DEFINITION_PATH := "res://game/combat/dev/custom_battle_definition.tres"
const INVALID_BATTLE_DEFINITION_PATH := "res://game/combat/dev/missing_battle_definition.tres"
const TEST_ENEMY := preload("res://data/enemies/scout.tres")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	# Script-mode headless windows default to 64x64; use a real game viewport for UI checks.
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(1152, 648)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _wait_until(predicate: Callable, frames := 120) -> bool:
	for frame in range(frames):
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()

func _new_battle(counts: Array[int]) -> Battle:
	var battle := BATTLE_SCENE.instantiate() as Battle
	var definition := BattleDefinition.new()
	definition.battle_id = &"regression_test"
	definition.display_name = "战斗回归测试"
	for count in counts:
		var wave = BattleWaveDefinition.new()
		wave.enemies.append(TEST_ENEMY)
		wave.counts.append(count)
		wave.spawn_interval_seconds = 0.12
		definition.waves.append(wave)
	definition.preparation_seconds = 0.03
	definition.intermission_seconds = 0.03
	definition.spawn_interval_seconds = 0.12
	battle.battle_definition = definition
	root.add_child(battle)
	# State-machine and mask fixtures issue their own shots; silence spawned AI weapons
	# before their first physics tick, including while a multi-enemy wave is queued.
	battle.world.child_entered_tree.connect(func(node: Node):
		if node is ShipRuntime:
			_silence.call_deferred(node)
	)
	if is_instance_valid(battle.player):
		_silence(battle.player)
	return battle

func _silence(ship: Node) -> void:
	if ship is ShipRuntime:
		for weapon in ship.weapon_runtimes:
			weapon.set_physics_process(false)

func _core_module(ship: ShipRuntime) -> ShipModuleInstance:
	for module in ship.ship_data.modules:
		if module.definition is CoreModuleDefinition:
			return module
	return null

func _core_cells(ship: ShipRuntime) -> Array[ShipHullCell]:
	var result: Array[ShipHullCell] = []
	var core := _core_module(ship)
	if core == null:
		return result
	for position in core.get_cells():
		var cell := ship.ship_data.get_hull_cell_at(position)
		if cell != null:
			result.append(cell)
	return result

func _core_cell(ship: ShipRuntime) -> ShipHullCell:
	var cells := _core_cells(ship)
	return null if cells.is_empty() else cells[0]

func _core_runtime(ship: ShipRuntime) -> HullCellRuntime:
	var cell := _core_cell(ship)
	return null if cell == null else ship.get_hull_runtime(cell)

func _kill(ship: Node) -> void:
	if ship is ShipRuntime:
		for cell in _core_cells(ship):
			if is_instance_valid(ship):
				ship.apply_hull_projectile_damage(cell, 1000.0)

func _run() -> void:
	var had_save := FileAccess.file_exists(SAVE_PATH)
	var previous := FileAccess.get_file_as_bytes(SAVE_PATH) if had_save else PackedByteArray()
	if had_save:
		DirAccess.remove_absolute(SAVE_PATH)
	await _test_movement_feedback()
	await _test_waves_and_victory()
	await _test_late_projectile_and_failure()
	await _test_friendly_fire()
	await _test_errors()
	await _test_custom_definition()
	await _test_direct_victory_settlement()
	await _test_editor_roundtrip()
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else:
		DirAccess.remove_absolute(SAVE_PATH)
	print("Combat regression: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _test_movement_feedback() -> void:
	var battle := _new_battle([1])
	battle.countdown = 60.0
	await process_frame
	await process_frame
	var backdrop := battle.get_node("World/Backdrop") as Node2D
	var landmark := Node2D.new()
	landmark.position = Vector2(200.0, 200.0)
	backdrop.add_child(landmark)
	var world_before := landmark.global_position
	var screen_before := landmark.get_global_transform_with_canvas().origin
	var ship_before := battle.player.global_position
	_key(KEY_W, true)
	for frame in range(90):
		await physics_frame
	_key(KEY_W, false)
	await process_frame
	await process_frame
	_check(battle.player.global_position.y < ship_before.y - 5.0 and battle.player.get_speed() > 0.0, "Real W input must propel the player's powered ship forward")
	_check(landmark.global_position == world_before, "Backdrop landmarks must remain anchored in the world")
	_check(landmark.get_global_transform_with_canvas().origin.distance_to(screen_before) > 5.0, "Following camera must make world landmarks visibly scroll when the ship moves")
	_check(battle.camera.global_position.distance_to(battle.player.global_position) < 1.0, "Movement feedback must preserve the following camera")
	# Battle wheel zoom retains the player-follow camera and stays within safe limits.
	battle.adjust_camera_zoom(1)
	_check(battle.camera.zoom.x > 1.0 and is_equal_approx(battle.camera.zoom.x, battle.camera.zoom.y), "Battle wheel up zooms in uniformly")
	battle.adjust_camera_zoom(-1)
	_check(is_equal_approx(battle.camera.zoom.x, 1.0), "Battle wheel down returns to default scale")
	for i in range(30):
		battle.adjust_camera_zoom(-1)
	_check(is_equal_approx(battle.camera.zoom.x, battle.MIN_CAMERA_ZOOM), "Battle camera zoom has a minimum limit")
	for i in range(60):
		battle.adjust_camera_zoom(1)
	_check(is_equal_approx(battle.camera.zoom.x, battle.MAX_CAMERA_ZOOM), "Battle camera zoom has a maximum limit")

	_check(battle.hud.text.contains("速度：%.1f px/s" % battle.player.get_speed()) and battle.hud.text.contains("坐标："), "HUD must report live movement telemetry")
	# Isolate reverse-input semantics from the new acceleration/braking model.
	battle.player.velocity = Vector2.ZERO
	_key(KEY_S, true)
	for frame in range(90):
		await physics_frame
	_key(KEY_S, false)
	_check(battle.player.velocity.y > 0.0, "Real S input must reverse thrust along the ship's heading")
	var heading_before := battle.player.rotation
	_key(KEY_D, true)
	for frame in range(15):
		await physics_frame
	_key(KEY_D, false)
	_check(battle.player.rotation > heading_before, "Real D input must turn the player's ship")
	await process_frame
	var hud_panel: Control = battle.get_node("UI/HUD")
	_check(root.get_visible_rect().encloses(hud_panel.get_global_rect()), "Movement telemetry and controls must fit in the game viewport")
	battle.queue_free()
	await process_frame

func _test_waves_and_victory() -> void:
	var battle := _new_battle([1, 2])
	var outcomes: Array[bool] = []
	battle.finished.connect(func(value: bool): outcomes.append(value))
	_check(battle.phase == Battle.Phase.PREPARING and battle.enemies.is_empty(), "Battle must start in preparation with no enemies")
	_check(battle.player.ship_data.is_design_valid(), "No-save battle must load a valid fallback")
	_check(await _wait_until(func(): return battle.enemies.size() == 1), "First wave must spawn after the preparation timer")
	_silence(battle.enemies[0])
	_check(battle.enemies[0].ship_data.is_design_valid() and battle.enemies[0].get_weapon_count() > 0, "Enemies must spawn as valid modular ShipData designs")
	battle.player.apply_hull_projectile_damage(_core_cell(battle.player), 1.0)
	_kill(battle.enemies[0])
	_check(await _wait_until(func(): return battle.phase == Battle.Phase.INTERMISSION), "Cleared early wave must enter intermission")
	_check(outcomes.is_empty() and battle.defeated_enemies == 1, "Intermediate clearance must not award victory")
	_check(await _wait_until(func(): return battle.wave_index == 1), "Intermission timer must start the next wave")
	_silence(battle.enemies[0])
	_kill(battle.enemies[0])
	await physics_frame
	_check(battle.phase == Battle.Phase.FIGHTING and battle.spawned_in_wave == 1, "Queued enemies must prevent early wave completion")
	_check(await _wait_until(func(): return battle.spawned_in_wave == 2), "Remaining enemy must spawn on schedule")
	_silence(battle.enemies[0])
	_check(is_equal_approx(_core_cell(battle.player).current_hp, 19.0), "Local Hull damage must persist across waves")
	_check(battle.hud.text.contains("Hull HP") and battle.hud.text.contains("场上敌舰"), "HUD must expose Hull durability and wave enemies")
	# A real emitted projectile lives after its firing ship is killed.
	var enemy := battle.enemies[0]
	var weapon := enemy.weapon_runtimes[0]
	enemy.rotation = 0.0
	weapon.global_position = Vector2(10000.0, 10000.0)
	weapon.global_rotation = Vector2.UP.angle_to(Vector2.UP)
	weapon.fire_once()
	_kill(enemy)
	_check(await _wait_until(func(): return battle.phase == Battle.Phase.RESOLVING), "Final clearance must wait for projectiles")
	_check(outcomes.is_empty() and battle._has_live_projectiles(), "Live airborne shots must postpone victory")
	_check(await _wait_until(func(): return battle.phase == Battle.Phase.VICTORY, 180), "Victory must occur after projectiles finish and player survives")
	_check(outcomes == [true] and battle.defeated_enemies == 3, "Victory must emit exactly once with correct kill count")
	_check(not battle.has_node("UI/ResultOverlay") and battle.pending_result.is_victory(), "Victory must generate a result without the deleted intermediate interface")
	var elapsed := battle.elapsed_seconds
	var position_before := battle.player.global_position
	battle.player.set_control_input(1.0, 1.0)
	for frame in range(5):
		await physics_frame
	_check(battle.elapsed_seconds == elapsed and battle.player.global_position == position_before, "Result state must freeze combat and timers")
	battle._finish_battle(false)
	_check(outcomes == [true] and battle.phase == Battle.Phase.VICTORY, "Settled victory must not be overwritten")
	_check(battle.pending_result.enemies_destroyed == 3 and battle.pending_result.waves_reached == 2 and battle.pending_result.total_waves == 2, "Battle statistics must survive in BattleResult for the common settlement")
	battle.queue_free()
	await process_frame

func _test_late_projectile_and_failure() -> void:
	var battle := _new_battle([1])
	var outcomes: Array[bool] = []
	battle.finished.connect(func(value: bool): outcomes.append(value))
	await _wait_until(func(): return battle.enemies.size() == 1)
	var enemy := battle.enemies[0]
	_silence(enemy)
	var player_core_cells := _core_cells(battle.player)
	for index in range(player_core_cells.size() - 1):
		battle.player.apply_hull_projectile_damage(player_core_cells[index], 1000.0)
	var final_core_cell := player_core_cells[player_core_cells.size() - 1]
	battle.player.apply_hull_projectile_damage(final_core_cell, 16.0)
	var final_core_runtime := battle.player.get_hull_runtime(final_core_cell)
	var weapon := enemy.weapon_runtimes[0]
	# The last airborne shot destroys the final surviving Core-supporting Hull cell.
	weapon.global_position = final_core_runtime.global_position + Vector2(0.0, -100.0)
	weapon.global_rotation = Vector2.UP.angle_to(Vector2.DOWN)
	weapon.fire_once()
	_kill(enemy)
	_check(await _wait_until(func(): return battle.phase == Battle.Phase.DEFEAT), "Last enemy's airborne shot must still be able to defeat the player")
	_check(outcomes == [false], "Late player destruction must emit defeat, never premature victory")
	_check(not battle.has_node("UI/ResultOverlay") and not root.get_node("RunState").run_active and root.get_node("RunState").last_result == battle.pending_result, "Player destruction must end the Run immediately and retain only the Game Over result")
	for frame in range(15):
		await physics_frame
	_check(battle.spawned_in_wave == 1 and outcomes == [false], "Defeat must stop spawning and remain stable")
	_check(is_instance_valid(battle.camera), "Camera must survive removal of the player")
	battle.queue_free()
	await process_frame

func _test_friendly_fire() -> void:
	var battle := _new_battle([2])
	await _wait_until(func(): return battle.enemies.size() == 2)
	var shooter := battle.enemies[0]
	var ally := battle.enemies[1]
	_silence(shooter)
	_silence(ally)
	# This checks collision masks, independently of the ally's moving AI and cell seams.
	ally.set_physics_process(false)
	await physics_frame
	var hp_before := ally.get_current_hull_hp()
	var weapon := shooter.weapon_runtimes[0]
	shooter.rotation = PI
	weapon.global_position = ally.global_position + Vector2(0.0, -100.0)
	weapon.global_rotation = Vector2.UP.angle_to(Vector2.DOWN)
	weapon.fire_once()
	for frame in range(20):
		await physics_frame
	_check(ally.get_current_hull_hp() == hp_before, "Enemy shots must pass through allied Hull without friendly damage")
	weapon = battle.player.weapon_runtimes[0]
	battle.player.rotation = PI
	weapon.global_position = ally.global_position + Vector2(0.0, -100.0)
	weapon.global_rotation = ModuleArtLibrary.WEAPON_FORWARD.angle_to(Vector2.DOWN)
	weapon.fire_once()
	_check(await _wait_until(func(): return ally.get_current_hull_hp() < hp_before), "Player shots must hit the same opposing Hull through battle masks")
	# Destroy both sides before resolution in one frame: failure takes precedence.
	_kill(shooter)
	_kill(ally)
	_kill(battle.player)
	_check(battle.phase == Battle.Phase.DEFEAT, "Simultaneous final clearance and player destruction must be defeat")
	battle.queue_free()
	await process_frame

func _test_errors() -> void:
	var invalid := _new_battle([])
	_check(invalid.phase == Battle.Phase.ERROR and invalid.hud.text.contains("无法开始战斗"), "Empty encounter configuration must show a recoverable error")
	invalid.queue_free()
	await process_frame

	set_meta(Battle.BATTLE_DEFINITION_META, INVALID_BATTLE_DEFINITION_PATH)
	invalid = BATTLE_SCENE.instantiate() as Battle
	root.add_child(invalid)
	_check(invalid.phase == Battle.Phase.ERROR, "Explicit invalid battle definition path must enter ERROR")
	_check(invalid.hud.text.contains("战斗配置不存在"), "Invalid battle definition path must report the configuration error")
	_check(invalid.battle_definition == null or invalid.battle_definition.battle_id != &"stage_001", "Explicit invalid battle definition path must never fall back to stage_001")
	invalid.queue_free()
	await process_frame

	ShipSerializer.save_to_file(ShipData.new(), SAVE_PATH)
	invalid = _new_battle([1])
	_check(invalid.phase == Battle.Phase.ERROR and invalid.player == null, "Invalid saved design must not silently use the fallback")
	invalid.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)

func _test_custom_definition() -> void:
	var design := Battle.build_starter_design()
	var saved := ShipSerializer.save_to_file(design, SAVE_PATH)
	_check(saved["ok"], "Custom battle test must save a valid player design")
	set_meta(Battle.BATTLE_DEFINITION_META, CUSTOM_BATTLE_DEFINITION_PATH)
	change_scene_to_file("res://game/combat/battle.tscn")
	await scene_changed
	var battle := current_scene as Battle
	_check(battle != null and battle.battle_definition.battle_id == &"regression_custom", "Battle must load the explicitly selected custom definition")
	_check(battle.battle_definition.display_name == "自定义回归关卡", "Custom battle display name must come from the selected definition")
	_check(battle.battle_definition.get_wave_count() == 1 and battle.battle_definition.get_wave(0).get_total_enemy_count() == 2, "Custom battle wave data must come from the selected definition")
	_check(battle.battle_definition.get_wave(0).get_enemy_for_spawn_index(0).enemy_id == &"scout", "Custom battle wave must preserve its enemy blueprint")
	_check(is_equal_approx(battle.battle_definition.spawn_radius, 333.0), "Custom battle spawn radius must come from the selected definition")

	_key(KEY_R, true)
	await process_frame
	_key(KEY_R, false)
	_check(current_scene == battle and not battle.has_method("retry"), "R must no longer restart the encounter")

	battle._finish_battle(true)
	await scene_changed
	var run_state := root.get_node("RunState")
	_check(current_scene.scene_file_path.ends_with("battle_result_screen.tscn") and run_state.last_result.battle_id == &"regression_custom", "An F6 encounter without an active Run must also enter the common settlement")
	current_scene.queue_free()
	current_scene = null
	await process_frame
	run_state.reset_run()
	DirAccess.remove_absolute(SAVE_PATH)

func _test_editor_roundtrip() -> void:
	var run_state := root.get_node("RunState")
	run_state.reset_run()
	var design := Battle.build_starter_design()
	var editor = load("res://game/ship/editor/ship_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene = editor
	await process_frame
	var launch: Button = editor.get_node("WorkSections/Header/ReturnButton")
	_check(root.get_visible_rect().encloses(launch.get_global_rect()), "Editor save/return button must remain visible")
	# A valid saved design should create the test route on return.
	editor.grid.set_ship(design)
	launch.pressed.emit()
	await scene_changed
	_check(current_scene.scene_file_path.ends_with("route_map_screen.tscn"), "Editor must return to the map rather than launch combat")
	_check(run_state.is_route_active() and (run_state.get_current_route_node() as RunRouteNodeDefinition).node_type == RunRouteNodeDefinition.NodeType.SHOP, "Map must initialize shop-first test route without editor combat entry")
	_check(ShipSerializer.to_dictionary(run_state.current_ship) == ShipSerializer.to_dictionary(design), "Test map must load the saved design")
	# During an active Run, an unfinished design must be saved and returned without
	# accidentally allowing the player to enter combat.
	set_meta(&"run_refit_mode", true)
	change_scene_to_file("res://game/ship/editor/ship_editor.tscn")
	await scene_changed
	var refit_editor := current_scene as Control
	var unfinished := ShipData.new()
	(refit_editor.get_node("WorkSections/TopSection/MainLayout/Center/Grid") as ShipGridView).set_ship(unfinished)
	(refit_editor.get_node("WorkSections/Header/ReturnButton") as Button).pressed.emit()
	await scene_changed
	_check(current_scene.scene_file_path.ends_with("route_map_screen.tscn"), "Incomplete Run design must still return to the map")
	_check(not run_state.current_ship.is_design_valid(), "Returning to map must preserve unfinished Run design")
	current_scene.queue_free()
	current_scene = null
	await process_frame
	run_state.reset_run()

func _test_direct_victory_settlement() -> void:
	var run_state := root.get_node("RunState")
	var design := Battle.build_starter_design()
	_check(run_state.start_run_with_route(design, "res://data/routes/prototype_route.tres"), "Direct victory settlement test must start a route")
	set_meta(Battle.BATTLE_DEFINITION_META, "res://data/battles/stage_001/battle.tres")
	change_scene_to_file("res://game/combat/battle.tscn")
	await scene_changed
	var battle := current_scene as Battle
	battle.wave_index = 2
	battle.defeated_enemies = 6
	battle.elapsed_seconds = 28.3
	_core_cell(battle.player).current_hp = 8.0
	_check(not battle.has_node("UI/ResultOverlay"), "The old result popup must be deleted from the battle scene")
	var outcomes: Array[bool] = []
	battle.finished.connect(func(value: bool): outcomes.append(value))
	battle._finish_battle(true)
	battle._finish_battle(true)
	var result := battle.pending_result
	await scene_changed
	_check(current_scene.scene_file_path.ends_with("battle_result_screen.tscn"), "Victory must automatically open the unified settlement without an extra click")
	_check(outcomes == [true] and run_state.last_result == result and run_state.completed_route_nodes.size() == 1, "Automatic victory must complete the route node exactly once")
	_check(run_state.energy_crystals == 1100 and run_state.parts == 1012 and run_state.has_pending_loot(), "Automatic settlement must grant currencies once and leave module loot pending")
	_check(is_equal_approx(_core_cell_from_data(run_state.current_ship).current_hp, 8.0), "Automatic settlement must retain battle damage")
	var summary := current_scene.get_node("%Summary") as Label
	_check(summary.text.contains("第一战") and summary.text.contains("击毁敌舰：6") and summary.text.contains("3 / 3") and summary.text.contains("28.3 秒"), "The unified settlement must display the statistics from the deleted popup")
	_check((current_scene.get_node("%NextBattle") as Button).disabled, "Automatic settlement must still require processing every loot item before route continuation")
	current_scene.queue_free()
	current_scene = null
	await process_frame
	run_state.reset_run()

func _core_cell_from_data(ship: ShipData) -> ShipHullCell:
	for module in ship.modules:
		if module.definition is CoreModuleDefinition:
			return ship.get_hull_cell_at(module.get_cells()[0])
	return null
