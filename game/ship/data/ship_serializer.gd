class_name ShipSerializer
extends RefCounted

const FORMAT_VERSION := 1

static func to_dictionary(ship: ShipData) -> Dictionary:
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
		"modules": module_rows
	}

static func from_dictionary(data: Dictionary, module_database: ModuleDatabase) -> Dictionary:
	if module_database == null:
		return _failure("ModuleDatabase 未配置")

	var version := int(data.get("version", 0))
	if version != FORMAT_VERSION:
		return _failure("不支持的飞船存档版本：%d" % version)

	var rows = data.get("modules", null)
	if typeof(rows) != TYPE_ARRAY:
		return _failure("飞船存档缺少 modules 数组")

	var ship := ShipData.new()
	for index in range(rows.size()):
		var row = rows[index]
		if typeof(row) != TYPE_DICTIONARY:
			return _failure("第 %d 个模块数据格式无效" % index)

		var module_id_text := String(row.get("module_id", ""))
		if module_id_text.is_empty():
			return _failure("第 %d 个模块缺少 module_id" % index)

		var module_id := StringName(module_id_text)
		var definition := module_database.get_by_id(module_id)
		if definition == null:
			return _failure("找不到模块定义：%s" % module_id_text)

		var pos := Vector2i(int(row.get("x", 0)), int(row.get("y", 0)))
		var rotation := posmod(int(row.get("rotation", 0)), 4)
		var check := ship.can_place(definition, pos, rotation)
		if not check["ok"]:
			return _failure("无法恢复模块 %s：%s" % [module_id_text, check["reason"]])

		# 恢复时沿用 ShipData 的放置规则：
		# 只禁止占用格重叠和重复核心，不要求模块相邻、连通或填满格子。
		ship.place(definition, pos, rotation)

	return {
		"ok": true,
		"ship": ship,
		"error": ""
	}

static func save_to_file(ship: ShipData, path: String) -> Dictionary:
	var global_dir := ProjectSettings.globalize_path(path.get_base_dir())
	var dir_error := DirAccess.make_dir_recursive_absolute(global_dir)
	if dir_error != OK:
		return _failure("无法创建存档目录：error %d" % dir_error)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("无法写入飞船存档：%s" % path)

	file.store_string(JSON.stringify(to_dictionary(ship), "\t"))
	return {
		"ok": true,
		"path": path,
		"error": ""
	}

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
	return {
		"ok": false,
		"ship": null,
		"error": message
	}
