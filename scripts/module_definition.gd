class_name ShipModuleDefinition
extends Resource

enum ModuleType {
	ENERGY,
	PROPULSION,
	WEAPON,
	DEFENSE,
	FUNCTION,
	CORE
}

@export_group("基础信息")
@export var id: StringName = &""
@export var display_name: String = ""
@export var module_type: ModuleType = ModuleType.FUNCTION
@export_multiline var description: String = ""
@export var size: Vector2i = Vector2i.ONE
@export var mass: float = 0.0
@export var energy_cost: float = 0.0

func get_type_name() -> String:
	match module_type:
		ModuleType.ENERGY:
			return "能量模块"
		ModuleType.PROPULSION:
			return "动力模块"
		ModuleType.WEAPON:
			return "武器模块"
		ModuleType.DEFENSE:
			return "防护模块"
		ModuleType.FUNCTION:
			return "功能模块"
		ModuleType.CORE:
			return "核心模块"
	return "未知模块"
