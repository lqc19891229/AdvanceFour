@tool
extends RefCounted

const CHIP_DEF = preload("res://data/definitions/bridge/bridge_chip_definition.gd")
const CREW_DEF = preload("res://data/definitions/bridge/bridge_crew_definition.gd")
const EFFECT_DEF = preload("res://data/definitions/bridge/bridge_modifier_definition.gd")
const CONFIG_DEF = preload("res://data/definitions/bridge/bridge_config_definition.gd")
const DATABASE_DEF = preload("res://data/definitions/bridge/bridge_database.gd")
const EXCEL := "res://tools/data_source/bridge_data.xlsx"
const CACHE := "res://tools/cache/bridge.json"
const ROOT := "res://data/bridge"

static func validate_and_import(write_resources: bool) -> bool:
	var python := ""
	for candidate in ["python", "python3", "py"]:
		var output: Array = []
		if OS.execute(candidate, PackedStringArray(["--version"]), output, true) == 0:
			python = candidate
			break
	if python.is_empty():
		push_error("Python 3 is required for bridge data import")
		return false
	var args := PackedStringArray([
		ProjectSettings.globalize_path("res://tools/import/import_bridge.py"),
		ProjectSettings.globalize_path(EXCEL),
		ProjectSettings.globalize_path(CACHE)
	])
	if FileAccess.file_exists(CACHE):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(CACHE)) != OK:
			push_error("Cannot clear stale bridge cache")
			return false
	var output: Array = []
	var code := OS.execute(python, args, output, true)
	if code != 0 or not FileAccess.file_exists(CACHE):
		push_error("Bridge Excel validation failed:\n" + "\n".join(output))
		return false
	var payload = JSON.parse_string(FileAccess.get_file_as_string(CACHE))
	if not (payload is Dictionary) or not payload.get("ok", false):
		push_error("Bridge cache is invalid")
		return false
	if not write_resources:
		print("Bridge data validated")
		return true
	return _save_definitions(payload)

static func _save_definitions(payload: Dictionary) -> bool:
	# Construct all in memory first; do not clear existing assets on parse/build errors.
	var by_owner: Dictionary = {}
	for row in payload["effects"]:
		var d = EFFECT_DEF.new()
		d.effect_id = StringName(row["effect_id"])
		d.owner_id = StringName(row["owner_id"])
		d.stat = StringName(row["stat"])
		d.operation = String(row["operation"])
		d.value = float(row["value"])
		d.target_filter = StringName(row["target_filter"])
		d.condition_id = StringName(row["condition_id"])
		if not by_owner.has(String(d.owner_id)):
			by_owner[String(d.owner_id)] = []
		by_owner[String(d.owner_id)].append(d)
	var db = DATABASE_DEF.new()
	var resources: Dictionary = {}
	for row in payload["chips"]:
		var chip = CHIP_DEF.new()
		chip.chip_id = StringName(row["chip_id"])
		chip.display_name = row["display_name"]
		chip.description = row["description"]
		chip.rarity = StringName(row["rarity"])
		var icon := String(row["icon_path"])
		if not icon.is_empty():
			chip.icon = load(icon) as Texture2D
			if chip.icon == null:
				push_error("Missing chip texture: " + icon)
				return false
		for effect in by_owner.get(String(chip.chip_id), []):
			chip.modifiers.append(effect)
		db.chips.append(chip)
		resources["%s/chips/%s.tres" % [ROOT, row["chip_id"]]] = chip
	for row in payload["crew"]:
		var crew = CREW_DEF.new()
		crew.crew_id = StringName(row["crew_id"])
		crew.display_name = row["display_name"]
		crew.description = row["description"]
		crew.race = StringName(row["race"])
		crew.rarity = StringName(row["rarity"])
		var portrait := String(row["portrait_path"])
		if not portrait.is_empty():
			crew.portrait = load(portrait) as Texture2D
			if crew.portrait == null:
				push_error("Missing crew portrait: " + portrait)
				return false
		for effect in by_owner.get(String(crew.crew_id), []):
			crew.modifiers.append(effect)
		db.crew.append(crew)
		resources["%s/crew/%s.tres" % [ROOT, row["crew_id"]]] = crew
	for row in payload["bridge_configs"]:
		var config = CONFIG_DEF.new()
		config.bridge_id = StringName(row["bridge_id"])
		config.crew_slots = int(row["crew_slots"])
		config.chip_slots = int(row["chip_slots"])
		db.configs.append(config)
		resources["%s/configs/%s.tres" % [ROOT, row["bridge_id"]]] = config
	resources["%s/bridge_database.tres" % ROOT] = db
	# Save using a rollback snapshot so partially written imports do not corrupt previous resources.
	var previous: Dictionary = {}
	for path in resources:
		previous[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	for path in resources:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(String(path).get_base_dir()))
		if ResourceSaver.save(resources[path], path) != OK:
			for old_path in previous:
				var bytes = previous[old_path]
				if bytes == null:
					if FileAccess.file_exists(old_path):
						DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
				else:
					var file := FileAccess.open(old_path, FileAccess.WRITE)
					if file != null:
						file.store_buffer(bytes)
						file.close()
			push_error("Bridge import failed; previous files restored")
			return false
	print("Bridge import completed: %d resources" % resources.size())
	return true
