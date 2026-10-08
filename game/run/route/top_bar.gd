extends HBoxContainer
@onready var title_label: Label = $TitlePanel/Title
@onready var energy_value: Label = $EnergyPanel/Content/Value
@onready var parts_value: Label = $PartsPanel/Content/Value

func _ready() -> void:
	add_theme_constant_override("separation", 8)

func update_resources(energy: int, parts: int, heading: String) -> void:
	title_label.text = heading
	energy_value.text = str(energy)
	parts_value.text = str(parts)
