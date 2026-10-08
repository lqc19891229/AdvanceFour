extends SceneTree

const DATABASE := preload("res://data/modules/module_database.tres")
const HULL_APPEARANCE := preload("res://data/appearances/hull/human_basic.tres")
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
		ship.ensure_hull_for_equipment(definition, position, rotation)
		ship.place(definition, position, rotation)
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
	await _test_module_art_data()
	await _test_ai_and_damage()
	await _test_weapon_firing_arc()
	await _test_long_turret_geometry()
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

func _test_module_art_data() -> void:
	var module_ids := [
		&"energy_smallreactor",
		&"propulsion_smallengine",
		&"weapon_cannon",
		&"defense_lightarmor",
		&"function_radar",
		&"core_bridge"
	]
	for module_id in module_ids:
		var definition := DATABASE.get_by_id(module_id)
		_check(
			definition != null and ModuleArtLibrary.get_base_texture(definition) != null,
			"Every generated module definition must carry its Excel-driven base texture"
		)
		if definition is WeaponModuleDefinition:
			_check(
				ModuleArtLibrary.get_turret_texture(definition) != null,
				"Generated weapon definitions must carry their Excel-driven turret texture"
			)

	var world := Node2D.new()
	root.add_child(world)
	var runtime := _spawn(world, Vector2.ZERO)
	runtime.set_physics_process(false)
	_check(
		runtime.appearance_renderer != null
		and runtime.appearance_renderer.ship_data == runtime.ship_data,
		"Battle RuntimeShip must build an Appearance layer from the same ShipData"
	)
	_check(
		EquipmentAppearancePolicy.should_show(DATABASE.get_by_id(&"core_bridge"))
		and EquipmentAppearancePolicy.should_show(DATABASE.get_by_id(&"weapon_cannon"))
		and EquipmentAppearancePolicy.should_show(DATABASE.get_by_id(&"propulsion_smallengine"))
		and not EquipmentAppearancePolicy.should_show(DATABASE.get_by_id(&"energy_smallreactor"))
		and not EquipmentAppearancePolicy.should_show(DATABASE.get_by_id(&"defense_lightarmor"))
		and not EquipmentAppearancePolicy.should_show(DATABASE.get_by_id(&"function_radar")),
		"Battle appearance must expose Core, Weapon and Propulsion while hiding internal Equipment"
	)
	var core_instance := runtime.ship_data.get_module_at(Vector2i.ZERO)
	var core_runtime := runtime.get_module_runtime(core_instance)
	_check(
		core_runtime != null and core_runtime.visual != null and core_runtime.visual.texture != null,
		"Exposed Core Equipment must retain its generated Texture2D visual"
	)
	var energy_instance := runtime.ship_data.get_module_at(Vector2i(-1, 1))
	var energy_runtime := runtime.get_module_runtime(energy_instance)
	_check(
		energy_runtime != null and energy_runtime.visual == null,
		"Internal Energy Equipment must be hidden behind the Appearance shell in battle"
	)
	var propulsion_instance := runtime.ship_data.get_module_at(Vector2i(0, 2))
	var propulsion_runtime := runtime.get_module_runtime(propulsion_instance)
	_check(
		propulsion_runtime != null and propulsion_runtime.visual != null,
		"Propulsion must remain externally visible in the first Appearance pass"
	)
	var weapon_base_instance := runtime.ship_data.get_module_at(Vector2i(0, -1))
	var weapon_base_runtime := runtime.get_module_runtime(weapon_base_instance)
	_check(
		weapon_base_runtime != null
		and weapon_base_runtime.visual != null
		and weapon_base_runtime.z_index > runtime.appearance_renderer.z_index,
		"Weapon base must render above the hull Appearance shell"
	)
	var weapon := runtime.weapon_runtime_by_uid.values()[0] as WeaponRuntime
	_check(
		weapon != null
		and weapon.turret_visual != null
		and weapon.turret_visual.texture != null
		and weapon.z_index > weapon_base_runtime.z_index,
		"Weapon turret must keep its generated Texture2D visual above the Appearance shell and base"
	)

	var appearance_data := ShipData.new()
	appearance_data.add_hull_cell(Vector2i.ZERO)
	appearance_data.add_hull_cell(Vector2i.RIGHT)
	var appearance := ShipAppearanceRenderer.new()
	world.add_child(appearance)
	appearance.setup(appearance_data, 36.0, Vector2.ZERO)
	_check(
		HULL_APPEARANCE is HullAppearanceDefinition
		and HULL_APPEARANCE.is_valid()
		and HULL_APPEARANCE.tiles.size() == 16,
		"Default Hull appearance must provide all 16 adjacency textures"
	)
	_check(
		appearance.is_using_tile_appearance()
		and appearance.hull_sprites.size() == 2
		and appearance.get_neighbor_mask(Vector2i.ZERO) == 2
		and appearance.get_neighbor_mask(Vector2i.RIGHT) == 8
		and appearance.get_hull_texture_for_cell(Vector2i.ZERO) == HULL_APPEARANCE.get_tile(2)
		and appearance.get_hull_texture_for_cell(Vector2i.RIGHT) == HULL_APPEARANCE.get_tile(8)
		and appearance.is_exterior_cell(Vector2i.ZERO),
		"Appearance must select Hull textures from the four-direction adjacency mask"
	)
	var cross_data := ShipData.new()
	cross_data.add_hull_cell(Vector2i.ZERO)
	cross_data.add_hull_cell(Vector2i.UP)
	cross_data.add_hull_cell(Vector2i.RIGHT)
	cross_data.add_hull_cell(Vector2i.DOWN)
	cross_data.add_hull_cell(Vector2i.LEFT)
	var cross_appearance := ShipAppearanceRenderer.new()
	world.add_child(cross_appearance)
	cross_appearance.setup(cross_data, 36.0, Vector2.ZERO)
	_check(
		cross_appearance.get_neighbor_mask(Vector2i.ZERO) == 15
		and not cross_appearance.is_exterior_cell(Vector2i.ZERO)
		and cross_appearance.get_hull_texture_for_cell(Vector2i.ZERO) == HULL_APPEARANCE.get_tile(15),
		"A four-neighbor Hull cell must use tile 1111"
	)
	world.queue_free()
	await process_frame


