class_name ShopDefinition
extends Resource

@export var shop_id: StringName = &""
@export var display_name := ""
@export var items: Array[Resource] = []

func is_valid() -> bool:
	if shop_id == &"" or display_name.strip_edges().is_empty() or items.is_empty():
		return false
	var ids: Dictionary = {}
	for raw_item in items:
		if not (raw_item is ShopItemDefinition):
			return false
		var item := raw_item as ShopItemDefinition
		if not item.is_valid() or ids.has(item.item_id):
			return false
		ids[item.item_id] = true
	return true

func get_invalid_reason() -> String:
	if shop_id == &"":
		return "商店 ID 不能为空。"
	if display_name.strip_edges().is_empty():
		return "商店名称不能为空。"
	if items.is_empty():
		return "商店至少需要一个商品。"
	var ids: Dictionary = {}
	for index in range(items.size()):
		var raw_item := items[index]
		if not (raw_item is ShopItemDefinition):
			return "第 %d 个商品类型无效。" % (index + 1)
		var item := raw_item as ShopItemDefinition
		if not item.is_valid():
			return "第 %d 个商品：%s" % [index + 1, item.get_invalid_reason()]
		if ids.has(item.item_id):
			return "商品 ID 重复：%s" % String(item.item_id)
		ids[item.item_id] = true
	return ""
