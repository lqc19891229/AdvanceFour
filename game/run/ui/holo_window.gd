class_name HoloWindow
extends Control

signal close_requested

var content_host: Control
var title_label: Label
var window_panel: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.035, 0.065, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	window_panel = PanelContainer.new()
	window_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window_panel.anchor_left = 0.09
	window_panel.anchor_top = 0.08
	window_panel.anchor_right = 0.91
	window_panel.anchor_bottom = 0.92
	window_panel.offset_left = 0
	window_panel.offset_top = 0
	window_panel.offset_right = 0
	window_panel.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.12, 0.96)
	style.border_color = Color(0.22, 0.83, 0.98, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.0, 0.68, 1.0, 0.23)
	style.shadow_size = 18
	window_panel.add_theme_stylebox_override("panel", style)
	add_child(window_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	window_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var heading := HBoxContainer.new()
	layout.add_child(heading)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", Color(0.46, 0.9, 1.0))
	title_label.add_theme_font_size_override("font_size", 22)
	heading.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "离开"
	close_button.custom_minimum_size.x = 125
	close_button.pressed.connect(func(): close_requested.emit())
	heading.add_child(close_button)

	var separator := HSeparator.new()
	layout.add_child(separator)
	content_host = Control.new()
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(content_host)

func show_screen(screen: Control, title_text: String) -> void:
	title_label.text = title_text
	content_host.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := screen.get_node_or_null("Background") as CanvasItem
	if background != null:
		background.hide()
