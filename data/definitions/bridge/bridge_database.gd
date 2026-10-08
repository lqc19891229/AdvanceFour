class_name BridgeDatabase
extends Resource

@export var chips: Array[BridgeChipDefinition] = []
@export var crew: Array[BridgeCrewDefinition] = []
@export var configs: Array[BridgeConfigDefinition] = []

func find_chip(id: StringName) -> BridgeChipDefinition:
    for item in chips:
        if item != null and item.chip_id == id:
            return item
    return null

func find_crew(id: StringName) -> BridgeCrewDefinition:
    for item in crew:
        if item != null and item.crew_id == id:
            return item
    return null
