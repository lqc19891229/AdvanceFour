class_name PropulsionModuleDefinition
extends ShipModuleDefinition

@export_group("类型专属参数")
@export var thrust: float = 0.0

func _init() -> void:
	module_type = ModuleType.PROPULSION
