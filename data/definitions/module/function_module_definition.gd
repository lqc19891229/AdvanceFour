class_name FunctionModuleDefinition
extends ShipModuleDefinition

@export var storage_capacity := 0

func _init() -> void:
	module_type = ModuleType.FUNCTION
