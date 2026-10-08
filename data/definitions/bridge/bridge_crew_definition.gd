class_name BridgeCrewDefinition
extends Resource

@export var crew_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var race: StringName = &"HUMAN"
@export var rarity: StringName = &"COMMON"
@export_range(0, 999999, 1) var price: int = 0
@export var portrait: Texture2D
@export var modifiers: Array[BridgeModifierDefinition] = []
