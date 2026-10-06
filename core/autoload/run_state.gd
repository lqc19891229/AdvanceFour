extends Node

const DATABASE := preload("res://data/modules/module_database.tres")
const REPAIR_COST_PER_HP := 1.0

var run_active := false
var current_ship: ShipData
var battle_entry_ship: ShipData
var current_battle_path := ""
var currency := 0
var module_inventory: Dictionary = {}
var hull_stock := 0
var completed_battles: Array[StringName] = []
var last_result: BattleResult

func reset_run() -> void:
	run_active = false
	current_ship = null
	battle_entry_ship = null
	current_battle_path = ""
	currency = 0
	module_inventory.clear()
	hull_stock = 0
	completed_battles.clear()
	last_result = null

func start_run(ship: ShipData, first_battle_path: String) -> bool:
	if ship == null or not ship.is_design_valid() or first_battle_path.is_empty():
		return false
	var copy := _clone_ship(ship)
	if copy == null:
		return false
	reset_run()
	run_active = true
	current_ship = copy
	current_battle_path = first_battle_path
	return true

func get_ship_for_battle(battle_path: String) -> ShipData:
	if not run_active or current_ship == null:
		return null
	if battle_entry_ship == null or current_battle_path != battle_path:
		current_battle_path = battle_path
		battle_entry_ship = _clone_ship(current_ship)
	return _clone_ship(battle_entry_ship)

func update_current_ship(ship: ShipData) -> bool:
	if not run_active or ship == null or not ship.is_design_valid():
		return false
	var copy := _clone_ship(ship)
	if copy == null:
		return false
	current_ship = copy
	return true

func commit_victory(result: BattleResult) -> bool:
	if not run_active or result == null or not result.is_victory() or result.ship_after_battle == null:
		return false
	if result.battle_id != &"" and completed_battles.has(result.battle_id):
		return false
	var copy := _clone_ship(result.ship_after_battle)
	if copy == null:
		return false
	current_ship = copy
	currency += maxi(result.reward_credits, 0)
	hull_stock += maxi(result.reward_hull_cells, 0)
	for index in range(result.reward_module_ids.size()):
		var module_id := result.reward_module_ids[index]
		var count := 1
		if index < result.reward_module_counts.size():
			count = maxi(result.reward_module_counts[index], 0)
		add_module_to_inventory(module_id, count)
	if result.battle_id != &"" and not completed_battles.has(result.battle_id):
		completed_battles.append(result.battle_id)
	last_result = result
	battle_entry_ship = null
	return true

func record_defeat(result: BattleResult) -> void:
	if not run_active:
		return
	last_result = result


func get_module_inventory_count(module_id: StringName) -> int:
	return int(module_inventory.get(module_id, 0))

func has_module_in_inventory(module_id: StringName, count: int = 1) -> bool:
	return count >= 0 and get_module_inventory_count(module_id) >= count

func add_module_to_inventory(module_id: StringName, count: int = 1) -> void:
	if module_id == &"" or count <= 0:
		return
	module_inventory[module_id] = get_module_inventory_count(module_id) + count

func take_module_from_inventory(module_id: StringName, count: int = 1) -> bool:
	if module_id == &"" or count <= 0 or not has_module_in_inventory(module_id, count):
		return false
	var remaining := get_module_inventory_count(module_id) - count
	if remaining <= 0:
		module_inventory.erase(module_id)
	else:
		module_inventory[module_id] = remaining
	return true

func add_hull_stock(count: int = 1) -> void:
	if count > 0:
		hull_stock += count

func take_hull_stock(count: int = 1) -> bool:
	if count <= 0 or hull_stock < count:
		return false
	hull_stock -= count
	return true

func get_repair_cost_for_cell(position: Vector2i) -> int:
	if current_ship == null:
		return 0
	var cell := current_ship.get_hull_cell_at(position)
	if cell == null:
		return 0
	return ceili(maxf(cell.max_hp - cell.current_hp, 0.0) * REPAIR_COST_PER_HP)

func repair_cell(position: Vector2i) -> bool:
	if current_ship == null:
		return false
	var cell := current_ship.get_hull_cell_at(position)
	if cell == null:
		return false
	var cost := get_repair_cost_for_cell(position)
	if cost <= 0:
		return true
	if currency < cost:
		return false
	currency -= cost
	cell.repair_full()
	return true

func get_total_repair_cost() -> int:
	if current_ship == null:
		return 0
	var total := 0
	for cell in current_ship.get_hull_cells():
		total += get_repair_cost_for_cell(cell.grid_position)
	return total

func repair_all() -> bool:
	var cost := get_total_repair_cost()
	if cost <= 0:
		return true
	if currency < cost or current_ship == null:
		return false
	currency -= cost
	for cell in current_ship.get_hull_cells():
		cell.current_hp = cell.max_hp
	return true

func get_next_battle_path() -> String:
	if last_result == null or not last_result.is_victory():
		return ""
	return last_result.next_battle_path

func advance_to_next_battle() -> String:
	var path := get_next_battle_path()
	if path.is_empty():
		return ""
	current_battle_path = path
	battle_entry_ship = null
	return path

func _clone_ship(ship: ShipData) -> ShipData:
	if ship == null:
		return null
	var result := ShipSerializer.from_dictionary(ShipSerializer.to_dictionary(ship), DATABASE)
	if not result["ok"]:
		push_error("RunState 无法复制 ShipData：%s" % result["error"])
		return null
	return result["ship"] as ShipData
