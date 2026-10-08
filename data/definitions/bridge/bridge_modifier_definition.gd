class_name BridgeModifierDefinition
extends Resource

@export var stat: StringName = &""
@export_enum("FLAT", "PERCENT_ADD", "MULTIPLIER") var operation: String = "PERCENT_ADD"
@export var value: float = 0.0
@export var target_filter: StringName = &""
