class_name ShipSerializer
extends RefCounted

const FORMAT_VERSION := 3
const RIGHT_FORWARD_FORMAT_VERSION := 2
const LEGACY_FORMAT_VERSION := 1

static func to_dictionary(ship: ShipData) -> Dictionary:
	var hull_rows: Array[Dictionary] = []
	for cell in ship.get_hull_cells():
		hull_rows.append({
			"x": cell.grid_position.x,
			"y": cell.grid_position.y,
			"hull_type": String(cell.hull_type),
			"max_hp": cell.max_hp,
			"current_hp": cell.current_hp,
			"mass": cell.mass
		})
	hull_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["y"]) == int(b["y"]):
			return int(a["x"]) < int(b["x"])
		return int(a["y"]) < int(b["y"])
	)

	var module_rows: Array[Dictionary] = []
	for module in ship.modules:
		module_rows.append({
			"module_id": String(module.definition.id),
			"x": module.grid_position.x,
			"y": module.grid_position.y,
			"rotation": module.rotation_quarters
		})

	return {
		"version": FORMAT_VERSION,
		"hull_cells": hull_rows,
		"modules": module_rows
	}

static func from_dictionary(data: Dictionary, module_database: ModuleDatabase) -> Dictionary:
	if module_database == null:
		return _failure("ModuleDatabase 未配置")

	var version := int(data.get("version", 0))
	if version == LEGACY_FORMAT_VERSION:
		return _from_legacy_v1(data, module_database)
	if version not in [FORMAT_VERSION, RIGHT_FORWARD_FORMAT_VERSION]:
		return _failure("不支持的飞船存档版本：%d" % version)

	var hull_rows = data.get("hull_cells", null)
	if typeof(hull_rows) != TYPE_ARRAY:
		return _failure("飞船存档缺少 hull_cells 数组")

	var rows = data.get("modules", null)
	if typeof(rows) != TYPE_ARRAY:
		return _failure("飞船存档缺少 modules 数组")

	var ship := ShipData.new()
	for index in range(hull_rows.size()):
		var row = hull_rows[index]
		if typeof(row) != TYPE_DICTIONARY:
			return _failure("第 %d 个船体格数据格式无效" % index)
		var pos := Vector2i(int(row.get("x", 0)), int(row.get("y", 0)))
		var hull_type := StringName(String(row.get("hull_type", "basic_hull")))
		var max_hp := maxf(float(row.get("max_hp", ShipHullCell.DEFAULT_MAX_HP)), 0.0)
		var current_hp := clampf(float(row.get("current_hp", max_hp)), 0.0, max_hp)
		var mass := maxf(float(row.get("mass", ShipHullCell.DEFAULT_MASS)), 0.0)
		if ship.add_hull_cell(pos, hull_type, max_hp, mass, current_hp) == null:
			return _failure("重复船体格：(%d, %d)" % [pos.x, pos.y])

	var module_result := _restore_modules(ship, rows, module_database, version == RIGHT_FORWARD_FORMAT_VERSION)
	if not module_result["ok"]:
		return module_result
	return {"ok": true, "ship": ship, "error": ""}

static func _from_legacy_v1(data: Dictionary, module_database: ModuleDatabase) -> Dictionary:
	var rows = data.get("modules", null)
	if typeof(rows) != TYPE_ARRAY:
		return _failure("旧版飞船存档缺少 modules 数组")

	var ship := ShipData.new()
	# v1 没有 Hull Layout：迁移时按旧设备占格补齐基础船体格。
	for index in range(rows.size()):
		var row = rows[index]
		if typeof(row) != TYPE_DICTIONARY:
			return _failure("第 %d 个旧版模块数据格式无效" % index)
		var module_id_text := String(row.get("module_id", ""))
		var definition := module_database.get_by_id(StringName(module_id_text))
		if definition == null:
			return _failure("找不到模块定义：%s" % module_id_text)
		var pos := Vector2i(int(row.get("x", 0)), int(row.get("y", 0)))
		var rotation := posmod(int(row.get("rotation", 0)), 4)
		if definition is WeaponModuleDefinition:
			rotation = posmod(rotation + 1, 4)
		var temp := ShipModuleInstance.new(-1, definition, pos, rotation)
		for cell in temp.get_cells():
			if not ship.has_hull_cell(cell):
				ship.add_hull_cell(cell)

	var module_result := _restore_modules(ship, rows, module_database, true)
	if not module_result["ok"]:
		return module_result
	return {"ok": true, "ship": ship, "error": ""}

static func _restore_modules(
	ship: ShipData,
	rows: Array,
	module_database: ModuleDatabase,
	legacy_right_forward: bool = false
) -> Dictionary:
	for index in range(rows.size()):
		var row = rows[index]
		if typeof(row) != TYPE_DICTIONARY:
			return _failure("第 %d 个模块数据格式无效" % index)

		var module_id_text := String(row.get("module_id", ""))
		if module_id_text.is_empty():
			return _failure("第 %d 个模块缺少 module_id" % index)

		var definition := module_database.get_by_id(StringName(module_id_text))
		if definition == null:
			return _failure("找不到模块定义：%s" % module_id_text)

		var pos := Vector2i(int(row.get("x", 0)), int(row.get("y", 0)))
		var rotation := posmod(int(row.get("rotation", 0)), 4)
		if legacy_right_forward and definition is WeaponModuleDefinition:
			rotation = posmod(rotation + 1, 4)
		var check := ship.can_place(definition, pos, rotation)
		if not check["ok"]:
			return _failure("无法恢复设备 %s：%s" % [module_id_text, check["reason"]])
		ship.place(definition, pos, rotation)

	return {"ok": true, "ship": ship, "error": ""}

static func save_to_file(ship: ShipData, path: String) -> Dictionary:
	var global_dir := ProjectSettings.globalize_path(path.get_base_dir())
	var dir_error := DirAccess.make_dir_recursive_absolute(global_dir)
	if dir_error != OK:
		return _failure("无法创建存档目录：error %d" % dir_error)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("无法写入飞船存档：%s" % path)

	file.store_string(JSON.stringify(to_dictionary(ship), "\t"))
	return {"ok": true, "path": path, "error": ""}

static func load_from_file(path: String, module_database: ModuleDatabase) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("飞船存档不存在：%s" % path)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure("无法读取飞船存档：%s" % path)

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		return _failure("飞船存档 JSON 无效：第 %d 行，%s" % [json.get_error_line(), json.get_error_message()])

	if typeof(json.data) != TYPE_DICTIONARY:
		return _failure("飞船存档根节点必须是对象")

	return from_dictionary(json.data, module_database)

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "ship": null, "error": message}
