class_name EquipmentAppearancePolicy
extends RefCounted

static func should_show(definition: ShipModuleDefinition) -> bool:
	return (
		definition is CoreModuleDefinition
		or definition is WeaponModuleDefinition
		or definition is PropulsionModuleDefinition
	)

static func get_layer(definition: ShipModuleDefinition) -> int:
	if definition is WeaponModuleDefinition:
		return 20
	if definition is CoreModuleDefinition or definition is PropulsionModuleDefinition:
		return 10
	return 0
