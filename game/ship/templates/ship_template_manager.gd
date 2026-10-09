class_name ShipTemplateManager
extends RefCounted

const MODULE_DATABASE: ModuleDatabase = preload("res://data/modules/module_database.tres")
const TEMPLATE_DIRECTORY := "res://data/ships/templates/"


static func get_template_path(template_id: String) -> String:
	if not is_valid_template_id(template_id):
		return ""
	return TEMPLATE_DIRECTORY + template_id + ".json"


static func is_valid_template_id(template_id: String) -> bool:
	if template_id.is_empty() or template_id.length() > 64:
		return false
	for character in template_id:
		if not (character >= "a" and character <= "z") \
				and not (character >= "0" and character <= "9") \
				and character != "_":
			return false
	return true


static func list_template_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	var directory := DirAccess.open(TEMPLATE_DIRECTORY)
	if directory == null:
		return ids
	for file_name in directory.get_files():
		if not file_name.ends_with(".json"):
			continue
		var template_id := file_name.trim_suffix(".json")
		if is_valid_template_id(template_id):
			ids.append(template_id)
	ids.sort()
	return ids


static func load_template(template_id: String) -> Dictionary:
	var path := get_template_path(template_id)
	if path.is_empty():
		return {"ok": false, "ship": null, "error": "模板 ID 只能包含小写字母、数字和下划线（最多 64 字符）"}
	return ShipSerializer.load_from_file(path, MODULE_DATABASE)


static func save_template(template_id: String, ship: ShipData) -> Dictionary:
	var path := get_template_path(template_id)
	if path.is_empty():
		return {"ok": false, "error": "无效的模板 ID"}
	if ship == null or not ship.is_design_valid():
		return {"ok": false, "error": "飞船设计未满足出航条件，无法保存为模板"}
	if not OS.has_feature("editor"):
		return {"ok": false, "error": "模板编辑功能只能在 Godot 编辑器中运行"}
	if FileAccess.file_exists(path):
		var backup_path := path + ".bak"
		var copy_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(backup_path)
		)
		if copy_error != OK:
			return {"ok": false, "error": "无法备份已有模板：%d" % copy_error}
	return ShipSerializer.save_to_file(ship, path)


static func delete_template(template_id: String) -> Dictionary:
	var path := get_template_path(template_id)
	if path.is_empty():
		return {"ok": false, "error": "无效的模板 ID"}
	if not OS.has_feature("editor"):
		return {"ok": false, "error": "模板删除功能只能在 Godot 编辑器中运行"}
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "模板不存在"}
	var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if error != OK:
		return {"ok": false, "error": "删除失败：%d" % error}
	return {"ok": true, "error": ""}
