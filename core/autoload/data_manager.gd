class_name AdvanceFourDataManager
extends Node

const MODULE_DATABASE_PATH := "res://data/generated/module_database.tres"

var module_database: ModuleDatabase
var modules_by_id: Dictionary = {}

func _ready() -> void:
	reload_data()

func reload_data() -> void:
	module_database = load(MODULE_DATABASE_PATH) as ModuleDatabase
	modules_by_id.clear()
	if module_database == null:
		push_error("无法加载模块数据库：%s" % MODULE_DATABASE_PATH)
		return
	modules_by_id = module_database.to_dictionary()

func get_module(module_id: StringName) -> ShipModuleDefinition:
	return modules_by_id.get(String(module_id), null)
