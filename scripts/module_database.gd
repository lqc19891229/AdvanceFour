class_name ModuleDatabase
extends Resource

@export var modules: Array[ShipModuleDefinition] = []

func get_by_id(module_id: StringName) -> ShipModuleDefinition:
	for module in modules:
		if module != null and module.id == module_id:
			return module
	return null

func to_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for module in modules:
		if module != null:
			result[String(module.id)] = module
	return result
