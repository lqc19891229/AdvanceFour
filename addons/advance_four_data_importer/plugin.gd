@tool
extends EditorPlugin

const EXCEL_PATH := "res://tools/data_import/source/game_data.xlsx"
const JSON_PATH := "res://tools/data_import/cache/modules.json"
const GENERATED_ROOT := "res://data/generated/modules"
const DATABASE_PATH := "res://data/generated/module_database.tres"

const EnergyDef = preload("res://game/ship/definitions/energy_module_definition.gd")
const PropulsionDef = preload("res://game/ship/definitions/propulsion_module_definition.gd")
const WeaponDef = preload("res://game/ship/definitions/weapon_module_definition.gd")
const DefenseDef = preload("res://game/ship/definitions/defense_module_definition.gd")
const FunctionDef = preload("res://game/ship/definitions/function_module_definition.gd")
const CoreDef = preload("res://game/ship/definitions/core_module_definition.gd")
const ModuleDatabaseScript = preload("res://game/ship/data/module_database.gd")

func _enter_tree() -> void:
	add_tool_menu_item("前进四：导入模块数据", _import_all)
	add_tool_menu_item("前进四：验证模块数据", _validate_only)

func _exit_tree() -> void:
	remove_tool_menu_item("前进四：导入模块数据")
	remove_tool_menu_item("前进四：验证模块数据")

func _validate_only() -> void:
	var payload := _run_excel_parser()
	if payload.is_empty():
		return
	if payload.get("ok", false):
		_notify("模块数据验证通过：%d 条" % payload.get("modules", []).size())
	else:
		_report_errors(payload)

func _import_all() -> void:
	var payload := _run_excel_parser()
	if payload.is_empty():
		return
	if not payload.get("ok", false):
		_report_errors(payload)
		return

	var rows: Array = payload.get("modules", [])
	var prepared := _prepare_definitions(rows)
	if not prepared.get("ok", false):
		return

	var modules: Array[ShipModuleDefinition] = prepared["modules"]
	var backup := _snapshot_generated_resources()
	if not _write_generated_resources(modules, rows):
		_restore_generated_resources(backup)
		get_editor_interface().get_resource_filesystem().scan()
		push_error("模块数据导入失败，已恢复导入前的 generated 资源")
		return

	get_editor_interface().get_resource_filesystem().scan()
	_notify("模块数据导入完成：%d 个 .tres" % modules.size())

func _prepare_definitions(rows: Array) -> Dictionary:
	var modules: Array[ShipModuleDefinition] = []
	var ids: Dictionary = {}
	for row in rows:
		var definition := _build_definition(row)
		if definition == null:
			push_error("无法创建模块：%s" % str(row))
			return {"ok": false, "modules": modules}
		if ids.has(String(definition.id)):
			push_error("重复模块 ID：%s" % definition.id)
			return {"ok": false, "modules": modules}
		ids[String(definition.id)] = true
		modules.append(definition)
	return {"ok": true, "modules": modules}

func _write_generated_resources(
	modules: Array[ShipModuleDefinition],
	rows: Array
) -> bool:
	if modules.size() != rows.size():
		push_error("模块定义数量与源数据数量不一致")
		return false
	if not _clear_generated_module_resources():
		return false

	for index in range(modules.size()):
		var definition := modules[index]
		var row: Dictionary = rows[index]
		var folder := "%s/%s" % [GENERATED_ROOT, _type_folder(String(row["module_type"]))]
		_ensure_dir(folder)
		var path := "%s/%s.tres" % [folder, String(definition.id)]
		var err := ResourceSaver.save(definition, path)
		if err != OK:
			push_error("保存模块失败：%s (error %d)" % [path, err])
			return false

	var database := ModuleDatabaseScript.new()
	database.modules = modules
	var db_err := ResourceSaver.save(database, DATABASE_PATH)
	if db_err != OK:
		push_error("保存 ModuleDatabase 失败：error %d" % db_err)
		return false
	return true

func _build_definition(row: Dictionary) -> ShipModuleDefinition:
	var type_name := String(row["module_type"])
	var d: ShipModuleDefinition
	match type_name:
		"ENERGY":
			d = EnergyDef.new()
			(d as EnergyModuleDefinition).energy_output = float(row["energy_output"])
		"PROPULSION":
			d = PropulsionDef.new()
			(d as PropulsionModuleDefinition).thrust = float(row["thrust"])
		"WEAPON":
			d = WeaponDef.new()
			var weapon := d as WeaponModuleDefinition
			weapon.firepower = float(row["firepower"])
			weapon.attack_range = float(row["attack_range"])
			weapon.fire_interval = float(row["fire_interval"])
			weapon.turn_speed_degrees = float(row["turn_speed_degrees"])
			weapon.projectile_speed = float(row["projectile_speed"])
			weapon.firing_arc_degrees = float(row["firing_arc_degrees"])
			weapon.fire_angle_tolerance_degrees = float(row["fire_angle_tolerance_degrees"])
		"DEFENSE":
			d = DefenseDef.new()
			var defense := d as DefenseModuleDefinition
			defense.hp = float(row["hp"])
			defense.protection = float(row["protection"])
		"FUNCTION":
			d = FunctionDef.new()
		"CORE":
			d = CoreDef.new()
		_:
			return null

	d.id = StringName(String(row["id"]))
	d.display_name = String(row["display_name"])
	d.description = String(row["description"])
	d.size = Vector2i(int(row["width"]), int(row["height"]))
	d.energy_cost = float(row["energy_cost"])

	var texture_path := String(row.get("texture_path", "")).strip_edges()
	d.texture = _load_texture(texture_path)
	if d.texture == null:
		push_error("模块贴图不存在或无法加载：%s -> %s" % [d.id, texture_path])
		return null

	if d is WeaponModuleDefinition:
		var turret_texture_path := String(row.get("turret_texture_path", "")).strip_edges()
		(d as WeaponModuleDefinition).turret_texture = _load_texture(turret_texture_path)
		if (d as WeaponModuleDefinition).turret_texture == null:
			push_error("武器炮塔贴图不存在或无法加载：%s -> %s" % [d.id, turret_texture_path])
			return null
	return d

