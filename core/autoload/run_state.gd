extends Node

const DATABASE := preload("res://data/modules/module_database.tres")
const REPAIR_COST_PER_HP := 1.0
const BASE_WAREHOUSE_CAPACITY := 12

var run_active := false
var current_ship: ShipData
var battle_entry_ship: ShipData
var current_battle_path := ""
var route_definition: RunRouteDefinition
var current_route_node_id: StringName = &""
var completed_route_nodes: Array[StringName] = []
var energy_crystals := 0
var parts := 0
var module_inventory: Dictionary = {}
var hull_stock := 0
var shop_node_states: Dictionary = {}
var completed_battles: Array[StringName] = []
var last_result: BattleResult

func reset_run() -> void:
	run_active = false
	current_ship = null
	battle_entry_ship = null
	current_battle_path = ""
	route_definition = null
	current_route_node_id = &""
	completed_route_nodes.clear()
	energy_crystals = 0
	parts = 0
	module_inventory.clear()
	hull_stock = 0
	shop_node_states.clear()
	completed_battles.clear()
	last_result = null


func start_run_with_route(ship: ShipData, route_path: String) -> bool:
	if ship == null or not ship.is_design_valid() or route_path.is_empty():
		return false
	if not ResourceLoader.exists(route_path):
		return false
	var loaded := ResourceLoader.load(route_path)
	if not (loaded is RunRouteDefinition):
		return false
	var route := loaded as RunRouteDefinition
	if not route.is_valid():
		return false
	var copy := _clone_ship(ship)
	if copy == null:
		return false
	reset_run()
	run_active = true
	current_ship = copy
	route_definition = route
	current_route_node_id = route.start_node_id
	var start_node := get_current_route_node()
	if start_node == null:
		reset_run()
		return false
	current_battle_path = start_node.target_path if start_node.node_type == RunRouteNodeDefinition.NodeType.BATTLE else ""
	return true

func is_route_active() -> bool:
	return run_active and route_definition != null and current_route_node_id != &""

func get_current_route_node() -> RunRouteNodeDefinition:
	if route_definition == null or current_route_node_id == &"":
		return null
	return route_definition.get_node(current_route_node_id)

func get_current_route_target_path() -> String:
	var node := get_current_route_node()
	return "" if node == null else node.target_path

func is_current_route_node_complete() -> bool:
	return current_route_node_id != &"" and completed_route_nodes.has(current_route_node_id)

func complete_current_route_node() -> bool:
	if not is_route_active() or is_current_route_node_complete():
		return false
	completed_route_nodes.append(current_route_node_id)
	return true

func get_available_route_node_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var current := get_current_route_node()
	if current == null or not is_current_route_node_complete() or has_pending_reward_choice() or has_pending_loot():
		return result
	for next_id in current.next_node_ids:
		if route_definition.get_node(next_id) != null:
			result.append(next_id)
	return result

func select_route_node(node_id: StringName) -> bool:
	if not is_route_active() or has_pending_reward_choice() or has_pending_loot():
		return false
	if not get_available_route_node_ids().has(node_id):
		return false
	var node := route_definition.get_node(node_id)
	if node == null:
		return false
	current_route_node_id = node_id
	if node.node_type == RunRouteNodeDefinition.NodeType.BATTLE:
		current_battle_path = node.target_path
		battle_entry_ship = null
	else:
		current_battle_path = ""
	return true

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
	energy_crystals += maxi(result.reward_energy_crystals, 0)
	parts += maxi(result.reward_parts, 0)
	hull_stock += maxi(result.reward_hull_cells, 0)
	result.initialize_loot_state()
	if result.battle_id != &"" and not completed_battles.has(result.battle_id):
		completed_battles.append(result.battle_id)
	last_result = result
	battle_entry_ship = null
	if is_route_active():
		var node := get_current_route_node()
		if (
			node != null
			and node.node_type == RunRouteNodeDefinition.NodeType.BATTLE
			and node.target_path == result.battle_path
		):
			complete_current_route_node()
	return true

func has_pending_loot() -> bool:
	return (
		run_active
		and last_result != null
		and last_result.is_victory()
		and last_result.has_pending_loot()
	)

func get_loot_count(index: int) -> int:
	if last_result == null or index < 0 or index >= last_result.reward_module_ids.size():
		return 0
	if index < last_result.reward_module_counts.size():
		return maxi(last_result.reward_module_counts[index], 0)
	return 1

func can_take_loot(index: int) -> bool:
	if not has_pending_loot() or index < 0 or index >= last_result.reward_module_ids.size():
		return false
	if index < last_result.loot_resolved.size() and last_result.loot_resolved[index]:
		return false
	var module_id := last_result.reward_module_ids[index]
	var count := get_loot_count(index)
	return count > 0 and can_store_module(module_id, count)

