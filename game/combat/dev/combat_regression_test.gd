extends SceneTree

const BATTLE_SCENE := preload("res://game/combat/battle.tscn")
const SAVE_PATH := "user://ships/test_ship.json"
const CONTENT := "UI/ResultOverlay/Center/Panel/Margin/Content/"

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
	battle.wave_enemy_counts = counts
	battle.preparation_seconds = 0.03
	battle.intermission_seconds = 0.03
	battle.spawn_interval_seconds = 0.12
	root.add_child(battle)
	if is_instance_valid(battle.player):
		_silence(battle.player)
	return battle

func _silence(ship: ShipRuntime) -> void:
	for weapon in ship.weapon_runtimes:
		weapon.set_physics_process(false)

func _core(ship: ShipRuntime) -> ShipModuleRuntime:
	for module in ship.module_runtimes:
		if module.module_instance.definition is CoreModuleDefinition:
			return module
	return null

func _kill(ship: ShipRuntime) -> void:
	_core(ship).apply_damage(1000.0)

func _run() -> void:
	var had_save := FileAccess.file_exists(SAVE_PATH)
	var previous := FileAccess.get_file_as_bytes(SAVE_PATH) if had_save else PackedByteArray()
	if had_save:
		DirAccess.remove_absolute(SAVE_PATH)
	await _test_waves_and_victory()
	await _test_late_projectile_and_failure()
	await _test_friendly_fire()
	await _test_errors()
	await _test_editor_roundtrip()
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else:
		DirAccess.remove_absolute(SAVE_PATH)
	print("Combat regression: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_waves_and_victory() -> void:
	var battle := _new_battle([1, 2])
	var outcomes: Array[bool] = []
	battle.finished.connect(func(value: bool): outcomes.append(value))
	_check(battle.phase == Battle.Phase.PREPARING and battle.enemies.is_empty(), "Battle must start in preparation with no enemies")
	_check(battle.player.ship_data.is_design_valid(), "No-save battle must load a valid fallback")
	_check(await _wait_until(func(): return battle.enemies.size() == 1), "First wave must spawn after the preparation timer")
	_silence(battle.enemies[0])
	_core(battle.player).apply_damage(1.0)
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
	_check(is_equal_approx(_core(battle.player).get_hp(), 19.0), "Player module damage must persist across waves")
	_check(battle.hud.text.contains("舰桥 HP") and battle.hud.text.contains("场上敌舰"), "HUD must expose local core HP and wave enemies")
	# A real emitted projectile lives after its firing ship is killed.
	var enemy := battle.enemies[0]
	var weapon := enemy.weapon_runtimes[0]
	weapon.global_position = Vector2(10000.0, 10000.0)
	weapon.global_rotation = 0.0
	enemy.request_fire()
	_kill(enemy)
	_check(await _wait_until(func(): return battle.phase == Battle.Phase.RESOLVING), "Final clearance must wait for projectiles")
	_check(outcomes.is_empty() and battle._has_live_projectiles(), "Live airborne shots must postpone victory")
	_check(await _wait_until(func(): return battle.phase == Battle.Phase.VICTORY, 180), "Victory must occur after projectiles finish and player survives")
	_check(outcomes == [true] and battle.defeated_enemies == 3, "Victory must emit exactly once with correct kill count")
	_check(battle.result_overlay.visible and battle.result_title.text == "战斗胜利", "Victory must show the result interface")
	var elapsed := battle.elapsed_seconds
	var position_before := battle.player.global_position
	battle.player.set_control_input(1.0, 1.0)
	for frame in range(5):
		await physics_frame
	_check(battle.elapsed_seconds == elapsed and battle.player.global_position == position_before, "Result state must freeze combat and timers")
	battle._finish_battle(false)
	_check(outcomes == [true] and battle.phase == Battle.Phase.VICTORY, "Settled victory must not be overwritten")
	await process_frame
	var panel: Control = battle.get_node("UI/ResultOverlay/Center/Panel")
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Result panel and its actions must fit in the viewport: viewport=%s panel=%s" % [root.get_visible_rect(), panel.get_global_rect()])
	battle.queue_free()
	await process_frame

func _test_late_projectile_and_failure() -> void:
	var battle := _new_battle([1])
	var outcomes: Array[bool] = []
	battle.finished.connect(func(value: bool): outcomes.append(value))
	await _wait_until(func(): return battle.enemies.size() == 1)
	var enemy := battle.enemies[0]
	_silence(enemy)
	_core(battle.player).apply_damage(16.0)
	var weapon := enemy.weapon_runtimes[0]
	# Avoid the player's forward weapon: this ray hits its exposed core directly.
	weapon.global_position = _core(battle.player).global_position + Vector2(18.0, -100.0)
	weapon.global_rotation = PI
	enemy.request_fire()
	_kill(enemy)
	_check(await _wait_until(func(): return battle.phase == Battle.Phase.DEFEAT), "Last enemy's airborne shot must still be able to defeat the player")
	_check(outcomes == [false], "Late player destruction must emit defeat, never premature victory")
	_check(battle.result_overlay.visible and battle.result_title.text == "战斗失败", "Player destruction must show defeat UI")
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
	var hp_before := _core(ally).get_hp()
	var weapon := shooter.weapon_runtimes[0]
	weapon.global_position = _core(ally).global_position + Vector2(18.0, -100.0)
	weapon.global_rotation = PI
	shooter.request_fire()
	for frame in range(20):
		await physics_frame
	_check(_core(ally).get_hp() == hp_before, "Enemy shots must pass through allied modules without friendly damage")
	weapon = battle.player.weapon_runtimes[0]
	weapon.global_position = _core(ally).global_position + Vector2(18.0, -100.0)
	weapon.global_rotation = PI
	battle.player.request_fire()
	_check(await _wait_until(func(): return _core(ally).get_hp() < hp_before), "Player shots must hit the same opposing module through battle masks")
	# Destroy both sides before resolution in one frame: failure takes precedence.
	_kill(shooter)
	_kill(ally)
	_kill(battle.player)
	_check(battle.phase == Battle.Phase.DEFEAT, "Simultaneous final clearance and player destruction must be defeat")
	battle.queue_free()
	await process_frame

func _test_errors() -> void:
	var invalid := _new_battle([])
	_check(invalid.phase == Battle.Phase.ERROR and invalid.result_overlay.visible, "Empty encounter configuration must show a recoverable error")
	invalid.queue_free()
	await process_frame
	ShipSerializer.save_to_file(ShipData.new(), SAVE_PATH)
	invalid = _new_battle([1])
	_check(invalid.phase == Battle.Phase.ERROR and invalid.player == null, "Invalid saved design must not silently use the fallback")
	invalid.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)

