class_name ShopDefinition
extends Resource

const FIXED_SLOT_COUNT := 4

@export var shop_id: StringName = &""
@export var display_name := ""
@export var slot_count := FIXED_SLOT_COUNT
@export var slot_groups: Array[StringName] = [&"combat", &"systems", &"utility", &"any"]
@export var items: Array[Resource] = []

func is_valid() -> bool:
	if shop_id == &"" or display_name.strip_edges().is_empty():
		return false
	if slot_count != FIXED_SLOT_COUNT or slot_groups.size() != slot_count or items.size() < slot_count:
		return false
	for group in slot_groups:
		if group == &"":
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
	if slot_count != FIXED_SLOT_COUNT:
		return "当前版本商店必须固定为 4 个商品槽。"
	if slot_groups.size() != slot_count:
		return "商品槽规则数量必须与商品槽数量一致。"
	if items.size() < slot_count:
		return "商品池数量不能少于 4 个。"
	for index in range(slot_groups.size()):
		if slot_groups[index] == &"":
			return "第 %d 个商品槽规则不能为空。" % (index + 1)
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

func get_item_by_id(item_id: StringName) -> ShopItemDefinition:
	for raw_item in items:
		var item := raw_item as ShopItemDefinition
		if item != null and item.item_id == item_id:
			return item
	return null

func item_matches_slot(item: ShopItemDefinition, slot_index: int) -> bool:
	if item == null or slot_index < 0 or slot_index >= slot_groups.size():
		return false
	return item.matches_shop_group(slot_groups[slot_index])