func take_loot(index: int) -> bool:
	if not can_take_loot(index):
		return false
	var module_id := last_result.reward_module_ids[index]
	var count := get_loot_count(index)
	if not store_module(module_id, count):
		return false
	last_result.loot_resolved[index] = true
	last_result.loot_taken[index] = true
	return true

func discard_loot(index: int) -> bool:
	if not has_pending_loot() or index < 0 or index >= last_result.reward_module_ids.size():
		return false
	if index < last_result.loot_resolved.size() and last_result.loot_resolved[index]:
		return false
	last_result.loot_resolved[index] = true
	last_result.loot_taken[index] = false
	return true


func has_pending_reward_choice() -> bool:
	return (
		last_result != null
		and last_result.is_victory()
		and not last_result.reward_choices.is_empty()
		and not last_result.reward_choice_claimed
	)

func can_claim_reward_choice(index: int) -> bool:
	if not run_active or last_result == null or not last_result.is_victory():
		return false
	if last_result.reward_choice_claimed or index < 0 or index >= last_result.reward_choices.size():
		return false
	var raw_choice := last_result.reward_choices[index]
	if not (raw_choice is BattleRewardOption):
		return false
	var choice := raw_choice as BattleRewardOption
	if not choice.is_valid():
		return false
	if choice.module_id != &"" and choice.module_count > 0:
		return can_store_module(choice.module_id, choice.module_count)
	return true

func claim_reward_choice(index: int) -> bool:
	if not run_active or last_result == null or not last_result.is_victory():
		return false
	if last_result.reward_choice_claimed:
		return false
	if not can_claim_reward_choice(index):
		return false
	var raw_choice := last_result.reward_choices[index]
	if not (raw_choice is BattleRewardOption):
		return false
	var choice := raw_choice as BattleRewardOption
	if not choice.is_valid():
		return false
	if choice.module_id != &"" and choice.module_count > 0:
		if not store_module(choice.module_id, choice.module_count):
			return false
	if choice.hull_cells > 0:
		add_hull_stock(choice.hull_cells)
	last_result.reward_choice_claimed = true
	last_result.selected_reward_choice = index
	return true

func record_defeat(result: BattleResult) -> void:
	if not run_active:
		return
	last_result = result



func add_energy_crystals(amount: int) -> void:
	if amount > 0:
		energy_crystals += amount

func can_spend_energy_crystals(amount: int) -> bool:
	return amount >= 0 and energy_crystals >= amount

func spend_energy_crystals(amount: int) -> bool:
	if amount < 0 or energy_crystals < amount:
		return false
	energy_crystals -= amount
	return true

func add_parts(amount: int) -> void:
	if amount > 0:
		parts += amount

func can_spend_parts(amount: int) -> bool:
	return amount >= 0 and parts >= amount

func spend_parts(amount: int) -> bool:
	if amount < 0 or parts < amount:
		return false
	parts -= amount
	return true

func get_module_inventory_count(module_id: StringName) -> int:
	return int(module_inventory.get(module_id, 0))

func has_module_in_inventory(module_id: StringName, count: int = 1) -> bool:
	return count >= 0 and get_module_inventory_count(module_id) >= count

func get_module_storage_cost(module_id: StringName, count: int = 1) -> int:
	if module_id == &"" or count <= 0:
		return 0
	var definition := DATABASE.get_by_id(module_id)
	if definition == null:
		return 0
	return maxi(definition.get_storage_cost(), 0) * count

func get_warehouse_capacity() -> int:
	var capacity := BASE_WAREHOUSE_CAPACITY
	if current_ship != null:
		capacity += maxi(current_ship.get_storage_capacity(), 0)
	return capacity

func get_warehouse_used() -> int:
	var total := 0
	for raw_id in module_inventory.keys():
		var module_id := StringName(raw_id)
		total += get_module_storage_cost(module_id, int(module_inventory[module_id]))
	return total

func get_warehouse_remaining() -> int:
	return get_warehouse_capacity() - get_warehouse_used()

func is_warehouse_over_capacity() -> bool:
	return get_warehouse_used() > get_warehouse_capacity()

func can_store_module(module_id: StringName, count: int = 1) -> bool:
	if not run_active or module_id == &"" or count <= 0:
		return false
	var definition := DATABASE.get_by_id(module_id)
	if definition == null:
		return false
	return get_warehouse_used() + get_module_storage_cost(module_id, count) <= get_warehouse_capacity()

func store_module(module_id: StringName, count: int = 1) -> bool:
	if not can_store_module(module_id, count):
		return false
	add_module_to_inventory(module_id, count)
	return true

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


