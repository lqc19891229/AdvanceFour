class_name ShipData
extends RefCounted

var modules: Array[ShipModuleInstance] = []
var occupied_cells: Dictionary = {}
var next_uid := 1

func has_core() -> bool:
	for m in modules:
		if m.definition.type == ShipModuleDefinition.ModuleType.CORE:
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
	var temp := ShipModuleInstance.new(-1, definition, pos, rotation)
	for c in temp.get_cells():
		if occupied_cells.has(c):
			return {"ok": false, "reason": "模块与现有模块重叠"}
	if definition.type == ShipModuleDefinition.ModuleType.CORE and has_core():
		return {"ok": false, "reason": "当前原型每艘飞船只能安装 1 个核心模块"}
	if not modules.is_empty() and not _touches_ship(temp.get_cells()):
		return {"ok": false, "reason": "新模块必须与现有飞船上下左右相连"}
	var output_after := get_energy_output() + definition.energy_output
	var cost_after := get_energy_cost() + definition.energy_cost
	if cost_after > output_after:
		return {"ok": false, "reason": "能量不足：安装后耗能 %.1f，高于供能 %.1f" % [cost_after, output_after]}
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
	var remaining: Array[ShipModuleInstance] = []
	for m in modules:
		if m != target:
			remaining.append(m)
	if remaining.is_empty():
		return {"ok": true, "reason": ""}
	var cells: Dictionary = {}
	for m in remaining:
		for c in m.get_cells():
			cells[c] = true
	var start: Vector2i = cells.keys()[0]
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	while not queue.is_empty():
		var current = queue.pop_front()
		for d in dirs:
			var n = current + d
			if cells.has(n) and not visited.has(n):
				visited[n] = true
				queue.append(n)
	if visited.size() != cells.size():
		return {"ok": false, "reason": "删除后飞船会断开"}
	var out := 0.0
	var cost := 0.0
	for m in remaining:
		out += m.definition.energy_output
		cost += m.definition.energy_cost
	if cost > out:
		return {"ok": false, "reason": "删除后能量不足：耗能 %.1f，高于供能 %.1f" % [cost, out]}
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

func _touches_ship(cells: Array[Vector2i]) -> bool:
	var dirs := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
	for c in cells:
		for d in dirs:
			if occupied_cells.has(c + d):
				return true
	return false

func get_mass() -> float:
	var v := 0.0
	for m in modules: v += m.definition.mass
	return v
func get_energy_output() -> float:
	var v := 0.0
	for m in modules: v += m.definition.energy_output
	return v
func get_energy_cost() -> float:
	var v := 0.0
	for m in modules: v += m.definition.energy_cost
	return v
func get_thrust() -> float:
	var v := 0.0
	for m in modules: v += m.definition.thrust
	return v
func get_firepower() -> float:
	var v := 0.0
	for m in modules: v += m.definition.firepower
	return v
func get_protection() -> float:
	var v := 0.0
	for m in modules: v += m.definition.protection
	return v
func get_total_hp() -> float:
	var v := 0.0
	for m in modules: v += m.definition.max_hp
	return v
func get_acceleration_score() -> float:
	return 0.0 if get_mass() <= 0.0 else get_thrust() / get_mass()
