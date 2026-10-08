extends Button
signal route_selected(node_id: StringName)
var route_node_id: StringName

func configure(node: RunRouteNodeDefinition, visited: bool, selectable: bool, current: bool) -> void:
	route_node_id = node.node_id
	var elite := node.node_type == RunRouteNodeDefinition.NodeType.BATTLE and (String(node.node_id).contains("elite") or node.target_path.contains("elite"))
	var tint := Color("#52caff")
	var symbol := "✦"
	match node.node_type:
		RunRouteNodeDefinition.NodeType.SHOP:
			tint = Color("#ffad4d")
			symbol = "▣"
		RunRouteNodeDefinition.NodeType.REFIT:
			tint = Color("#60eaff")
			symbol = "+"
		RunRouteNodeDefinition.NodeType.END:
			tint = Color("#ff6473")
			symbol = "◆"
		RunRouteNodeDefinition.NodeType.BATTLE:
			symbol = "⚔"
			if elite:
				tint = Color("#ff6676")
	disabled = not selectable
	var state := "✓" if visited else "▶" if selectable else "·"
	text = "%s  %s\n%s" % [symbol, node.display_name, state]
	tooltip_text = node.get_type_label()
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("#0b1b33")
	skin.border_color = tint if selectable else tint.darkened(0.42)
	skin.set_border_width_all(4)
	skin.set_corner_radius_all(1)
	skin.content_margin_left = 6
	skin.content_margin_right = 6
	skin.shadow_color = Color(tint.r, tint.g, tint.b, 0.3 if selectable else 0.06)
	skin.shadow_size = 5 if selectable else 1
	add_theme_stylebox_override("normal", skin)
	add_theme_stylebox_override("disabled", skin)
	var hover := skin.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#173854")
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_color_override("font_color", tint)
	add_theme_color_override("font_disabled_color", tint.darkened(0.3))
	add_theme_color_override("font_hover_color", Color.WHITE)

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	route_selected.emit(route_node_id)
