extends HBoxContainer

@onready var title_label: Label = $TitlePanel/Title
@onready var energy_value: Label = $EnergyPanel/Content/Value
@onready var parts_value: Label = $PartsPanel/Content/Value

var full_heading := ""

func _ready() -> void:
	add_theme_constant_override("separation", 5)
	resized.connect(_update_compact_mode)
	_update_compact_mode()

func update_resources(energy: int, parts: int, heading: String) -> void:
	full_heading = heading
	energy_value.text = str(energy)
	parts_value.text = str(parts)
	_update_compact_mode()

func _update_compact_mode() -> void:
	# The resource counters are kept visible even when the title must be shortened.
	if size.x < 350.0:
		title_label.text = ""
	elif size.x < 620.0:
		title_label.text = "星区"
	elif size.x < 820.0:
		title_label.text = "星区 01 · 航线"
	else:
		title_label.text = full_heading if not full_heading.is_empty() else "星区 01 · 全息航线"
