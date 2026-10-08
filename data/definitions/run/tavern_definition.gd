class_name TavernDefinition
extends Resource

@export var tavern_id: StringName = &""
@export var display_name := "星际酒馆"
@export_range(1, 8) var candidate_count := 2
@export var recruit_pool: Array[StringName] = []

func is_valid() -> bool:
	if tavern_id == &"" or candidate_count < 1 or recruit_pool.size() < candidate_count:
		return false
	var db := preload("res://data/bridge/bridge_database.tres") as BridgeDatabase
	var seen := {}
	for id in recruit_pool:
		var crew := db.find_crew(id)
		if id == &"" or seen.has(id) or crew == null or crew.price <= 0:
			return false
		seen[id] = true
	return true
