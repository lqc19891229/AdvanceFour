class_name BattleEncounterPool
extends RefCounted

# Encounter selection is independent of route topology and battle runtime.
const NORMAL_PATHS: Array[String] = [
	"res://data/battles/stage_001/battle.tres",
	"res://data/battles/stage_002/battle.tres",
	"res://data/battles/test_normal/battle.tres"
]
const ELITE_PATHS: Array[String] = [
	"res://data/battles/elite_001/battle.tres",
	"res://data/battles/test_elite/battle.tres"
]

static func candidates(encounter_type: BattleDefinition.EncounterType, sector: StringName = &"sector_01", maximum_tier: int = 10) -> Array[String]:
	var result: Array[String] = []
	var paths: Array[String] = ELITE_PATHS if encounter_type == BattleDefinition.EncounterType.ELITE else NORMAL_PATHS if encounter_type == BattleDefinition.EncounterType.NORMAL else []
	for path in paths:
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