func _test_long_turret_geometry() -> void:
	var world := Node2D.new()
	root.add_child(world)
	world.position = Vector2(150.0, 230.0)
	world.rotation = 0.4
	var definition := WeaponModuleDefinition.new()
	definition.size = Vector2i.ONE
	definition.turret_size_cells = Vector2(1.0, 2.0)
	definition.turret_pivot = Vector2(0.5, 0.25)
	definition.turret_muzzle = Vector2(0.5, 0.98)
	definition.turret_texture = ImageTexture.create_from_image(Image.create(128, 256, false, Image.FORMAT_RGBA8))
	var rect := ModuleArtLibrary.get_turret_draw_rect(definition, 32.0)
	_check(rect.size.is_equal_approx(Vector2(32, 64)), "A 2x1 height-first turret must retain a tall canvas above a 1x1 mount")
	_check(rect.position.is_equal_approx(Vector2(-16, -48)), "Bottom-left pivot coordinates must align the lower-quarter axle to the mount")
	_check(ModuleArtLibrary.get_turret_muzzle_offset(definition, 32).is_equal_approx(Vector2(0, -46.72)), "A high Y muzzle must lie above the mount with upward art")
	var weapon := WeaponRuntime.new()
	world.add_child(weapon)
	weapon.set_physics_process(false)
	var fired_positions: Array[Vector2] = []
	weapon.fired.connect(func(_module, _power, position, _direction): fired_positions.append(position))
	for quarters in range(4):
		var module := ShipModuleInstance.new(100 + quarters, definition, Vector2i.ZERO, quarters)
		weapon.setup(world, module, Vector2(30, -20))
		_check(module.get_cells().size() == 1, "Long turret art must not reserve extra placement cells")
		var pivot_in_pixels := Vector2(64, 192)
		_check(weapon.turret_visual.to_global(pivot_in_pixels).is_equal_approx(weapon.global_position), "Every rotation must keep the artwork axle fixed at the mount")
		var expected_muzzle := weapon.turret_visual.to_global(Vector2(64, 5.12))
		fired_positions.clear()
		weapon.fire_once()
		_check(fired_positions.size() == 1 and fired_positions[0].is_equal_approx(expected_muzzle), "Every rotation must spawn at the visible muzzle on a rotated owning ship")
	definition.size = Vector2i(2, 2)
	weapon.setup(world, ShipModuleInstance.new(200, definition, Vector2i.ZERO, 0), Vector2.ZERO, &"unused", 52.0)
	_check(weapon.turret_visual != null, "A larger base must still render its independent turret texture")
	_check((Vector2(definition.turret_texture.get_size()) * weapon.turret_visual.scale).is_equal_approx(Vector2(48, 96)), "Turret size must scale with the actual runtime cell size")
	var design := _design()
	var legacy := ShipSerializer.to_dictionary(design)
	legacy["version"] = 2
	for row in legacy["modules"]:
		if row["module_id"] == "weapon_cannon":
			row["rotation"] = 3
	var migrated := ShipSerializer.from_dictionary(legacy, DATABASE)
	_check(migrated["ok"] and migrated["ship"].get_module_at(Vector2i(0, -1)).rotation_quarters == 0, "A v2 upward cannon must preserve its world-facing direction when migrated to v3")
	var migrated_core := migrated["ship"].get_module_at(Vector2i.ZERO) as ShipModuleInstance
	_check(migrated_core.rotation_quarters == 0 and migrated_core.get_cells().size() == 4, "Old-save migration must preserve non-weapon orientation and occupied cells")
	var roundtrip := ShipSerializer.from_dictionary(ShipSerializer.to_dictionary(migrated["ship"]), DATABASE)
	_check(roundtrip["ok"] and roundtrip["ship"].get_module_at(Vector2i(0, -1)).rotation_quarters == 0, "Saving and loading v3 must not repeat the legacy weapon rotation conversion")
	var legacy_v1 := {"version": 1, "modules": legacy["modules"]}
	var migrated_v1 := ShipSerializer.from_dictionary(legacy_v1, DATABASE)
	_check(migrated_v1["ok"] and migrated_v1["ship"].get_module_at(Vector2i(0, -1)).rotation_quarters == 0, "The v1 Hull reconstruction must migrate upward weapon orientation too")
	world.queue_free()
	await process_frame

