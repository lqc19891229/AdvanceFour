class_name StationDefinition
extends Resource

@export var station_id: StringName = &""
@export var display_name := ""
@export var craft_items: Array[Resource] = []

func is_valid() -> bool:
	if station_id == &"" or display_name.strip_edges().is_empty() or craft_items.is_empty():
		return false
	var ids: Dictionary = {}
	for raw_item in craft_items:
		if not (raw_item is StationCraftItemDefinition):
			return false
		var item := raw_item as StationCraftItemDefinition
		if not item.is_valid() or ids.has(item.item_id):
			return false
		ids[item.item_id] = true
	return true

func get_invalid_reason() -> String:
	if station_id == &"":
		return "空间站 ID 不能为空。"
	if display_name.strip_edges().is_empty():
		return "空间站名称不能为空。"
	if craft_items.is_empty():
		return "空间站至少需要一个制造项目。"
	var ids: Dictionary = {}
	for index in range(craft_items.size()):
		var raw_item := craft_items[index]
		if not (raw_item is StationCraftItemDefinition):
			return "第 %d 个制造项目类型无效。" % (index + 1)
		var item := raw_item as StationCraftItemDefinition
		if not item.is_valid():
			return "第 %d 个制造项目：%s" % [index + 1, item.get_invalid_reason()]
		if ids.has(item.item_id):
			return "制造项目 ID 重复：%s" % String(item.item_id)
		ids[item.item_id] = true
	return ""

func get_craft_item(item_id: StringName) -> StationCraftItemDefinition:
	for raw_item in craft_items:
		var item := raw_item as StationCraftItemDefinition
		if item != null and item.item_id == item_id:
			return item
	return null
