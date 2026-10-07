extends SceneTree

const STAGE_001_PATH := "res://data/battles/stage_001/battle.tres"
const STAGE_002_PATH := "res://data/battles/stage_002/battle.tres"
const ELITE_001_PATH := "res://data/battles/elite_001/battle.tres"

var checks := 0
var failures: Array[String] = []
var run_state: Node

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _first_cell(ship: ShipData) -> ShipHullCell:
	var cells := ship.get_hull_cells()
	return null if cells.is_empty() else cells[0]

func _run() -> void:
	run_state = root.get_node_or_null("RunState")
	_check(run_state != null, "RunState autoload must be available")
	if run_state == null:
		print("Run regression: %d checks, %d failures" % [checks, failures.size()])
		quit(1)
		return

	run_state.call("reset_run")
	var design := Battle.build_starter_design()
	var cannon_definition := ShopItemDefinition.DATABASE.get_by_id(&"weapon_cannon") as WeaponModuleDefinition
	_check(cannon_definition != null and cannon_definition.icon_texture != null and cannon_definition.get_display_texture() == cannon_definition.icon_texture and cannon_definition.get_display_texture() != cannon_definition.texture, "Weapon cannon must use a dedicated combined UI icon instead of its base texture")
	_check(bool(run_state.call("start_run", design, STAGE_001_PATH)), "A valid design must start a Run")
	_check(int(run_state.get("energy_crystals")) == 0 and String(run_state.get("current_battle_path")) == STAGE_001_PATH, "A new Run must start with zero 能量结晶 at stage_001")

	var stage_one_ship: ShipData = run_state.call("get_ship_for_battle", STAGE_001_PATH) as ShipData
	var stage_one_cell := _first_cell(stage_one_ship)
	stage_one_cell.current_hp = 8.0
	var victory := BattleResult.new()
	victory.outcome = BattleResult.Outcome.VICTORY
	victory.battle_id = &"stage_001"
	victory.battle_path = STAGE_001_PATH
	victory.next_battle_path = STAGE_002_PATH
	victory.ship_after_battle = stage_one_ship
	victory.reward_energy_crystals = 100
	victory.reward_parts = 12
	var stage_one_definition := load(STAGE_001_PATH) as BattleDefinition
	victory.reward_choices.assign(stage_one_definition.reward_choices)
	var stage_one_roll := stage_one_definition.loot_table.roll(41001)
	_check(stage_one_definition.loot_table != null and stage_one_definition.loot_table.is_valid() and stage_one_roll.size() == 3, "stage_001 must use a valid three-drop loot table")
	var stage_one_roll_again := stage_one_definition.loot_table.roll(41001)
	_check(stage_one_roll == stage_one_roll_again, "Loot table rolls must be reproducible with a fixed seed")
	var stage_one_loot_ids: Array[StringName] = []
	for rolled in stage_one_roll:
		var rolled_id := StringName(rolled["module_id"])
		stage_one_loot_ids.append(rolled_id)
		victory.reward_module_ids.append(rolled_id)
		victory.reward_module_counts.append(int(rolled["count"]))
	var stage_one_unique: Dictionary = {}
	for loot_id in stage_one_loot_ids:
		stage_one_unique[loot_id] = true
	_check(stage_one_unique.size() == 3, "stage_001 loot table must not return duplicate modules")
	victory.enemies_destroyed = 5
	_check(bool(run_state.call("commit_victory", victory)), "Victory must commit a valid BattleResult")
	var current_ship := run_state.get("current_ship") as ShipData
	_check(is_equal_approx(_first_cell(current_ship).current_hp, 8.0), "Victory must persist Hull damage into RunState")
	var completed: Array = run_state.get("completed_battles")
	_check(int(run_state.get("energy_crystals")) == 100 and int(run_state.get("parts")) == 12 and completed.has(&"stage_001"), "Victory must grant energy crystals, parts and mark the battle complete")
	_check(bool(run_state.call("has_pending_loot")), "Victory with fixed module loot must remain pending until loot is resolved")
	_check(bool(run_state.call("has_pending_reward_choice")), "Victory with reward choices must remain pending until one choice is claimed")
	var loot_absent_before_claim := true
	for loot_id in stage_one_loot_ids:
		if int(run_state.call("get_module_inventory_count", loot_id)) != 0:
			loot_absent_before_claim = false
	_check(loot_absent_before_claim, "Committed battle loot must not enter warehouse automatically")
	_check(not bool(run_state.call("commit_victory", victory)) and int(run_state.get("energy_crystals")) == 100, "The same victory must not be committed twice")

	var loot_scene := load("res://game/run/loot/loot_screen.tscn") as PackedScene
	var loot_screen := loot_scene.instantiate() as Control
	root.add_child(loot_screen)
	await process_frame
	var loot_list := loot_screen.get_node("Center/Panel/Margin/Layout/LootScroll/LootList") as VBoxContainer
	var loot_continue := loot_screen.get_node("Center/Panel/Margin/Layout/Footer/Continue") as Button
	_check(loot_list.get_child_count() == 3 and loot_continue.disabled, "stage_001 loot screen must show three unresolved module drops")
	var first_loot_card := loot_list.get_child(0) as PanelContainer
	var first_loot_labels := first_loot_card.find_children("*", "Label", true, false)
	var loot_detail_has_size := false
	var loot_detail_has_storage := false
	for label in first_loot_labels:
		var loot_text := (label as Label).text
		if loot_text.contains("×1") or loot_text.contains("1×1"):
			loot_detail_has_size = true
		if loot_text.contains("仓储占用"):
			loot_detail_has_storage = true
	_check(not loot_detail_has_size and loot_detail_has_storage, "Loot card must omit module dimensions while keeping storage usage")
	var first_loot_id := stage_one_loot_ids[0]
	var discarded_loot_id := stage_one_loot_ids[1]
	var third_loot_id := stage_one_loot_ids[2]
	var first_loot_count := int(victory.reward_module_counts[0])
	var third_loot_count := int(victory.reward_module_counts[2])
	_check(bool(run_state.call("take_loot", 0)), "An affordable loot item must be transferable into warehouse")
	_check(int(run_state.call("get_module_inventory_count", first_loot_id)) == first_loot_count, "Taking loot must add exactly the rolled module quantity")
	_check(bool(run_state.call("discard_loot", 1)), "Loot may be discarded without entering warehouse")
	_check(int(run_state.call("get_module_inventory_count", discarded_loot_id)) == 0, "Discarded loot must not enter warehouse")
	_check(bool(run_state.call("take_loot", 2)), "A second loot item must be transferable independently")
	_check(int(run_state.call("get_module_inventory_count", third_loot_id)) == third_loot_count and not bool(run_state.call("has_pending_loot")), "Resolving every loot item must clear pending loot")
	loot_screen.call("_refresh")
	await process_frame
	_check(not loot_continue.disabled, "Loot screen continue must unlock after all drops are resolved")
	loot_screen.queue_free()
	await process_frame

	var result_screen_scene := load("res://game/run/battle_result/battle_result_screen.tscn") as PackedScene
	var result_screen := result_screen_scene.instantiate() as Control
	root.add_child(result_screen)
	await process_frame
	var result_summary := result_screen.get_node("Center/Panel/Margin/Content/Summary") as Label
	var repair_button := result_screen.get_node("Center/Panel/Margin/Content/ActionRow/RepairAll") as Button
	var end_run_button := result_screen.get_node("Center/Panel/Margin/Content/ActionRow/EndRun") as Button
	_check(result_summary.text.contains("+100 能量结晶") and result_summary.text.contains("+12 零件") and repair_button.text.contains("12 零件"), "Battle result screen must expose fixed 能量结晶 and repair cost")
	var reward_choice_row := result_screen.get_node("Center/Panel/Margin/Content/RewardChoiceRow") as HBoxContainer
	var next_button_first := result_screen.get_node("Center/Panel/Margin/Content/ActionRow/NextBattle") as Button
	var shop_button_first := result_screen.get_node("Center/Panel/Margin/Content/ActionRow/Shop") as Button
	var refit_button_first := result_screen.get_node("Center/Panel/Margin/Content/ActionRow/Refit") as Button
	_check(reward_choice_row.get_child_count() == 3, "stage_001 must expose three reward choices")
	_check(next_button_first.disabled and shop_button_first.disabled and refit_button_first.disabled, "Pending reward choice must block shop, refit and next battle")
	var damage_list := result_screen.get_node("Center/Panel/Margin/Content/DamageScroll/DamageList") as VBoxContainer
	var repair_selected := result_screen.get_node("Center/Panel/Margin/Content/RepairSelected") as Button
	var selected_detail := result_screen.get_node("Center/Panel/Margin/Content/SelectedDetail") as Label
	_check(damage_list.get_child_count() == 1, "One damaged Hull must create one local-repair list entry")
	var damage_button := damage_list.get_child(0) as Button
	damage_button.pressed.emit()
	await process_frame
	_check(repair_selected.text.contains("12 零件") and selected_detail.text.contains("8 / 20"), "Selecting a damaged Hull must expose its local repair action")
	_check(not end_run_button.visible, "A result with a next battle must not show End Run as the primary progression action")
	var cannon_before_growth := int(run_state.call("get_module_inventory_count", &"weapon_cannon"))
	var inventory_before_growth: Dictionary = (run_state.get("module_inventory") as Dictionary).duplicate(true)
	var choice_weapon := reward_choice_row.get_child(1) as Button
	choice_weapon.pressed.emit()
	await process_frame
	_check(not bool(run_state.call("has_pending_reward_choice")), "Claiming one reward must clear the pending reward state")
	_check(int(run_state.call("get_module_inventory_count", &"weapon_cannon")) == cannon_before_growth + 1, "Selected module reward must add one cannon after battle loot")
	var other_loot_unchanged := true
	for loot_id in inventory_before_growth.keys():
		if StringName(loot_id) != &"weapon_cannon" and int(run_state.call("get_module_inventory_count", StringName(loot_id))) != int(inventory_before_growth[loot_id]):
			other_loot_unchanged = false
	_check(other_loot_unchanged and int(run_state.get("hull_stock")) == 0, "Unselected growth rewards must not alter previously resolved battle loot")
	_check(not next_button_first.disabled and not shop_button_first.disabled and not refit_button_first.disabled, "Claimed reward must unlock shop, refit and next battle")
	_check(not bool(run_state.call("claim_reward_choice", 0)), "Reward choice can only be claimed once")
	result_screen.queue_free()
	await process_frame

	var next_path := String(run_state.call("advance_to_next_battle"))
	_check(next_path == STAGE_002_PATH, "Run progression must advance to stage_002")
	var stage_two_ship: ShipData = run_state.call("get_ship_for_battle", next_path) as ShipData
	_check(is_equal_approx(_first_cell(stage_two_ship).current_hp, 8.0), "The next battle must inherit previous battle Hull damage")
	_first_cell(stage_two_ship).current_hp = 3.0
	var retry_ship: ShipData = run_state.call("get_ship_for_battle", next_path) as ShipData
	_check(is_equal_approx(_first_cell(retry_ship).current_hp, 8.0), "Retry must restore the stage entry Hull snapshot")

	var repair_cost := int(run_state.call("get_total_repair_cost"))
	_check(repair_cost == 12, "Missing 12 base Hull HP must cost 12 parts")
	_check(bool(run_state.call("repair_all")), "Repair all must succeed when parts are sufficient")
	current_ship = run_state.get("current_ship") as ShipData
	_check(int(run_state.get("energy_crystals")) == 100 and int(run_state.get("parts")) == 0 and is_equal_approx(_first_cell(current_ship).current_hp, 20.0), "Repair all must deduct parts while preserving energy crystals")

	_first_cell(current_ship).current_hp = 0.0
	run_state.set("parts", 5)
	var crystals_before_failed_repair := int(run_state.get("energy_crystals"))
	var hp_before := _first_cell(current_ship).current_hp
	_check(not bool(run_state.call("repair_all")), "Repair all must fail atomically when parts are insufficient")
	_check(int(run_state.get("parts")) == 5 and int(run_state.get("energy_crystals")) == crystals_before_failed_repair and is_equal_approx(_first_cell(current_ship).current_hp, hp_before), "Failed repair must not change parts, energy crystals or Hull HP")

	# Local repair must repair exactly one Hull Cell and charge only that cell.
	run_state.call("reset_run")
	_check(bool(run_state.call("start_run", design, STAGE_001_PATH)), "Local repair test must start a Run")
	current_ship = run_state.get("current_ship") as ShipData
	var local_cells := current_ship.get_hull_cells()
	var local_a := local_cells[0]
	var local_b := local_cells[1]
	local_a.current_hp = 8.0
	local_b.current_hp = 10.0
	run_state.set("parts", 12)
	var local_crystals_before := int(run_state.get("energy_crystals"))
	_check(int(run_state.call("get_repair_cost_for_cell", local_a.grid_position)) == 12, "Local repair cost must equal missing Hull HP")
	_check(bool(run_state.call("repair_cell", local_a.grid_position)), "Local repair must succeed when parts are sufficient")
	_check(is_equal_approx(local_a.current_hp, local_a.max_hp) and is_equal_approx(local_b.current_hp, 10.0), "Local repair must not repair other Hull Cells")
	_check(int(run_state.get("parts")) == 0 and int(run_state.get("energy_crystals")) == local_crystals_before, "Local repair must deduct only parts and preserve energy crystals")
	_check(not bool(run_state.call("repair_cell", local_b.grid_position)), "Local repair must fail when parts are insufficient")
	_check(is_equal_approx(local_b.current_hp, 10.0) and int(run_state.get("parts")) == 0 and int(run_state.get("energy_crystals")) == local_crystals_before, "Failed local repair must be atomic")

	# Shop nodes must generate four fixed slots, preserve them for the node lifetime, and sell each slot once.
	run_state.call("reset_run")
	_check(bool(run_state.call("start_run", design, STAGE_001_PATH)), "Shop test must start a Run")
	run_state.set("energy_crystals", 500)
	var shop_definition := load("res://data/shops/basic_shop.tres") as ShopDefinition
	_check(shop_definition != null and shop_definition.is_valid() and shop_definition.items.size() == 7 and shop_definition.slot_count == 4, "Basic shop data must expose a valid seven-item pool and four slots")
	var generated_shop_slots: Array = run_state.call("get_shop_slots", shop_definition)
	_check(generated_shop_slots.size() == 4, "Shop must generate exactly four product slots")
	var generated_ids: Array[StringName] = []
	var all_slots_match := true
	for slot_index in range(generated_shop_slots.size()):
		var generated_item := generated_shop_slots[slot_index] as ShopItemDefinition
		generated_ids.append(generated_item.item_id)
		if not shop_definition.item_matches_slot(generated_item, slot_index):
			all_slots_match = false
	_check(all_slots_match, "Each generated shop item must respect its slot group")
	var unique_ids: Dictionary = {}
	for item_id in generated_ids:
		unique_ids[item_id] = true
	_check(unique_ids.size() == 4, "Generated shop slots must not duplicate products")

	var shop_scene := load("res://game/run/shop/shop_screen.tscn") as PackedScene
	var shop_screen := shop_scene.instantiate() as Control
	root.add_child(shop_screen)
	await process_frame
	var shop_slots_ui := shop_screen.get_node("Center/Panel/Margin/Content/Slots") as HBoxContainer
	var shop_resources := shop_screen.get_node("Center/Panel/Margin/Content/Credits") as Label
	_check(shop_slots_ui.get_child_count() == 4 and shop_resources.text.contains("能量结晶：500") and shop_resources.text.contains("零件：0"), "Shop screen must render four product cards and both resource balances")

	var first_item := generated_shop_slots[0] as ShopItemDefinition
	var credits_before_first_purchase := int(run_state.get("energy_crystals"))
	_check(bool(run_state.call("purchase_shop_slot", shop_definition, 0)), "An affordable unsold shop slot must be purchasable")
	_check(int(run_state.get("energy_crystals")) == credits_before_first_purchase - first_item.price_energy_crystals, "Shop purchase must deduct the selected slot price")
	if first_item.module_id != &"":
		_check(int(run_state.call("get_module_inventory_count", first_item.module_id)) == first_item.module_count, "Purchased module must enter Run inventory")
	else:
		_check(int(run_state.get("hull_stock")) == first_item.hull_cells, "Purchased Hull must enter Run inventory")
	_check(bool(run_state.call("is_shop_slot_purchased", shop_definition, 0)), "Purchased slot must be marked SOLD")
	var credits_after_first_purchase := int(run_state.get("energy_crystals"))
	_check(not bool(run_state.call("purchase_shop_slot", shop_definition, 0)) and int(run_state.get("energy_crystals")) == credits_after_first_purchase, "A SOLD slot must reject repeat purchase atomically")

	var generated_again: Array = run_state.call("get_shop_slots", shop_definition)
	var ids_again: Array[StringName] = []
	for raw_item in generated_again:
		ids_again.append((raw_item as ShopItemDefinition).item_id)
	_check(ids_again == generated_ids, "Refreshing the same shop state must preserve all four generated products")
	shop_screen.call("_refresh")
	await process_frame
	shop_slots_ui = shop_screen.get_node("Center/Panel/Margin/Content/Slots") as HBoxContainer
	var sold_button := shop_slots_ui.get_child(0).get_node("Margin/Content/Buy") as Button
	_check(sold_button.disabled and sold_button.text == "SOLD", "Purchased product card must remain SOLD after refresh")
	shop_screen.queue_free()
	await process_frame

	run_state.call("reset_run")
	_check(bool(run_state.call("start_run", design, STAGE_001_PATH)), "Warehouse test must start a clean Run")
	_check(int(run_state.call("get_warehouse_capacity")) == 12 and int(run_state.call("get_warehouse_used")) == 0, "A Run must start with 12 base warehouse capacity")
	_check(int(run_state.call("get_module_storage_cost", &"weapon_cannon", 1)) == 1, "A 1x1 module must occupy one warehouse unit")
	var cargo_definition := RunState.DATABASE.get_by_id(&"function_cargo_hold") as FunctionModuleDefinition
	_check(cargo_definition != null and cargo_definition.size == Vector2i(2, 2) and cargo_definition.storage_capacity == 16 and cargo_definition.get_storage_cost() == 4, "Standard cargo hold must be 2x2, occupy four storage units, and provide 16 capacity")
	for i in range(12):
		_check(bool(run_state.call("store_module", &"weapon_cannon", 1)), "Warehouse must accept modules while capacity remains")
	_check(int(run_state.call("get_warehouse_used")) == 12 and int(run_state.call("get_warehouse_remaining")) == 0, "Twelve 1x1 modules must fill the base warehouse")
	_check(not bool(run_state.call("store_module", &"weapon_cannon", 1)), "Warehouse must reject a module that exceeds capacity")
	_check(int(run_state.call("get_module_inventory_count", &"weapon_cannon")) == 12, "Failed warehouse storage must preserve inventory atomically")
	run_state.set("energy_crystals", 500)
	var cannon_shop_item := shop_definition.get_item_by_id(&"cannon")
	_check(cannon_shop_item != null and not bool(run_state.call("can_purchase_shop_item", cannon_shop_item)), "A full warehouse must block module purchases")
	_check(not bool(run_state.call("purchase_shop_item", cannon_shop_item)) and int(run_state.get("energy_crystals")) == 500, "Warehouse-full shop purchase must not deduct 能量结晶")

	var capacity_ship := ShipData.new()
	capacity_ship.ensure_hull_for_equipment(cargo_definition, Vector2i.ZERO, 0)
	_check(capacity_ship.place(cargo_definition, Vector2i.ZERO, 0) != null, "Cargo hold must be placeable on prepared Hull")
	run_state.set("current_ship", capacity_ship)
	_check(int(run_state.call("get_warehouse_capacity")) == 28, "Installed standard cargo hold must increase warehouse capacity from 12 to 28")

	run_state.call("reset_run")
	_check(bool(run_state.call("start_run", design, STAGE_001_PATH)), "Warehouse screen test must start a clean Run")
	_check(bool(run_state.call("store_module", &"weapon_cannon", 1)), "Warehouse screen setup must store cannon")
	_check(bool(run_state.call("store_module", &"function_cargo_hold", 1)), "Warehouse screen setup must store cargo hold")
	var warehouse_scene := load("res://game/run/warehouse/warehouse_screen.tscn") as PackedScene
	var warehouse_screen := warehouse_scene.instantiate() as Control
	root.add_child(warehouse_screen)
	await process_frame
	var warehouse_capacity_label := warehouse_screen.get_node("Margin/Layout/Header/Capacity") as Label
	var warehouse_item_list := warehouse_screen.get_node("Margin/Layout/Body/InventoryPanel/InventoryMargin/InventoryLayout/ItemScroll/ItemList") as VBoxContainer
	var warehouse_detail_body := warehouse_screen.get_node("Margin/Layout/Body/DetailPanel/DetailMargin/DetailLayout/Body") as Label
	var warehouse_refit := warehouse_screen.get_node("Margin/Layout/Footer/Refit") as Button
	_check(warehouse_capacity_label.text.contains("5 / 12"), "Warehouse screen must show used and total capacity")
	_check(warehouse_item_list.get_child_count() == 2, "Warehouse screen must stack inventory by module ID")
	var cargo_button: Button
	for child in warehouse_item_list.get_children():
		if child is Button and (child as Button).text.contains("标准货舱"):
			cargo_button = child as Button
	_check(cargo_button != null and cargo_button.text.contains("2×2") and cargo_button.text.contains("总占用 4"), "Cargo hold list entry must show size and storage footprint")
	cargo_button.pressed.emit()
	await process_frame
	_check(warehouse_detail_body.text.contains("安装后仓储容量：+16") and warehouse_detail_body.text.contains("净仓储贡献：+12"), "Cargo hold detail must show installed and net storage contribution")
	var function_filter := warehouse_screen.get_node("Margin/Layout/Filters/Function") as Button
	function_filter.pressed.emit()
	await process_frame
	_check(warehouse_item_list.get_child_count() == 1 and (warehouse_item_list.get_child(0) as Button).text.contains("标准货舱"), "Warehouse Function filter must show only stored function modules")
	_check(warehouse_refit.disabled, "Warehouse must not bypass route rules to grant free refit")
	warehouse_screen.queue_free()
	await process_frame

	run_state.call("reset_run")
	_check(bool(run_state.call("start_run", design, STAGE_001_PATH)), "Inventory primitive test must start a clean Run")

	# Resource primitives must be atomic and keep currencies independent.
	run_state.call("add_energy_crystals", 50)
	run_state.call("add_parts", 20)
	_check(int(run_state.get("energy_crystals")) == 50 and int(run_state.get("parts")) == 20, "Resource APIs must add energy crystals and parts independently")
	_check(bool(run_state.call("spend_energy_crystals", 30)) and int(run_state.get("energy_crystals")) == 20 and int(run_state.get("parts")) == 20, "Spending energy crystals must not change parts")
	_check(not bool(run_state.call("spend_energy_crystals", 25)) and int(run_state.get("energy_crystals")) == 20, "Energy crystal overspend must fail atomically")
	_check(bool(run_state.call("spend_parts", 5)) and int(run_state.get("parts")) == 15 and int(run_state.get("energy_crystals")) == 20, "Spending parts must not change energy crystals")
	_check(not bool(run_state.call("spend_parts", 16)) and int(run_state.get("parts")) == 15, "Parts overspend must fail atomically")

	# Station services must not be callable outside an active station route node.
	var off_route_station := load("res://data/stations/basic_station.tres") as StationDefinition
	var off_route_cell := _first_cell(run_state.get("current_ship") as ShipData)
	off_route_cell.current_hp = 5.0
	run_state.set("parts", 100)
	var off_route_cannon := off_route_station.get_craft_item(&"cannon")
	_check(not bool(run_state.call("repair_all_free_at_station")) and is_equal_approx(off_route_cell.current_hp, 5.0), "Free station repair must be rejected outside a station node")
	_check(not bool(run_state.call("craft_station_item", off_route_cannon)) and int(run_state.get("parts")) == 100 and int(run_state.call("get_module_inventory_count", &"weapon_cannon")) == 0, "Station crafting must be rejected outside a station node")

	# Inventory primitives must be atomic.
	run_state.call("add_module_to_inventory", &"weapon_cannon", 2)
	_check(int(run_state.call("get_module_inventory_count", &"weapon_cannon")) == 2, "Module inventory must add fixed quantities")
	_check(bool(run_state.call("take_module_from_inventory", &"weapon_cannon", 1)), "Available module inventory must be consumable")
	_check(int(run_state.call("get_module_inventory_count", &"weapon_cannon")) == 1, "Consuming a module must decrement inventory")
	_check(not bool(run_state.call("take_module_from_inventory", &"weapon_cannon", 2)), "Module inventory must reject over-consumption atomically")
	_check(int(run_state.call("get_module_inventory_count", &"weapon_cannon")) == 1, "Failed module consumption must preserve inventory")
	run_state.call("add_hull_stock", 2)
	_check(bool(run_state.call("take_hull_stock", 1)) and int(run_state.get("hull_stock")) == 1, "Hull stock must be consumable")
	_check(not bool(run_state.call("take_hull_stock", 2)) and int(run_state.get("hull_stock")) == 1, "Hull stock over-consumption must fail atomically")

	# Run refit editor must expose inventory mode without allowing free clear.
	run_state.call("reset_run")
	_check(bool(run_state.call("start_run", design, STAGE_001_PATH)), "Run refit integration test must start a Run")
	run_state.call("add_module_to_inventory", &"defense_lightarmor", 1)
	run_state.call("add_hull_stock", 1)
	set_meta(&"run_refit_mode", true)
	var refit_editor = load("res://game/ship/editor/ship_editor.tscn").instantiate()
	root.add_child(refit_editor)
	await process_frame
	var refit_grid := refit_editor.get_node("MainLayout/Center/Grid") as ShipGridView
	var clear_button := refit_editor.get_node("MainLayout/RightPanel/RightMargin/RightVBox/ClearButton") as Button
	_check(refit_grid.run_inventory_enabled and clear_button.disabled, "Run refit must enable inventory constraints and disable one-click clear")
	var found_armor_inventory := false
	var found_hull_inventory := false
	var module_buttons := refit_editor.get_node("MainLayout/LeftPanel/LeftMargin/LeftVBox/ModuleButtons") as VBoxContainer
	for child in module_buttons.get_children():
		if child is Button:
			var text_value := (child as Button).text
			if text_value.contains("轻型装甲") and text_value.contains("库存 1"):
				found_armor_inventory = true
			if text_value.contains("基础船体格") and text_value.contains("库存 1"):
				found_hull_inventory = true
	_check(found_armor_inventory and found_hull_inventory, "Run refit buttons must show module and Hull inventory counts")
	refit_editor.queue_free()
	await process_frame

	run_state.call("reset_run")
	_check(bool(run_state.call("start_run", design, STAGE_001_PATH)), "A second Run must start after reset")
	var defeat_ship: ShipData = run_state.call("get_ship_for_battle", STAGE_001_PATH) as ShipData
	_first_cell(defeat_ship).current_hp = 1.0
	var defeat := BattleResult.new()
	defeat.outcome = BattleResult.Outcome.DEFEAT
	defeat.battle_id = &"stage_001"
	defeat.battle_path = STAGE_001_PATH
	defeat.ship_after_battle = defeat_ship
	defeat.reward_energy_crystals = 100
	defeat.reward_parts = 12
	run_state.call("record_defeat", defeat)
	current_ship = run_state.get("current_ship") as ShipData
	_check(is_equal_approx(_first_cell(current_ship).current_hp, 20.0), "Defeat must not commit battle damage")
	completed = run_state.get("completed_battles")
	_check(int(run_state.get("energy_crystals")) == 0 and int(run_state.get("parts")) == 0 and completed.is_empty(), "Defeat must not grant resources or completion")

	# Current final-stage result must expose a way to leave the Run.
	run_state.call("reset_run")
	_check(bool(run_state.call("start_run", design, STAGE_002_PATH)), "Final-stage flow must be able to start")
	var final_ship: ShipData = run_state.call("get_ship_for_battle", STAGE_002_PATH) as ShipData
	var stage_two_definition := load(STAGE_002_PATH) as BattleDefinition
	_check(stage_two_definition.loot_table != null and stage_two_definition.loot_table.is_valid() and stage_two_definition.loot_table.drop_count == 3, "stage_002 must use a valid three-drop loot table")
	var final_victory := BattleResult.new()
	final_victory.outcome = BattleResult.Outcome.VICTORY
	final_victory.battle_id = &"stage_002"
	final_victory.battle_path = STAGE_002_PATH
	final_victory.next_battle_path = ""
	final_victory.ship_after_battle = final_ship
	final_victory.reward_energy_crystals = 150
	final_victory.reward_parts = 20
	final_victory.reward_module_ids.assign([&"weapon_cannon"])
	final_victory.reward_module_counts.assign([1])
	_check(bool(run_state.call("commit_victory", final_victory)), "Final-stage victory must commit")
	_check(int(run_state.call("get_module_inventory_count", &"weapon_cannon")) == 0 and bool(run_state.call("has_pending_loot")), "Final-stage loot must wait for player confirmation")
	_check(bool(run_state.call("take_loot", 0)) and int(run_state.call("get_module_inventory_count", &"weapon_cannon")) == 1, "Taking final-stage loot must move it into warehouse")
	result_screen = result_screen_scene.instantiate() as Control
	root.add_child(result_screen)
	await process_frame
	end_run_button = result_screen.get_node("Center/Panel/Margin/Content/ActionRow/EndRun") as Button
	var next_button := result_screen.get_node("Center/Panel/Margin/Content/ActionRow/NextBattle") as Button
	_check(end_run_button.visible and not next_button.visible, "Final-stage result must offer End Run instead of a dead Next Battle action")
	result_screen.queue_free()
	await process_frame

	# v0.37 route graph must branch through Shop / Refit and converge on stage_002.
	run_state.call("reset_run")
	var route_path := "res://data/routes/prototype_route.tres"
	var route_definition := load(route_path) as RunRouteDefinition
	_check(route_definition != null and route_definition.is_valid() and route_definition.nodes.size() == 6, "Prototype route must contain six valid nodes")
	_check(bool(run_state.call("start_run_with_route", design, route_path)), "A valid design must start the prototype route")
	_check(bool(run_state.call("is_route_active")), "Route Run must report active route state")
	var route_node := run_state.call("get_current_route_node") as RunRouteNodeDefinition
	_check(route_node != null and route_node.node_id == &"battle_001" and route_node.target_path == STAGE_001_PATH, "Route must start at stage_001 battle node")

	var route_ship: ShipData = run_state.call("get_ship_for_battle", STAGE_001_PATH) as ShipData
	var route_victory := BattleResult.new()
	route_victory.outcome = BattleResult.Outcome.VICTORY
	route_victory.battle_id = &"stage_001"
	route_victory.battle_path = STAGE_001_PATH
	route_victory.ship_after_battle = route_ship
	route_victory.reward_energy_crystals = 100
	route_victory.reward_parts = 12
	var route_stage_one := load(STAGE_001_PATH) as BattleDefinition
	route_victory.reward_choices.assign(route_stage_one.reward_choices)
	_check(bool(run_state.call("commit_victory", route_victory)), "Route battle victory must commit")
	_check(bool(run_state.call("is_current_route_node_complete")), "Committed route battle must mark current node complete")
	_check(bool(run_state.call("has_pending_reward_choice")), "Route progression must still respect pending reward choices")
	_check((run_state.call("get_available_route_node_ids") as Array).is_empty(), "Pending reward choice must hide route branches")
	_check(bool(run_state.call("claim_reward_choice", 0)), "Route reward choice must be claimable")
	var branch_ids: Array = run_state.call("get_available_route_node_ids")
	_check(branch_ids.size() == 3 and branch_ids.has(&"shop_001") and branch_ids.has(&"refit_001") and branch_ids.has(&"elite_001"), "stage_001 route must branch to Shop, Station and Elite")
	_check(not bool(run_state.call("select_route_node", &"battle_002")), "Route must reject skipping directly to stage_002")

	var map_scene := load("res://game/run/route/route_map_screen.tscn") as PackedScene
	var map_screen := map_scene.instantiate() as Control
	root.add_child(map_screen)
	await process_frame
	var map_area := map_screen.get_node("Margin/Layout/MapFrame/MapArea") as Control
	var warehouse_route_button := map_screen.get_node("Margin/Layout/Actions/Warehouse") as Button
	_check(warehouse_route_button != null and not warehouse_route_button.disabled, "Active route map must expose warehouse access without changing route choices")
	var route_buttons := 0
	var enabled_route_buttons := 0
	for child in map_area.get_children():
		if child is Button:
			route_buttons += 1
			if not (child as Button).disabled:
				enabled_route_buttons += 1
	_check(route_buttons == 6 and enabled_route_buttons == 3, "Route map must render six nodes with three selectable branches")
	map_screen.queue_free()
	await process_frame

	_check(bool(run_state.call("select_route_node", &"shop_001")), "Shop branch must be selectable")
	route_node = run_state.call("get_current_route_node") as RunRouteNodeDefinition
	_check(route_node.node_type == RunRouteNodeDefinition.NodeType.SHOP and route_node.target_path == "res://data/shops/basic_shop.tres", "Shop branch must target the data-driven shop")
	_check(bool(run_state.call("complete_current_route_node")), "Shop route node must be completable")
	branch_ids = run_state.call("get_available_route_node_ids")
	_check(branch_ids.size() == 1 and branch_ids[0] == &"battle_002", "Completed Shop node must converge on stage_002")
	_check(bool(run_state.call("select_route_node", &"battle_002")), "stage_002 route node must be selectable after Shop")
	route_node = run_state.call("get_current_route_node") as RunRouteNodeDefinition
	_check(route_node.target_path == STAGE_002_PATH, "Second battle node must target stage_002")

	var route_stage_two_ship: ShipData = run_state.call("get_ship_for_battle", STAGE_002_PATH) as ShipData
	var route_final_victory := BattleResult.new()
	route_final_victory.outcome = BattleResult.Outcome.VICTORY
	route_final_victory.battle_id = &"stage_002"
	route_final_victory.battle_path = STAGE_002_PATH
	route_final_victory.ship_after_battle = route_stage_two_ship
	_check(bool(run_state.call("commit_victory", route_final_victory)), "Second route battle must commit")
	branch_ids = run_state.call("get_available_route_node_ids")
	_check(branch_ids.size() == 1 and branch_ids[0] == &"end", "stage_002 must unlock the route end")
	_check(bool(run_state.call("select_route_node", &"end")), "Route end must be selectable")
	route_node = run_state.call("get_current_route_node") as RunRouteNodeDefinition
	_check(route_node.node_type == RunRouteNodeDefinition.NodeType.END, "Selected terminal route node must be END")

	run_state.call("reset_run")
	_check(bool(run_state.call("start_run_with_route", design, route_path)), "Route must restart cleanly for Station branch")
	route_ship = run_state.call("get_ship_for_battle", STAGE_001_PATH) as ShipData
	_first_cell(route_ship).current_hp = 6.0
	route_victory = BattleResult.new()
	route_victory.outcome = BattleResult.Outcome.VICTORY
	route_victory.battle_id = &"stage_001"
	route_victory.battle_path = STAGE_001_PATH
	route_victory.ship_after_battle = route_ship
	route_victory.reward_parts = 50
	_check(bool(run_state.call("commit_victory", route_victory)), "Station branch setup battle must commit")
	_check(bool(run_state.call("select_route_node", &"refit_001")), "Station branch must be selectable")
	route_node = run_state.call("get_current_route_node") as RunRouteNodeDefinition
	_check(route_node.node_type == RunRouteNodeDefinition.NodeType.REFIT and route_node.target_path == "res://data/stations/basic_station.tres", "Refit route node must target station data")
	var station_definition := load(route_node.target_path) as StationDefinition
	_check(station_definition != null and station_definition.is_valid() and station_definition.craft_items.size() == 6, "Basic station must expose six valid craft recipes")
	var parts_before_station := int(run_state.get("parts"))
	var station_scene := load("res://game/run/station/station_screen.tscn") as PackedScene
	var station_screen := station_scene.instantiate() as Control
	root.add_child(station_screen)
	await process_frame
	_check(is_equal_approx(_first_cell(run_state.get("current_ship") as ShipData).current_hp, 20.0), "Entering station must repair all Hull to full for free")
	_check(int(run_state.get("parts")) == parts_before_station, "Free station repair must not consume parts")
	var station_resources := station_screen.get_node("Margin/Layout/Resources") as Label
	var station_craft_list := station_screen.get_node("Margin/Layout/CraftScroll/CraftList") as VBoxContainer
	_check(station_resources.text.contains("零件：50") and station_craft_list.get_child_count() == 6, "Station screen must show resources and all craft recipes")
	var craft_item := station_definition.get_craft_item(&"cannon")
	var parts_before_craft := int(run_state.get("parts"))
	_check(bool(run_state.call("craft_station_item", craft_item)), "Station must craft a valid module when parts and storage are sufficient")
	_check(int(run_state.get("parts")) == parts_before_craft - craft_item.parts_cost and int(run_state.call("get_module_inventory_count", &"weapon_cannon")) == 1, "Crafting must spend parts and add module to warehouse")
	run_state.set("parts", 0)
	var armor_recipe := station_definition.get_craft_item(&"armor")
	var armor_before := int(run_state.call("get_module_inventory_count", &"defense_lightarmor"))
	_check(not bool(run_state.call("craft_station_item", armor_recipe)) and int(run_state.call("get_module_inventory_count", &"defense_lightarmor")) == armor_before, "Station crafting must fail atomically when parts are insufficient")
	run_state.set("parts", 100)
	while int(run_state.call("get_warehouse_remaining")) > 0:
		if not bool(run_state.call("store_module", &"weapon_cannon", 1)):
			break
	var parts_before_full_craft := int(run_state.get("parts"))
	var cargo_recipe := station_definition.get_craft_item(&"cargo_hold")
	_check(not bool(run_state.call("craft_station_item", cargo_recipe)) and int(run_state.get("parts")) == parts_before_full_craft, "Station crafting must not spend parts when warehouse capacity is insufficient")
	var station_refit := station_screen.get_node("Margin/Layout/Actions/Refit") as Button
	_check(not station_refit.disabled, "Station must keep access to ship refit")
	station_screen.queue_free()
	await process_frame
	_check(bool(run_state.call("complete_current_route_node")), "Station route node must be completable")
	branch_ids = run_state.call("get_available_route_node_ids")
	_check(branch_ids.size() == 1 and branch_ids[0] == &"battle_002", "Completed Station node must converge on stage_002")

	# v0.42 elite battle remains a normal BATTLE node whose difficulty/reward come entirely from battle + loot data.
	var elite_definition := load(ELITE_001_PATH) as BattleDefinition
	_check(elite_definition != null and elite_definition.is_valid() and elite_definition.battle_id == &"elite_001", "Elite battle package must contain a valid BattleDefinition")
	var elite_enemy_total := 0
	for wave_index in range(elite_definition.get_wave_count()):
		elite_enemy_total += elite_definition.get_wave(wave_index).get_total_enemy_count()
	_check(elite_definition.reward_energy_crystals == 220 and elite_definition.reward_parts == 30 and elite_enemy_total == 12, "Elite battle difficulty and dual resource rewards must be expressed by battle data")
	_check(elite_definition.loot_table != null and elite_definition.loot_table.is_valid() and elite_definition.loot_table.drop_count == 4 and not elite_definition.loot_table.allow_duplicates, "Elite loot data must grant four non-duplicate weighted drops")
	var elite_roll := elite_definition.loot_table.roll(42001)
	var elite_unique: Dictionary = {}
	for rolled in elite_roll:
		elite_unique[StringName(rolled["module_id"])] = true
	_check(elite_roll.size() == 4 and elite_unique.size() == 4, "Elite loot table must roll four unique modules")

	run_state.call("reset_run")
	_check(bool(run_state.call("start_run_with_route", design, route_path)), "Route must restart cleanly for Elite branch")
	route_ship = run_state.call("get_ship_for_battle", STAGE_001_PATH) as ShipData
	route_victory = BattleResult.new()
	route_victory.outcome = BattleResult.Outcome.VICTORY
	route_victory.battle_id = &"stage_001"
	route_victory.battle_path = STAGE_001_PATH
	route_victory.ship_after_battle = route_ship
	_check(bool(run_state.call("commit_victory", route_victory)), "Elite branch setup battle must commit")
	branch_ids = run_state.call("get_available_route_node_ids")
	_check(branch_ids.has(&"elite_001"), "Elite branch must be available after stage_001")
	_check(bool(run_state.call("select_route_node", &"elite_001")), "Elite battle branch must be selectable")
	route_node = run_state.call("get_current_route_node") as RunRouteNodeDefinition
	_check(route_node.node_type == RunRouteNodeDefinition.NodeType.BATTLE and route_node.target_path == ELITE_001_PATH, "Elite route node must remain a normal BATTLE node targeting elite battle data")
	var elite_ship: ShipData = run_state.call("get_ship_for_battle", ELITE_001_PATH) as ShipData
	var elite_victory := BattleResult.new()
	elite_victory.outcome = BattleResult.Outcome.VICTORY
	elite_victory.battle_id = &"elite_001"
	elite_victory.battle_path = ELITE_001_PATH
	elite_victory.ship_after_battle = elite_ship
	elite_victory.reward_energy_crystals = elite_definition.reward_energy_crystals
	elite_victory.reward_parts = elite_definition.reward_parts
	_check(bool(run_state.call("commit_victory", elite_victory)), "Elite battle victory must commit through the shared battle flow")
	_check(int(run_state.get("energy_crystals")) == 220 and int(run_state.get("parts")) == 30, "Elite dual resource rewards must come from elite battle data")
	branch_ids = run_state.call("get_available_route_node_ids")
	_check(branch_ids.size() == 1 and branch_ids[0] == &"battle_002", "Completed Elite battle must converge on stage_002")

	run_state.call("reset_run")
	print("Run regression: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