func _get_shop_state_key(shop: ShopDefinition) -> StringName:
	if shop == null:
		return &""
	if is_route_active():
		var node := get_current_route_node()
		if node != null and node.node_type == RunRouteNodeDefinition.NodeType.SHOP:
			return StringName("route:%s" % String(node.node_id))
	return StringName("shop:%s" % String(shop.shop_id))

func _generate_shop_state(shop: ShopDefinition) -> Dictionary:
	var state := {
		"item_ids": [],
		"purchased_slots": []
	}
	if shop == null or not shop.is_valid():
		return state
	var remaining: Array[ShopItemDefinition] = []
	for raw_item in shop.items:
		var item := raw_item as ShopItemDefinition
		if item != null:
			remaining.append(item)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var item_ids: Array[StringName] = []
	var purchased_slots: Array[bool] = []
	for slot_index in range(shop.slot_count):
		var candidates: Array[ShopItemDefinition] = []
		for item in remaining:
			if shop.item_matches_slot(item, slot_index):
				candidates.append(item)
		if candidates.is_empty():
			candidates.assign(remaining)
		if candidates.is_empty():
			break
		var selected := candidates[rng.randi_range(0, candidates.size() - 1)]
		item_ids.append(selected.item_id)
		purchased_slots.append(false)
		remaining.erase(selected)
	state["item_ids"] = item_ids
	state["purchased_slots"] = purchased_slots
	return state

func _ensure_shop_state(shop: ShopDefinition) -> StringName:
	if not run_active or shop == null or not shop.is_valid():
		return &""
	var key := _get_shop_state_key(shop)
	if key == &"":
		return &""
	if not shop_node_states.has(key):
		shop_node_states[key] = _generate_shop_state(shop)
	return key

func get_shop_slots(shop: ShopDefinition) -> Array[ShopItemDefinition]:
	var result: Array[ShopItemDefinition] = []
	var key := _ensure_shop_state(shop)
	if key == &"":
		return result
	var state: Dictionary = shop_node_states[key]
	var item_ids: Array = state.get("item_ids", [])
	for raw_id in item_ids:
		var item := shop.get_item_by_id(StringName(raw_id))
		if item != null:
			result.append(item)
	return result

func is_shop_slot_purchased(shop: ShopDefinition, slot_index: int) -> bool:
	var key := _ensure_shop_state(shop)
	if key == &"":
		return false
	var state: Dictionary = shop_node_states[key]
	var purchased_slots: Array = state.get("purchased_slots", [])
	if slot_index < 0 or slot_index >= purchased_slots.size():
		return false
	return bool(purchased_slots[slot_index])

func can_purchase_shop_slot(shop: ShopDefinition, slot_index: int) -> bool:
	var slots := get_shop_slots(shop)
	if slot_index < 0 or slot_index >= slots.size() or is_shop_slot_purchased(shop, slot_index):
		return false
	return can_purchase_shop_item(slots[slot_index])

func purchase_shop_slot(shop: ShopDefinition, slot_index: int) -> bool:
	if not can_purchase_shop_slot(shop, slot_index):
		return false
	var slots := get_shop_slots(shop)
	var item := slots[slot_index]
	if not purchase_shop_item(item):
		return false
	var key := _get_shop_state_key(shop)
	var state: Dictionary = shop_node_states[key]
	var purchased_slots: Array = state.get("purchased_slots", [])
	purchased_slots[slot_index] = true
	state["purchased_slots"] = purchased_slots
	shop_node_states[key] = state
	return true

func can_purchase_shop_item(item: ShopItemDefinition) -> bool:
	if not run_active or item == null or not item.is_valid() or energy_crystals < item.price_energy_crystals:
		return false
	if item.module_id != &"" and item.module_count > 0:
		return can_store_module(item.module_id, item.module_count)
	return true

func purchase_shop_item(item: ShopItemDefinition) -> bool:
	if not can_purchase_shop_item(item):
		return false
	if item.module_id != &"" and item.module_count > 0:
		if not store_module(item.module_id, item.module_count):
			return false
	energy_crystals -= item.price_energy_crystals
	if item.hull_cells > 0:
		add_hull_stock(item.hull_cells)
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
	if parts < cost:
		return false
	parts -= cost
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
	if parts < cost or current_ship == null:
		return false
	parts -= cost
	for cell in current_ship.get_hull_cells():
		cell.current_hp = cell.max_hp
	return true

func get_next_battle_path() -> String:
	if is_route_active():
		return ""
	if last_result == null or not last_result.is_victory() or has_pending_reward_choice() or has_pending_loot():
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
