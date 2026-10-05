class_name DefenseModuleDefinition
extends ShipModuleDefinition

@export_group("类型专属参数")
@export var hp: float = 20.0
@export var protection: float = 0.0

func _init() -> void:
	module_type = ModuleType.DEFENSE
