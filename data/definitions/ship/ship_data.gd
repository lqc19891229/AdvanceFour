class_name ShipData
extends RefCounted

var hull_cells: Dictionary = {}
var modules: Array[ShipModuleInstance] = []
var occupied_cells: Dictionary = {}
var next_uid := 1

func has_core() -> bool:
	for module in modules:
		if module.definition is CoreModuleDefinition:
			return true
	return false

func get_hull_cell_at(cell: Vector2i) -> ShipHullCell:
	return hull_cells.get(cell, null) as ShipHullCell

func has_hull_cell(cell: Vector2i) -> bool:
	return hull_cells.has(cell)

func get_hull_cells() -> Array[ShipHullCell]:
	var result: Array[ShipHullCell] = []
	for value in hull_cells.values():
		var cell := value as ShipHullCell
		if cell != null:
			result.append(cell)
	return result

func can_add_hull_cell(cell: Vector2i) -> Dictionary:
	if hull_cells.has(cell):
		return {"ok": false, "reason": "这里已经有船体底板"}
	return {"ok": true, "reason": ""}

func add_hull_cell(
	cell: Vector2i,
	hull_type: StringName = &"basic_hull",
	max_hp: float = ShipHullCell.DEFAULT_MAX_HP,
	mass: float = ShipHullCell.DEFAULT_MASS,
	current_hp: float = -1.0
) -> ShipHullCell:
	var check := can_add_hull_cell(cell)
	if not check["ok"]:
		return null
	var hull := ShipHullCell.new(cell, hull_type, max_hp, mass, current_hp)
	hull_cells[cell] = hull
	return hull

func can_remove_hull_cell(cell: Vector2i) -> Dictionary:
	if not hull_cells.has(cell):
		return {"ok": false, "reason": "这里没有船体底板"}
	if occupied_cells.has(cell):
		return {"ok": false, "reason": "该船体格上安装了设备，需先拆除设备"}
	return {"ok": true, "reason": ""}

func remove_hull_cell(cell: Vector2i) -> bool:
	var check := can_remove_hull_cell(cell)
	if not check["ok"]:
		return false
	hull_cells.erase(cell)
	return true

func ensure_hull_for_equipment(
	definition: ShipModuleDefinition,
	pos: Vector2i,
	rotation: int
) -> void:
	if definition == null:
		return
	var temp := ShipModuleInstance.new(-1, definition, pos, rotation)
	for cell in temp.get_cells():
		if not hull_cells.has(cell):
			add_hull_cell(cell)

func get_module_at(cell: Vector2i) -> ShipModuleInstance:
	return occupied_cells.get(cell, null)

func rebuild_occupancy() -> void:
	occupied_cells.clear()
	for module in modules:
		for cell in module.get_cells():
			occupied_cells[cell] = module

func can_place(definition: ShipModuleDefinition, pos: Vector2i, rotation: int) -> Dictionary:
	if definition == null:
		return {"ok": false, "reason": "没有选择设备"}

	var temp := ShipModuleInstance.new(-1, definition, pos, rotation)
	for cell in temp.get_cells():
		if not hull_cells.has(cell):
			return {"ok": false, "reason": "设备必须完整安装在船体底板上"}
		if occupied_cells.has(cell):
			return {"ok": false, "reason": "设备与现有设备重叠"}

	if definition is CoreModuleDefinition and has_core():
		return {"ok": false, "reason": "当前原型每艘飞船只能安装 1 个核心设备"}

	# Hull Layout 决定可安装区域；Equipment 不再创建船体，也不要求彼此相邻。
	# 编辑阶段仍不以能源不足阻止安装。
	return {"ok": true, "reason": ""}

func place(definition: ShipModuleDefinition, pos: Vector2i, rotation: int) -> ShipModuleInstance:
	var check := can_place(definition, pos, rotation)
	if not check["ok"]:
		return null
	var module := ShipModuleInstance.new(next_uid, definition, pos, rotation)
	next_uid += 1
	modules.append(module)
	for cell in module.get_cells():
		occupied_cells[cell] = module
	return module

func can_relocate(target: ShipModuleInstance, pos: Vector2i, rotation: int) -> Dictionary:
	if target == null or not modules.has(target):
		return {"ok": false, "reason": "没有选择已安装设备"}

	var temp := ShipModuleInstance.new(target.uid, target.definition, pos, rotation)
	for cell in temp.get_cells():
		if not hull_cells.has(cell):
			return {"ok": false, "reason": "设备必须完整安装在船体底板上"}
		var occupant := occupied_cells.get(cell, null) as ShipModuleInstance
		if occupant != null and occupant != target:
			return {"ok": false, "reason": "设备与现有设备重叠"}

	return {"ok": true, "reason": ""}