func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _run_excel_parser() -> Dictionary:
	var python := _find_python()
	if python.is_empty():
		push_error("找不到 Python。请安装 Python 3，并确保 python 或 py 命令可用。")
		return {}

	var script_path := ProjectSettings.globalize_path("res://tools/data_import/import_excel.py")
	var excel_path := ProjectSettings.globalize_path(EXCEL_PATH)
	var json_path := ProjectSettings.globalize_path(JSON_PATH)
	if FileAccess.file_exists(JSON_PATH):
		var remove_err := DirAccess.remove_absolute(json_path)
		if remove_err != OK:
			push_error("无法清理旧导入缓存：%s (error %d)" % [JSON_PATH, remove_err])
			return {}

	var output: Array = []
	var args: PackedStringArray = []
	for prefix_arg in python.get("prefix_args", []):
		args.append(prefix_arg)
	args.append(script_path)
	args.append(excel_path)
	args.append(json_path)

	var exit_code := OS.execute(String(python["command"]), args, output, true)
	if not FileAccess.file_exists(JSON_PATH):
		push_error("Excel 解析没有生成新的缓存文件（exit %d）：\n%s" % [
			exit_code,
			"\n".join(output)
		])
		return {}

	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取本次导入缓存：%s" % JSON_PATH)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("本次导入缓存 JSON 格式无效")
		return {}
	if exit_code != 0 and parsed.get("ok", true):
		push_error("Excel 解析异常退出（exit %d）：\n%s" % [
			exit_code,
			"\n".join(output)
		])
		return {}
	return parsed

func _find_python() -> Dictionary:
	var candidates := [
		{"command": "python", "prefix_args": []},
		{"command": "python3", "prefix_args": []},
		{"command": "py", "prefix_args": ["-3"]}
	]
	for candidate in candidates:
		var output: Array = []
		var args: PackedStringArray = []
		for prefix_arg in candidate["prefix_args"]:
			args.append(prefix_arg)
		args.append("--version")
		if OS.execute(candidate["command"], args, output, true) == 0:
			return candidate
	return {}

func _type_folder(type_name: String) -> String:
	match type_name:
		"ENERGY": return "energy"
		"PROPULSION": return "propulsion"
		"WEAPON": return "weapon"
		"DEFENSE": return "defense"
		"FUNCTION": return "function"
		"CORE": return "core"
	return "unknown"

func _ensure_dir(res_path: String) -> void:
	var global_path := ProjectSettings.globalize_path(res_path)
	DirAccess.make_dir_recursive_absolute(global_path)

func _snapshot_generated_resources() -> Dictionary:
	var snapshot := {
		"module_files": {},
		"database_exists": FileAccess.file_exists(DATABASE_PATH),
		"database_bytes": PackedByteArray()
	}
	if snapshot["database_exists"]:
		snapshot["database_bytes"] = FileAccess.get_file_as_bytes(DATABASE_PATH)

	var type_folders := ["energy", "propulsion", "weapon", "defense", "function", "core"]
	for type_folder in type_folders:
		var folder := "%s/%s" % [GENERATED_ROOT, type_folder]
		_ensure_dir(folder)
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.get_extension().to_lower() == "tres":
				var path := "%s/%s" % [folder, file_name]
				snapshot["module_files"][path] = FileAccess.get_file_as_bytes(path)
			file_name = dir.get_next()
		dir.list_dir_end()
	return snapshot

func _restore_generated_resources(snapshot: Dictionary) -> void:
	_clear_generated_module_resources()

	for path in snapshot.get("module_files", {}):
		var folder := String(path).get_base_dir()
		_ensure_dir(folder)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("无法恢复模块资源：%s" % path)
			continue
		file.store_buffer(snapshot["module_files"][path])
		file.close()

	if FileAccess.file_exists(DATABASE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DATABASE_PATH))
	if snapshot.get("database_exists", false):
		var database_file := FileAccess.open(DATABASE_PATH, FileAccess.WRITE)
		if database_file == null:
			push_error("无法恢复 ModuleDatabase：%s" % DATABASE_PATH)
		else:
			database_file.store_buffer(snapshot["database_bytes"])
			database_file.close()

func _clear_generated_module_resources() -> bool:
	var success := true
	var type_folders := ["energy", "propulsion", "weapon", "defense", "function", "core"]
	for type_folder in type_folders:
		var folder := "%s/%s" % [GENERATED_ROOT, type_folder]
		_ensure_dir(folder)
		var dir := DirAccess.open(folder)
		if dir == null:
			push_error("无法打开生成模块目录：%s" % folder)
			success = false
			continue

		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.get_extension().to_lower() == "tres":
				var err := dir.remove(file_name)
				if err != OK:
					push_error("删除旧模块失败：%s/%s (error %d)" % [folder, file_name, err])
					success = false
			file_name = dir.get_next()
		dir.list_dir_end()
	return success

func _report_errors(payload: Dictionary) -> void:
	var errors: Array = payload.get("errors", [])
	push_error("模块数据验证失败：\n- %s" % "\n- ".join(errors))

func _notify(message: String) -> void:
	print("[AdvanceFourDataImporter] %s" % message)
