class_name CoreModuleDefinition
extends ShipModuleDefinition

@export_group("舰桥容量")
@export_range(0, 32) var crew_slots: int = 4
@export_range(0, 32) var chip_slots: int = 4

func _init() -> void:
	module_type = ModuleType.CORE