func relocate(target: ShipModuleInstance, pos: Vector2i, rotation: int) -> bool:
	var check := can_relocate(target, pos, rotation)
	if not check["ok"]:
		return false
	target.grid_position = pos
	target.rotation_quarters = posmod(rotation, 4)
	rebuild_occupancy()
	return true

func can_remove(target: ShipModuleInstance) -> Dictionary:
	if target == null:
		return {"ok": false, "reason": "这里没有设备"}
	return {"ok": true, "reason": ""}

func remove(target: ShipModuleInstance) -> bool:
	var check := can_remove(target)
	if not check["ok"]:
		return false
	modules.erase(target)
	rebuild_occupancy()
	return true

func clear() -> void:
	hull_cells.clear()
	modules.clear()
	occupied_cells.clear()
	next_uid = 1

func clear_equipment() -> void:
	modules.clear()
	occupied_cells.clear()
	next_uid = 1

func is_energy_valid() -> bool:
	return get_energy_cost() <= get_energy_output()

func is_design_valid() -> bool:
	return not hull_cells.is_empty() and not modules.is_empty() and has_core() and is_energy_valid()

func get_design_invalid_reason() -> String:
	if hull_cells.is_empty():
		return "缺少船体底板"
	if modules.is_empty():
		return "没有安装设备"
	if not has_core():
		return "缺少核心设备"
	if not is_energy_valid():
		return "能量不足：耗能 %.1f，高于供能 %.1f" % [get_energy_cost(), get_energy_output()]
	return ""

func get_defense_hp_bonus_at(cell_position: Vector2i) -> float:
	var total := 0.0
	for module in modules:
		if not (module.definition is DefenseModuleDefinition):
			continue
		var covered_cells := module.get_cells()
		if covered_cells.is_empty() or not covered_cells.has(cell_position):
			continue
		var defense := module.definition as DefenseModuleDefinition
		total += maxf(defense.hp, 0.0) / float(covered_cells.size())
	return total

func get_hull_cell_effective_max_hp(cell: ShipHullCell) -> float:
	if cell == null:
		return 0.0
	return maxf(cell.max_hp, 0.0) + get_defense_hp_bonus_at(cell.grid_position)

func get_hull_cell_effective_hp(cell: ShipHullCell) -> float:
	if cell == null:
		return 0.0
	return get_hull_cell_effective_max_hp(cell) * cell.get_health_ratio()

func get_total_hull_hp() -> float:
	var total := 0.0
	for cell in get_hull_cells():
		total += get_hull_cell_effective_hp(cell)
	return total

func get_total_hull_max_hp() -> float:
	var total := 0.0
	for cell in get_hull_cells():
		total += get_hull_cell_effective_max_hp(cell)
	return total

func get_hull_mass() -> float:
	var total := 0.0
	for cell in get_hull_cells():
		total += cell.mass
	return total

func get_energy_output() -> float:
	var total := 0.0
	for module in modules:
		if module.definition is EnergyModuleDefinition:
			total += (module.definition as EnergyModuleDefinition).energy_output
	return total

func get_energy_cost() -> float:
	var total := 0.0
	for module in modules:
		total += module.definition.energy_cost
	return total

func get_thrust() -> float:
	var total := 0.0
	for module in modules:
		if module.definition is PropulsionModuleDefinition:
			total += (module.definition as PropulsionModuleDefinition).thrust
	return total

func get_firepower() -> float:
	var total := 0.0
	for module in modules:
		if module.definition is WeaponModuleDefinition:
			total += (module.definition as WeaponModuleDefinition).firepower
	return total

func get_storage_capacity() -> int:
	var total := 0
	for module in modules:
		if module.definition is FunctionModuleDefinition:
			total += maxi((module.definition as FunctionModuleDefinition).storage_capacity, 0)
	return total

func get_protection() -> float:
	var total := 0.0
	for module in modules:
		if module.definition is DefenseModuleDefinition:
			total += (module.definition as DefenseModuleDefinition).protection
	return total

func get_acceleration_score() -> float:
	# Legacy API name kept for callers; movement now depends only on propulsion thrust.
	return get_thrust()
