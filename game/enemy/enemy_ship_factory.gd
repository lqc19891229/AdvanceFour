class_name EnemyShipFactory
extends RefCounted

const DATABASE: ModuleDatabase = preload("res://data/modules/module_database.tres")

static func create_design(definition: EnemyShipDefinition) -> ShipData:
	if definition == null:
		return null
	if not definition.ship_template_path.is_empty():
		var loaded := ShipSerializer.load_from_file(definition.ship_template_path, DATABASE)
		if not loaded["ok"]:
			push_error("Enemy ship template: " + String(loaded["error"]))
			return null
		var saved := loaded["ship"] as ShipData
		return saved if saved != null and saved.is_design_valid() else null

	var placements: Array
	match definition.enemy_id:
		&"scout":
			placements = [
				[&"core_bridge", Vector2i.ZERO, 0],
				[&"energy_smallreactor", Vector2i(-1, 1), 0],
				[&"propulsion_smallengine", Vector2i(1, 1), 0],
				[&"weapon_cannon", Vector2i(0, -1), 0]
			]
		&"gunship":
			placements = [
				[&"core_bridge", Vector2i.ZERO, 0],
				[&"energy_smallreactor", Vector2i(-1, 1), 0],
				[&"energy_smallreactor", Vector2i(2, 1), 0],
				[&"propulsion_smallengine", Vector2i(0, 2), 0],
				[&"defense_lightarmor", Vector2i(1, 2), 0],
				[&"weapon_cannon", Vector2i(-1, -1), 0],
				[&"weapon_cannon", Vector2i(2, -1), 0]
			]
		_:
			push_error("Enemy has no modular design: " + String(definition.enemy_id))
			return null

	var ship := ShipData.new()
	for placement in placements:
		var module_def := DATABASE.get_by_id(placement[0])
		if module_def == null:
			push_error("Enemy module not found: " + String(placement[0]))
			return null
		var position: Vector2i = placement[1]
		var rotation: int = placement[2]
		ship.ensure_hull_for_equipment(module_def, position, rotation)
		var result := ship.can_place(module_def, position, rotation)
		if not result["ok"]:
			push_error("Enemy module placement failed: " + String(result["reason"]))
			return null
		ship.place(module_def, position, rotation)
	return ship if ship.is_design_valid() else null
