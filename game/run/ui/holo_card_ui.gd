class_name HoloCardUI
extends RefCounted

const CYAN := Color("#67dbf4")
const BORDER := Color("#287e9e")
const PANEL := Color("#10293b")

static func style_card(panel: PanelContainer, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#174257") if selected else PANEL
	style.border_color = CYAN if selected else BORDER
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(4)
	if selected:
		style.shadow_color = Color(0.13, 0.78, 1.0, 0.22)
		style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)

static func make_details() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Details"
	panel.custom_minimum_size.x = 320
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	style_card(panel, false)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "选择项目查看详情"
	heading.add_theme_color_override("font_color", CYAN)
	heading.add_theme_font_size_override("font_size", 21)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	var description := Label.new()
	description.name = "Description"
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	var action := Button.new()
	action.name = "Action"
	action.custom_minimum_size.y = 48
	action.text = "选择左侧项目"
	action.disabled = true
	column.add_child(action)
	return panel

static func show_details(panel: PanelContainer, heading: String, description: String, button_text: String, can_act: bool, action_callback: Callable) -> void:
	var column := panel.get_node("MarginContainer/Column") as VBoxContainer
	var title := column.get_node("Heading") as Label
	var info := column.get_node("Description") as Label
	var button := column.get_node("Action") as Button
	title.text = heading
	info.text = description
	button.text = button_text
	button.disabled = not can_act
	for connection in button.pressed.get_connections():
		button.pressed.disconnect(connection["callable"])
	if can_act:
		button.pressed.connect(action_callback)
	var tween := panel.create_tween()
	panel.modulate.a = 0.65
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
