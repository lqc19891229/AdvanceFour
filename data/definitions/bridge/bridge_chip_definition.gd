class_name BridgeChipDefinition
extends Resource

@export var chip_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: StringName = &"COMMON"
@export var icon: Texture2D
@export var modifiers: Array[BridgeModifierDefinition] = []
