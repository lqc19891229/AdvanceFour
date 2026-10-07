class_name LootTableDefinition
extends Resource

@export var loot_id: StringName = &""
@export var display_name := ""
@export var drop_count := 3
@export var allow_duplicates := false
@export var entries: Array[Resource] = []

func is_valid() -> bool:
	if loot_id == &"" or display_name.strip_edges().is_empty() or drop_count < 0:
		return false
	if drop_count > 0 and entries.is_empty():
		return false
	var ids: Dictionary = {}
	for raw_entry in entries:
		if not (raw_entry is LootTableEntry):
			return false
		var entry := raw_entry as LootTableEntry
		if not entry.is_valid():
			return false
		if ids.has(entry.module_id):
			return false
		ids[entry.module_id] = true
	if not allow_duplicates and drop_count > entries.size():
		return false
	return true

func get_invalid_reason() -> String:
	if loot_id == &"":
		return "掉落表 ID 不能为空。"
	if display_name.strip_edges().is_empty():
		return "掉落表名称不能为空。"
	if drop_count < 0:
		return "掉落数量不能为负数。"
	if drop_count > 0 and entries.is_empty():
		return "有掉落数量时掉落池不能为空。"
	var ids: Dictionary = {}
	for index in range(entries.size()):
		var raw_entry := entries[index]
		if not (raw_entry is LootTableEntry):
			return "第 %d 个掉落条目类型无效。" % (index + 1)
		var entry := raw_entry as LootTableEntry
		if not entry.is_valid():
			return "第 %d 个掉落条目：%s" % [index + 1, entry.get_invalid_reason()]
		if ids.has(entry.module_id):
			return "掉落模块 ID 重复：%s" % String(entry.module_id)
		ids[entry.module_id] = true
	if not allow_duplicates and drop_count > entries.size():
		return "禁止重复掉落时，掉落数量不能大于掉落池条目数。"
	return ""

func roll(seed_value: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_valid() or drop_count <= 0:
		return result
	var rng := RandomNumberGenerator.new()
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var pool: Array[LootTableEntry] = []
	for raw_entry in entries:
		pool.append(raw_entry as LootTableEntry)

	for _index in range(drop_count):
		if pool.is_empty():
			break
		var total_weight := 0.0
		for entry in pool:
			total_weight += entry.weight
		var roll_value := rng.randf_range(0.0, total_weight)
		var accumulated := 0.0
		var selected: LootTableEntry = pool.back()
		for entry in pool:
			accumulated += entry.weight
			if roll_value <= accumulated:
				selected = entry
				break
		result.append({
			"module_id": selected.module_id,
			"count": rng.randi_range(selected.min_count, selected.max_count),
			"rarity": selected.rarity,
			"rarity_label": selected.get_rarity_label()
		})
		if not allow_duplicates:
			pool.erase(selected)
	return result
