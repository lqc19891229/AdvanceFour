class_name WeaponModuleDefinition
extends ShipModuleDefinition

@export_group("类型专属参数")
@export var firepower: float = 0.0

func _init() -> void:
	module_type = ModuleType.WEAPON