func _test_weapon_firing_arc() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var owner := Node2D.new()
	world.add_child(owner)
	owner.rotation = deg_to_rad(170.0)
	var weapon := WeaponRuntime.new()
	owner.add_child(weapon)
	weapon.set_physics_process(false)
	var definition := DATABASE.get_by_id(&"weapon_cannon") as WeaponModuleDefinition
	var shots: Array[Vector2] = []
	weapon.fired.connect(func(_module, _power, _position, direction): shots.append(direction))
	var target := Node2D.new()
	world.add_child(target)
	target.add_to_group(&"arc_test_targets")

	# Exercise all editor installation orientations with a rotated ship and real texture.
	var local_directions := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	for quarters in range(4):
		var module := ShipModuleInstance.new(quarters, definition, Vector2i.ZERO, quarters)
		weapon.setup(owner, module, Vector2.ZERO, &"arc_test_targets")
		var center := weapon.get_firing_arc_center_global_rotation()
		var expected_direction: Vector2 = local_directions[quarters].rotated(owner.rotation)
		_check(weapon.get_muzzle_world_direction().is_equal_approx(expected_direction), "Installation %d must point along the editor's visible muzzle" % quarters)
		for arc in [0.0, 60.0, 180.0, 270.0, 359.0, 360.0]:
			weapon.firing_arc_degrees = arc
			var half_arc := deg_to_rad(arc * 0.5)
			_check(weapon.is_world_direction_inside_firing_arc(expected_direction), "Installation %d / arc %.0f must contain its mounted muzzle direction" % [quarters, arc])
			_check(weapon.is_world_direction_inside_firing_arc(expected_direction.rotated(half_arc)) and weapon.is_world_direction_inside_firing_arc(expected_direction.rotated(-half_arc)), "Installation %d / arc %.0f must include both boundaries" % [quarters, arc])
			if arc < 360.0:
				_check(not weapon.is_world_direction_inside_firing_arc(expected_direction.rotated(half_arc + deg_to_rad(0.1))), "Installation %d / arc %.0f must reject angles just outside the boundary" % [quarters, arc])
		weapon.firing_arc_degrees = 180.0
		weapon.global_rotation = center + deg_to_rad(20.0)
		shots.clear()
		weapon.fire_once()
		var visual_direction := ModuleArtLibrary.WEAPON_FORWARD.rotated(weapon.turret_visual.global_rotation)
		_check(shots.size() == 1 and shots[0].is_equal_approx(visual_direction), "Installation %d must fire along the actual rotated turret texture" % quarters)
		_check(is_equal_approx(weapon.get_firing_arc_center_global_rotation(), center), "Aiming must not move the installation's fixed firing arc center")

	# A 270-degree mount must travel through its center, even across the world's +/- PI.
	weapon.firing_arc_degrees = 270.0
	weapon.turn_speed_degrees = 180.0
	var center := weapon.get_firing_arc_center_global_rotation()
	for sign_value in [-1.0, 1.0]:
		weapon.global_rotation = center + deg_to_rad(130.0 * sign_value)
		target.global_position = weapon.global_position + ModuleArtLibrary.WEAPON_FORWARD.rotated(center - deg_to_rad(130.0 * sign_value)) * 100.0
		weapon.target = target
		weapon._aim_at_target(0.05)
		var first_relative := wrapf(weapon.global_rotation - center, -PI, PI)
		_check(is_equal_approx(first_relative, deg_to_rad(121.0 * sign_value)), "Wide-arc turn must begin toward the allowed center, not the forbidden shortest path")
		var stayed_inside := true
		var respected_speed := true
		for step in range(40):
			var before := weapon.global_rotation
			weapon._aim_at_target(0.05)
			stayed_inside = stayed_inside and weapon.is_world_direction_inside_firing_arc(weapon.get_muzzle_world_direction())
			respected_speed = respected_speed and absf(wrapf(weapon.global_rotation - before, -PI, PI)) <= deg_to_rad(9.0) + 0.00001
		_check(stayed_inside and respected_speed and weapon._is_aimed_at_target(), "Both directions of a wide-arc turn must stay inside, respect speed and reach the target")

	weapon.firing_arc_degrees = 360.0
	weapon.global_rotation = center + deg_to_rad(175.0)
	target.global_position = weapon.global_position + ModuleArtLibrary.WEAPON_FORWARD.rotated(center - deg_to_rad(175.0)) * 100.0
	var before := weapon.global_rotation
	weapon._aim_at_target(0.05)
	_check(is_equal_approx(wrapf(weapon.global_rotation - before, -PI, PI), deg_to_rad(9.0)), "A full-circle turret must keep circular shortest-path turning")

	weapon.firing_arc_degrees = 0.0
	weapon.global_rotation = center
	target.global_position = weapon.global_position + ModuleArtLibrary.WEAPON_FORWARD.rotated(center + 0.5) * 100.0
	weapon._aim_at_target(1.0)
	_check(absf(wrapf(weapon.global_rotation - center, -PI, PI)) < 0.00001, "A zero-degree turret must remain locked to its installation")

	weapon.firing_arc_degrees = 180.0
	weapon.global_rotation = center + deg_to_rad(93.0)
	weapon.cooldown_remaining = 0.0
	shots.clear()
	weapon.fire_once()
	_check(shots.is_empty(), "Manual firing must reject a muzzle outside the mount arc")
	target.global_position = weapon.global_position + ModuleArtLibrary.WEAPON_FORWARD.rotated(center + deg_to_rad(89.0)) * 100.0
	weapon.target = target
	weapon._physics_process(0.0)
	_check(shots.size() == 1 and weapon.is_world_direction_inside_firing_arc(shots[0]), "Automatic firing must clamp an invalid muzzle before emitting a shot, even within the aiming tolerance")
	weapon._physics_process(0.0)
	_check(shots.size() == 1, "Automatic firing must obey the same cooldown as manual firing")
	weapon.cooldown_remaining = 0.0
	weapon.set_powered(false)
	weapon.fire_once()
	weapon._physics_process(1.0)
	_check(shots.size() == 1, "An unpowered turret must not emit manual or automatic shots")
	weapon.set_powered(true)
	weapon.global_rotation = center
	weapon.target = null
	target.global_position = weapon.global_position + ModuleArtLibrary.WEAPON_FORWARD.rotated(center + PI) * 100.0
	weapon._physics_process(1.0)
	_check(weapon.target == null and shots.size() == 1, "Targets outside the installation arc must not be selected or fired at")
	weapon.global_rotation = center + PI
	weapon._physics_process(0.0)
	_check(weapon.is_world_direction_inside_firing_arc(weapon.get_muzzle_world_direction()), "A turret with no valid target must still remain inside its mechanical range")
	world.queue_free()
	await process_frame