func _test_editor_roundtrip() -> void:
	var design := Battle.build_starter_design()
	var editor = load("res://game/ship/editor/ship_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene = editor
	await process_frame
	var launch: Button = editor.get_node("MainLayout/RightPanel/RightMargin/RightVBox/BattleButton")
	_check(root.get_visible_rect().encloses(launch.get_global_rect()), "Editor launch button must remain visible: viewport=%s button=%s" % [root.get_visible_rect(), launch.get_global_rect()])
	launch.pressed.emit()
	_check(current_scene == editor, "Invalid editor design must be rejected before saving or entering battle")
	editor.grid.set_ship(design)
	launch.pressed.emit()
	await scene_changed
	_check(current_scene is Battle, "Editor departure must enter the combat scene")
	var battle := current_scene as Battle
	_kill(battle.player)
	battle.get_node(CONTENT + "Retry").pressed.emit()
	await scene_changed
	_check(current_scene is Battle and current_scene.phase == Battle.Phase.PREPARING, "Result retry button must start a fresh encounter")
	_check(is_equal_approx(_core(current_scene.player).get_hp(), 20.0), "Retry must restore module HP from the saved design")
	_kill(current_scene.player)
	current_scene.get_node(CONTENT + "Return").pressed.emit()
	await scene_changed
	_check(current_scene.scene_file_path.ends_with("ship_editor.tscn"), "Result return button must reach the editor")
	_check(ShipSerializer.to_dictionary(current_scene.grid.ship) == ShipSerializer.to_dictionary(design), "Returning from defeat must preserve the exact saved layout")
	current_scene.queue_free()
	current_scene = null
	await process_frame
