class_name BattleEncounterPool
extends RefCounted

# Discover exported encounter resources, including Excel-imported levels.
static func candidates(encounter_type: BattleDefinition.EncounterType, sector: StringName = &"sector_01", maximum_tier: int = 10) -> Array[String]:
	var result: Array[String] = []
	var root := DirAccess.open("res://data/battles")
	if root == null:
		return result
	var folders := root.get_directories()
	folders.sort()
	for folder in folders:
		var path := "res://data/battles/%s/battle.tres" % folder
		if not ResourceLoader.exists(path):
			continue
		var definition := load(path) as BattleDefinition
		if definition != null and definition.is_valid() and definition.encounter_type == encounter_type and definition.sector_id == sector and definition.difficulty_tier <= maximum_tier:
			result.append(path)
	return result


static func select(encounter_type: BattleDefinition.EncounterType, seed_value: int, sector: StringName = &"sector_01", maximum_tier: int = 10) -> String:
	var paths := candidates(encounter_type, sector, maximum_tier)
	if paths.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return paths[rng.randi_range(0, paths.size() - 1)]