func _range_target(world: Node2D, location: Vector2, hp: float) -> HullCellRuntime:
	var data := ShipData.new()
	var cell := data.add_hull_cell(Vector2i.ZERO, &"test_hull", hp, 0.0, hp)
	var owner := ShipRuntime.new()
	world.add_child(owner)
	owner.setup(data)
	owner.set_physics_process(false)
	owner.position = location - Vector2(owner.cell_size * 0.5, owner.cell_size * 0.5)
	var target := owner.get_hull_runtime(cell)
	var shape := target.collision_shape.shape as RectangleShape2D
	shape.size = Vector2(0.2, 2.0)
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
		and is_equal_approx(weapon_definition.firing_arc_degrees, 180.0)
		and is_equal_approx(weapon_definition.fire_angle_tolerance_degrees, 6.0),
		"Weapon combat stats must come from generated weapon data"
	)
	_check(
		is_equal_approx(weapon.attack_range, weapon_definition.attack_range)
		and is_equal_approx(weapon.fire_interval, weapon_definition.fire_interval)
		and is_equal_approx(weapon.turn_speed_degrees, weapon_definition.turn_speed_degrees)
		and is_equal_approx(weapon.projectile_speed, weapon_definition.projectile_speed)
		and is_equal_approx(weapon.firing_arc_degrees, weapon_definition.firing_arc_degrees)
		and is_equal_approx(weapon.fire_angle_tolerance_degrees, weapon_definition.fire_angle_tolerance_degrees),
		"WeaponRuntime must load its own definition stats during setup"
	)
	weapon.set_physics_process(false)
	weapon.attack_range = 1600.0
	_check(
		weapon.is_world_direction_inside_firing_arc(Vector2.RIGHT)
		and weapon.is_world_direction_inside_firing_arc(Vector2.UP)
		and not weapon.is_world_direction_inside_firing_arc(Vector2.DOWN),
		"A zero-rotation turret must use the upward texture muzzle as its arc center"
	)
	owner.rotation = PI / 2.0
	_check(
		weapon.is_world_direction_inside_firing_arc(Vector2.RIGHT)
		and not weapon.is_world_direction_inside_firing_arc(Vector2.LEFT),
		"Weapon firing arc must rotate with the owning ship"
	)
	owner.rotation = 0.0
	var shots: Array[ProjectileRuntime] = []
	owner.projectile_spawned.connect(func(shot: ProjectileRuntime) -> void:
		shot.set_physics_process(false)
		shots.append(shot)
	)
	weapon.global_rotation = PI
	owner.request_fire()
	_check(
		shots.is_empty(),
		"Manual firing must not bypass the weapon firing arc"
	)
	weapon.global_rotation = 0.0
	owner.request_fire()
	_check(
		shots.size() == 1
		and is_equal_approx(shots[0].max_distance, 1600.0)
		and is_equal_approx(shots[0].speed, 700.0)
		and shots[0].direction.is_equal_approx(Vector2.UP),
		"ShipRuntime must preserve the muzzle direction, range and speed in the actual projectile"
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
		_check(not projectile.finished and projectile.global_position.is_equal_approx(origin + Vector2(0.0, -1407.0)), "A long-range shot must survive beyond the old two-second lifetime and ignore source movement")
		owner.free()
		projectile._physics_process(1.0)
		_check(projectile.finished and projectile.global_position.is_equal_approx(origin + Vector2(0.0, -1600.0)), "Destroying the source must not change a projectile's independent flight or range")
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

	var definition := DATABASE.get_by_id(&"function_radar")
	enemy.ship_data.add_hull_cell(Vector2i(9, 9), &"test_hull", 40.0, 2.0)
	var isolated := enemy.ship_data.place(definition, Vector2i(9, 9), 0)
	enemy.setup(enemy.ship_data)
	_check(is_equal_approx(enemy.get_module_efficiency(isolated), 1.0), "Equipment must start at full efficiency on intact Hull")
	enemy.apply_hull_projectile_damage(enemy.ship_data.get_hull_cell_at(Vector2i(9, 9)), 20.0)
	_check(is_equal_approx(enemy.get_module_efficiency(isolated), 0.5), "Equipment efficiency must follow the average health of its supporting Hull cells")
	_check(enemy.ship_data.get_hull_cell_at(Vector2i(5, 5)) == null, "Sparse Hull Layouts must retain empty space")
	for module in enemy.ship_data.modules:
		if module.definition is PropulsionModuleDefinition:
			for cell_position in module.get_cells():
				enemy.apply_hull_projectile_damage(enemy.ship_data.get_hull_cell_at(cell_position), 1000.0)
	_check(is_zero_approx(enemy.get_effective_thrust()), "Destroyed engine-supporting Hull must remove propulsion output")
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
				for cell_position in module.get_cells():
					battle.player.apply_hull_projectile_damage(
						battle.player.ship_data.get_hull_cell_at(cell_position),
						1000.0
					)
		_check(battle.battle_status == "玩家核心被摧毁", "Destroying all Core-supporting Hull must report the battle result")
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
	_check(movement.get_node("CanvasLayer/Info").text.contains("Hull"), "Movement HUD must report the new Hull-based durability model")
	movement.queue_free()
	await process_frame
	var editor = load("res://game/ship/editor/ship_editor.tscn").instantiate()
	root.add_child(editor)
	current_scene = editor
	await process_frame
	var launch_button: Button = editor.get_node("WorkSections/TopSection/MainLayout/RightPanel/RightMargin/RightVBox/AITestButton")
	_check(launch_button.get_global_rect().end.y <= root.get_visible_rect().end.y, "Editor battle entry must fit inside the viewport")
	editor.get_node("WorkSections/TopSection/MainLayout/RightPanel/RightMargin/RightVBox/AITestButton").pressed.emit()
	_check(current_scene == editor, "Editor must reject an empty design without leaving")
	_check(editor.speed_label.text.contains("预计最高速度：0.0 px/s"), "Empty design must show zero predicted speed")
	_check(root.get_visible_rect().encloses(editor.speed_label.get_global_rect()), "Predicted speed must be visible without scrolling")
	var editable_design := _design()
	editor.get_node("WorkSections/TopSection/MainLayout/Center/Grid").set_ship(editable_design)
	var editor_grid := editor.grid as ShipGridView
	# Mouse wheel zoom must preserve the grid cell beneath the cursor.
	var zoom_anchor := editor_grid.grid_to_screen(Vector2i(2, 3)) + Vector2.ONE * editor_grid.get_cell_size() * 0.5
	var anchor_cell := editor_grid.screen_to_grid(zoom_anchor)
	editor_grid.zoom_at(zoom_anchor, 1)
	_check(editor_grid.zoom > 1.0 and editor_grid.screen_to_grid(zoom_anchor) == anchor_cell, "Wheel up zooms in while preserving the hovered grid cell")
	editor_grid.zoom_at(zoom_anchor, -1)
	_check(is_equal_approx(editor_grid.zoom, 1.0) and editor_grid.screen_to_grid(zoom_anchor) == anchor_cell, "Wheel down restores zoom and hovered grid cell")
	for step in range(30):
		editor_grid.zoom_at(zoom_anchor, -1)
	_check(is_equal_approx(editor_grid.zoom, editor_grid.MIN_ZOOM), "Wheel zoom must respect minimum scale")
	for step in range(60):
		editor_grid.zoom_at(zoom_anchor, 1)
	_check(is_equal_approx(editor_grid.zoom, editor_grid.MAX_ZOOM), "Wheel zoom must respect maximum scale")
	editor_grid.center_view()
	_check(is_equal_approx(editor_grid.zoom, 1.0) and editor_grid.pan_offset == Vector2.ZERO, "Center view restores default zoom and pan")
	_check(editor_grid.GRID_HALF_EXTENT == 44, "Editor grid must contain 88 cells along each axis")
	editor_grid.pan_offset = Vector2(100000.0, -100000.0)
	editor_grid._clamp_pan_to_grid()
	var grid_half_size := float(editor_grid.GRID_HALF_EXTENT) * editor_grid.get_cell_size()
	var left_edge := editor_grid.grid_to_screen(Vector2i(-editor_grid.GRID_HALF_EXTENT, 0)).x
	var bottom_edge := editor_grid.grid_to_screen(Vector2i(0, editor_grid.GRID_HALF_EXTENT)).y
	_check(left_edge <= 0.01 and bottom_edge >= editor_grid.size.y - 0.01, "Editor camera cannot pan beyond 88x88 grid boundaries")
	editor_grid.center_view()
	var weapon_preview := editor_grid.get_preview_textures(DATABASE.get_by_id(&"weapon_cannon"))
	_check(
		weapon_preview["base"] != null and weapon_preview["turret"] != null,
		"Editor placement preview must expose both weapon base and turret textures"
	)
	var core_preview := editor_grid.get_preview_textures(DATABASE.get_by_id(&"core_bridge"))
	_check(
		core_preview["base"] != null and core_preview["turret"] == null,
		"Editor placement preview must expose the base texture for non-weapon modules"
	)
	editable_design.add_hull_cell(Vector2i(8, 8))
	_check(
		editable_design.can_place(DATABASE.get_by_id(&"function_radar"), Vector2i(8, 8), 0)["ok"]
		and not editable_design.can_place(DATABASE.get_by_id(&"function_radar"), Vector2i(9, 9), 0)["ok"],
		"Textured equipment preview must be valid on free Hull and invalid outside Hull Layout"
	)
	var installed_weapon := editable_design.get_module_at(Vector2i(0, -1))
	var installed_weapon_uid := installed_weapon.uid
	editor_grid.select_installed_module(installed_weapon)
	_check(
		editor.stats_label.text.contains("已选模块：机炮")
		and editor.stats_label.text.contains("射程：500.0")
		and editor.stats_label.text.contains("射击间隔：0.50 秒")
		and editor.stats_label.text.contains("弹速：700.0 px/s")
		and editor.stats_label.text.contains("射界：180.0°"),
		"Selecting an installed weapon must show its complete combat details"
	)
	editable_design.add_hull_cell(Vector2i(4, -1))
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
	var move_button: Button = editor.get_node("WorkSections/TopSection/MainLayout/RightPanel/RightMargin/RightVBox/MoveButton")
	_check(
		root.get_visible_rect().encloses(move_button.get_global_rect())
		and root.get_visible_rect().encloses(launch_button.get_global_rect()),
		"Installed-module editing controls and battle entry must remain visible in the default viewport"
	)
	editor.grid.set_ship(_design())
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
	var armored := _design()
	var armor_cell := armored.add_hull_cell(Vector2i(8, 8))
	var armor_definition := DATABASE.get_by_id(&"defense_lightarmor") as DefenseModuleDefinition
	armored.place(armor_definition, Vector2i(8, 8), 0)
	editor.grid.set_ship(armored)
	_check(
		is_equal_approx(armored.get_hull_cell_effective_max_hp(armor_cell), armor_cell.max_hp + armor_definition.hp),
		"Defense HP must add to the supporting Hull region HP"
	)
	_check(
		is_equal_approx(runtime.estimate_design_top_speed(armored), cruising_speed)
		and editor.speed_label.text.contains("预计最高速度：%.1f px/s" % cruising_speed),
		"Non-propulsion Equipment must not change thrust-only top speed"
	)
	var faster := _design()
	faster.add_hull_cell(Vector2i(8, 8))
	faster.place(DATABASE.get_by_id(&"propulsion_smallengine"), Vector2i(8, 8), 0)
	_check(
		runtime.estimate_design_top_speed(faster) > cruising_speed,
		"Adding propulsion thrust must increase predicted top speed"
	)
	var underpowered := _design()
	underpowered.add_hull_cell(Vector2i(8, 8))
	underpowered.place(DATABASE.get_by_id(&"function_radar"), Vector2i(8, 8), 0)
	editor.grid.set_ship(underpowered)
	_check(editor.speed_label.text.contains("预计最高速度：—（供能不足）"), "Insufficient power must not present a misleading full-power speed")
	flight_world.queue_free()
	editor.grid.clear_ship()
	_check(editor.speed_label.text.contains("预计最高速度：0.0 px/s"), "Clearing the design must reset predicted speed")
	editor.grid.set_ship(_design())
	editor.get_node("WorkSections/TopSection/MainLayout/RightPanel/RightMargin/RightVBox/AITestButton").pressed.emit()
	await scene_changed
	_check(current_scene.scene_file_path.ends_with("ship_ai_test.tscn"), "Valid editor design must enter AI test")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	current_scene._unhandled_key_input(event)
	await scene_changed
	_check(current_scene.scene_file_path.ends_with("ship_editor.tscn"), "Escape must return to the editor")
	_check(current_scene.get_node("WorkSections/TopSection/MainLayout/Center/Grid").ship.modules.size() == _design().modules.size(), "Return to editor must restore the saved layout")
	current_scene.queue_free()
	current_scene = null
	await process_frame
