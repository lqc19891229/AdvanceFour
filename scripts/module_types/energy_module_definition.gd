class_name EnergyModuleDefinition
extends ShipModuleDefinition

@export_group("类型专属参数")
@export var energy_output: float = 0.0

func _init() -> void:
	module_type = ModuleType.ENERGY
