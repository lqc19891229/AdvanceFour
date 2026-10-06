extends SceneTree

const STAGE_001_PATH := "res://data/battles/stage_001.tres"
const STAGE_002_PATH := "res://data/battles/stage_002.tres"

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
	_check(bool(run_state.call("start_run", design, STAGE_001_PATH)), "A valid design must start a Run")
	_check(int(run_state.get("currency")) == 0 and String(run_state.get("current_battle_path")) == STAGE_001_PATH, "A new Run must start with zero Credits at stage_001")

	var stage_one_ship: ShipData = run_state.call("get_ship_for_battle", STAGE_001_PATH) as ShipData
	var stage_one_cell := _first_cell(stage_one_ship)
	stage_one_cell.current_hp = 8.0
	var victory := BattleResult.new()
	victory.outcome = BattleResult.Outcome.VICTORY
	victory.battle_id = &"stage_001"
	victory.battle_path = STAGE_001_PATH
	victory.next_battle_path = STAGE_002_PATH
	victory.ship_after_battle = stage_one_ship
	victory.reward_credits = 100
	victory.reward_module_ids.assign([&"defense_lightarmor"])
	victory.reward_module_counts.assign([1])
	victory.reward_hull_cells = 1
	victory.enemies_destroyed = 5
	_check(bool(run_state.call("commit_victory", victory)), "Victory must commit a valid BattleResult")
	var current_ship := run_state.get("current_ship") as ShipData
	_check(is_equal_approx(_first_cell(current_ship).current_hp, 8.0), "Victory must persist Hull damage into RunState")
	var completed: Array = run_state.get("completed_battles")
	_check(int(run_state.get("currency")) == 100 and completed.has(&"stage_001"), "Victory must grant Credits and mark the battle complete")
	_check(int(run_state.call("get_module_inventory_count", &"defense_lightarmor")) == 1, "Victory must add fixed module rewards to Run inventory")
	_check(int(run_state.get("hull_stock")) == 1, "Victory must add fixed Hull rewards to Run inventory")
	_check(not bool(run_state.call("commit_victory", victory)) and int(run_state.get("currency")) == 100, "The same victory must not be committed twice")

	var result_screen_scene := load("res://game/run/battle_result/battle_result_screen.tscn") as PackedScene
	var result_screen := result_screen_scene.instantiate() as Control
	root.add_child(result_screen)
	await process_frame
	var result_summary := result_screen.get_node("Center/Panel/Margin/Content/Summary") as Label
	var repair_button := result_screen.get_node("Center/Panel/Margin/Content/ActionRow/RepairAll") as Button
	var end_run_button := result_screen.get_node("Center/Panel/Margin/Content/ActionRow/EndRun") as Button
	_check(result_summary.text.contains("+100 Credits") and result_summary.text.contains("轻型装甲") and result_summary.text.contains("+1 Hull") and repair_button.text.contains("12 Credits"), "Battle result screen must expose all rewards and repair cost")
	var damage_list := result_screen.get_node("Center/Panel/Margin/Content/DamageScroll/DamageList") as VBoxContainer
	var repair_selected := result_screen.get_node("Center/Panel/Margin/Content/RepairSelected") as Button
	var selected_detail := result_screen.get_node("Center/Panel/Margin/Content/SelectedDetail") as Label
	_check(damage_list.get_child_count() == 1, "One damaged Hull must create one local-repair list entry")
	var damage_button := damage_list.get_child(0) as Button
	damage_button.pressed.emit()
	await process_frame
	_check(repair_selected.text.contains("12 Credits") and selected_detail.text.contains("8 / 20"), "Selecting a damaged Hull must expose its local repair action")
	_check(not end_run_button.visible, "A result with a next battle must not show End Run as the primary progression action")
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
	_check(repair_cost == 12, "Missing 12 base Hull HP must cost 12 Credits")
	_check(bool(run_state.call("repair_all")), "Repair all must succeed when Credits are sufficient")
	current_ship = run_state.get("current_ship") as ShipData
	_check(int(run_state.get("currency")) == 88 and is_equal_approx(_first_cell(current_ship).current_hp, 20.0), "Repair all must restore Hull HP and deduct Credits")

	_first_cell(current_ship).current_hp = 0.0
	run_state.set("currency", 5)
	var hp_before := _first_cell(current_ship).current_hp
	_check(not bool(run_state.call("repair_all")), "Repair all must fail atomically when Credits are insufficient")
	_check(int(run_state.get("currency")) == 5 and is_equal_approx(_first_cell(current_ship).current_hp, hp_before), "Failed repair must not change Credits or Hull HP")

	# Local repair must repair exactly one Hull Cell and charge only that cell.
	run_state.call("reset_run")
	_check(bool(run_state.call("start_run", design, STAGE_001_PATH)), "Local repair test must start a Run")
	current_ship = run_state.get("current_ship") as ShipData
	var local_cells := current_ship.get_hull_cells()
	var local_a := local_cells[0]
	var local_b := local_cells[1]
	local_a.current_hp = 8.0
	local_b.current_hp = 10.0
	run_state.set("currency", 12)
	_check(int(run_state.call("get_repair_cost_for_cell", local_a.grid_position)) == 12, "Local repair cost must equal missing Hull HP")
	_check(bool(run_state.call("repair_cell", local_a.grid_position)), "Local repair must succeed when Credits are sufficient")
	_check(is_equal_approx(local_a.current_hp, local_a.max_hp) and is_equal_approx(local_b.current_hp, 10.0), "Local repair must not repair other Hull Cells")
	_check(int(run_state.get("currency")) == 0, "Local repair must deduct only the selected Hull cost")
	_check(not bool(run_state.call("repair_cell", local_b.grid_position)), "Local repair must fail when Credits are insufficient")
	_check(is_equal_approx(local_b.current_hp, 10.0) and int(run_state.get("currency")) == 0, "Failed local repair must be atomic")

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
	defeat.reward_credits = 100
	run_state.call("record_defeat", defeat)
	current_ship = run_state.get("current_ship") as ShipData
	_check(is_equal_approx(_first_cell(current_ship).current_hp, 20.0), "Defeat must not commit battle damage")
	completed = run_state.get("completed_battles")
	_check(int(run_state.get("currency")) == 0 and completed.is_empty(), "Defeat must not grant rewards or completion")

	# Current final-stage result must expose a way to leave the Run.
	run_state.call("reset_run")
	_check(bool(run_state.call("start_run", design, STAGE_002_PATH)), "Final-stage flow must be able to start")
	var final_ship: ShipData = run_state.call("get_ship_for_battle", STAGE_002_PATH) as ShipData
	var final_victory := BattleResult.new()
	final_victory.outcome = BattleResult.Outcome.VICTORY
	final_victory.battle_id = &"stage_002"
	final_victory.battle_path = STAGE_002_PATH
	final_victory.next_battle_path = ""
	final_victory.ship_after_battle = final_ship
	final_victory.reward_credits = 150
	final_victory.reward_module_ids.assign([&"weapon_cannon"])
	final_victory.reward_module_counts.assign([1])
	_check(bool(run_state.call("commit_victory", final_victory)), "Final-stage victory must commit")
	_check(int(run_state.call("get_module_inventory_count", &"weapon_cannon")) == 1, "Final-stage module reward must enter inventory")
	result_screen = result_screen_scene.instantiate() as Control
	root.add_child(result_screen)
	await process_frame
	end_run_button = result_screen.get_node("Center/Panel/Margin/Content/ActionRow/EndRun") as Button
	var next_button := result_screen.get_node("Center/Panel/Margin/Content/ActionRow/NextBattle") as Button
	_check(end_run_button.visible and not next_button.visible, "Final-stage result must offer End Run instead of a dead Next Battle action")
	result_screen.queue_free()
	await process_frame

	run_state.call("reset_run")
	print("Run regression: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
