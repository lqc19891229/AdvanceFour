class_name BridgeChipDefinition
extends Resource

@export var chip_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: StringName = &"COMMON"
@export_range(0, 999999, 1) var price: int = 0
@export var icon: Texture2D
@export var modifiers: Array[BridgeModifierDefinition] = []
