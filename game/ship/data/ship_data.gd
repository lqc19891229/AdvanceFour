class_name ShipData
extends RefCounted

var modules: Array[ShipModuleInstance] = []
var occupied_cells: Dictionary = {}
var next_uid := 1

func has_core() -> bool:
	for m in modules:
		if m.definition is CoreModuleDefinition:
			return true
	return false

func get_module_at(cell: Vector2i) -> ShipModuleInstance:
	return occupied_cells.get(cell, null)

func rebuild_occupancy() -> void:
	occupied_cells.clear()
	for m in modules:
		for c in m.get_cells():
			occupied_cells[c] = m

func can_place(definition: ShipModuleDefinition, pos: Vector2i, rotation: int) -> Dictionary:
	if definition == null:
		return {"ok": false, "reason": "没有选择模块"}

	var temp := ShipModuleInstance.new(-1, definition, pos, rotation)
	for c in temp.get_cells():
		if occupied_cells.has(c):
			return {"ok": false, "reason": "模块与现有模块重叠"}

	if definition is CoreModuleDefinition and has_core():
		return {"ok": false, "reason": "当前原型每艘飞船只能安装 1 个核心模块"}

	# 飞船结构允许留空：模块不要求相邻、连通，也不要求网格全部填满。
	# 编辑阶段也不以能源不足阻止放置。
	return {"ok": true, "reason": ""}

func place(definition: ShipModuleDefinition, pos: Vector2i, rotation: int) -> ShipModuleInstance:
	var check := can_place(definition, pos, rotation)
	if not check["ok"]:
		return null
	var m := ShipModuleInstance.new(next_uid, definition, pos, rotation)
	next_uid += 1
	modules.append(m)
	for c in m.get_cells():
		occupied_cells[c] = m
	return m

func can_remove(target: ShipModuleInstance) -> Dictionary:
	if target == null:
		return {"ok": false, "reason": "这里没有模块"}
	return {"ok": true, "reason": ""}

func remove(target: ShipModuleInstance) -> bool:
	var check := can_remove(target)
	if not check["ok"]:
		return false
	modules.erase(target)
	rebuild_occupancy()
	return true

func clear() -> void:
	modules.clear()
	occupied_cells.clear()
	next_uid = 1

func is_energy_valid() -> bool:
	return get_energy_cost() <= get_energy_output()

func is_design_valid() -> bool:
	return not modules.is_empty() and has_core() and is_energy_valid()

func get_design_invalid_reason() -> String:
	if modules.is_empty():
		return "飞船为空"
	if not has_core():
		return "缺少核心模块"
	if not is_energy_valid():
		return "能量不足：耗能 %.1f，高于供能 %.1f" % [get_energy_cost(), get_energy_output()]
	return ""

func get_mass() -> float:
	var v := 0.0
	for m in modules:
		v += m.definition.mass
	return v

func get_energy_output() -> float:
	var v := 0.0
	for m in modules:
		if m.definition is EnergyModuleDefinition:
			v += (m.definition as EnergyModuleDefinition).energy_output
	return v

func get_energy_cost() -> float:
	var v := 0.0
	for m in modules:
		v += m.definition.energy_cost
	return v

func get_thrust() -> float:
	var v := 0.0
	for m in modules:
		if m.definition is PropulsionModuleDefinition:
			v += (m.definition as PropulsionModuleDefinition).thrust
	return v

func get_firepower() -> float:
	var v := 0.0
	for m in modules:
		if m.definition is WeaponModuleDefinition:
			v += (m.definition as WeaponModuleDefinition).firepower
	return v

func get_protection() -> float:
	var v := 0.0
	for m in modules:
		if m.definition is DefenseModuleDefinition:
			v += (m.definition as DefenseModuleDefinition).protection
	return v

func get_acceleration_score() -> float:
	return 0.0 if get_mass() <= 0.0 else get_thrust() / get_mass()
