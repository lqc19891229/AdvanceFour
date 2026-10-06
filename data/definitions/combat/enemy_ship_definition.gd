class_name EnemyShipDefinition
extends Resource

@export var enemy_id: StringName
@export var display_name := ""
@export var module_ids: Array[StringName] = []
@export var module_positions: Array[Vector2i] = []
@export var module_rotations: Array[int] = []

func is_valid() -> bool:
	return enemy_id != &"" 		and not display_name.strip_edges().is_empty() 		and not module_ids.is_empty() 		and module_ids.size() == module_positions.size() 		and module_ids.size() == module_rotations.size()

func get_invalid_reason() -> String:
	if enemy_id == &"":
		return "敌舰 ID 不能为空。"
	if display_name.strip_edges().is_empty():
		return "敌舰名称不能为空。"
	if module_ids.is_empty():
		return "敌舰蓝图至少需要一个设备。"
	if module_ids.size() != module_positions.size() or module_ids.size() != module_rotations.size():
		return "敌舰蓝图的设备、位置与旋转数组长度必须一致。"
	return ""

func build_design(database: ModuleDatabase) -> ShipData:
	if database == null or not is_valid():
		return null
	var design := ShipData.new()
	for index in range(module_ids.size()):
		var definition := database.get_by_id(module_ids[index])
		if definition == null:
			return null
		var position := module_positions[index]
		var rotation := module_rotations[index]
		design.ensure_hull_for_equipment(definition, position, rotation)
		if design.place(definition, position, rotation) == null:
			return null
	return design if design.is_design_valid() else null
