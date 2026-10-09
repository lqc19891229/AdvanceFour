extends Control
## Godot-only authoring tool. Does not access RunState or player saves.

const DATABASE := preload("res://data/modules/module_database.tres")

var grid: ShipGridView
var template_list: ItemList
var template_id_input: LineEdit
var status_label: Label
var module_list: VBoxContainer
var stats_label: Label
var confirmation: ConfirmationDialog
var pending_action := ""
var loaded_template_id := ""
var pending_navigation := ""
var pending_template_id := ""
var dirty := false


func _ready() -> void:
	_build_ui()
	_refresh_template_list()
	_reset_design()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)

	var title := Label.new()
	title.text = "飞船模板编辑器（开发工具）"
	title.custom_minimum_size.x = 220
	toolbar.add_child(title)

	template_id_input = LineEdit.new()
	template_id_input.placeholder_text = "模板 ID，例如 starter_scout"
	template_id_input.custom_minimum_size.x = 230
	toolbar.add_child(template_id_input)

	_add_button(toolbar, "新建", _new_design)
	_add_button(toolbar, "加载", _load_selected)
	_add_button(toolbar, "保存", _save_design)
	_add_button(toolbar, "另存为", _save_as_design)
	_add_button(toolbar, "删除", _delete_selected)

	var content := HSplitContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 245
	content.add_child(sidebar)

	var templates_title := Label.new()
	templates_title.text = "模板列表（点击选择）"
	sidebar.add_child(templates_title)

	template_list = ItemList.new()
	template_list.custom_minimum_size.y = 170
	template_list.item_selected.connect(_on_template_selected)
	sidebar.add_child(template_list)
	_add_button(sidebar, "刷新模板列表", _refresh_template_list)

	var modules_title := Label.new()
	modules_title.text = "设备 / 船体"
	sidebar.add_child(modules_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(scroll)
	module_list = VBoxContainer.new()
	module_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(module_list)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(center)

	var help := Label.new()
	help.text = "左键放置/选择 · 右键拆除 · R 旋转 · 中键拖动画布 · 滚轮缩放"
	center.add_child(help)

	grid = ShipGridView.new()
	grid.module_database = DATABASE
	grid.set_run_inventory_enabled(false)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size = Vector2(500, 360)
	grid.ship_changed.connect(_update_stats)
	grid.status_message.connect(_show_status)
	center.add_child(grid)

	stats_label = Label.new()
	center.add_child(stats_label)

	status_label = Label.new()
	status_label.text = "仅在 Godot 编辑器内写入项目模板；不会修改当前 Run。"
	root.add_child(status_label)

	confirmation = ConfirmationDialog.new()
	confirmation.confirmed.connect(_confirm_pending_action)
	add_child(confirmation)
	_build_module_buttons()


func _ask_confirmation(message: String, action: String) -> void:
	pending_action = action
	confirmation.dialog_text = message
	confirmation.popup_centered()


func _confirm_pending_action() -> void:
	var action := pending_action
	pending_action = ""
	match action:
		"overwrite":
			_commit_save(pending_template_id)
		"delete":
			_commit_delete(pending_template_id)
		"new":
			_reset_design()
		"load":
			_commit_load(pending_navigation)


func _reset_design() -> void:
	loaded_template_id = ""
	template_id_input.text = ""
	grid.set_ship(ShipData.new())
	dirty = false
	_show_status("已新建空白设计。")


func _add_button(parent: Node, label: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.pressed.connect(handler)
	parent.add_child(button)


func _build_module_buttons() -> void:
	_add_button(module_list, "基础船体格", grid.select_hull)
	for definition in DATABASE.modules:
		if definition == null:
			continue
		_add_button(
			module_list,
			"%s · %s" % [definition.get_type_name(), definition.display_name],
			grid.select_definition.bind(String(definition.id))
		)


func _new_design() -> void:
	if dirty:
		_ask_confirmation("当前设计有未保存修改。确定放弃并新建？", "new")
		return
	_reset_design()


func _refresh_template_list() -> void:
	template_list.clear()
	for template_id in ShipTemplateManager.list_template_ids():
		template_list.add_item(template_id)


func _on_template_selected(index: int) -> void:
	template_id_input.text = template_list.get_item_text(index)


func _load_selected() -> void:
	var template_id := template_id_input.text.strip_edges()
	if dirty:
		pending_navigation = template_id
		_ask_confirmation("当前设计有未保存修改。确定放弃并加载模板？", "load")
		return
	_commit_load(template_id)


func _commit_load(template_id: String) -> void:
	var result := ShipTemplateManager.load_template(template_id)
	if not result["ok"]:
		_show_status("加载失败：" + String(result["error"]))
		return
	grid.set_ship(result["ship"] as ShipData)
	loaded_template_id = template_id
	dirty = false
	_show_status("已加载模板：" + template_id)


func _save_design() -> void:
	_save_with_id(template_id_input.text.strip_edges(), false)


func _save_as_design() -> void:
	# Enter a new ID in the field before clicking '另存为'.
	_save_with_id(template_id_input.text.strip_edges(), true)


func _save_with_id(template_id: String, require_new: bool) -> void:
	var path := ShipTemplateManager.get_template_path(template_id)
	if path.is_empty():
		_show_status("请填写合法模板 ID（小写英文、数字、下划线）。")
		return
	if require_new and FileAccess.file_exists(path):
		_show_status("另存为失败：此 ID 已存在，请填写一个新 ID。")
		return
	if FileAccess.file_exists(path):
		pending_template_id = template_id
		_ask_confirmation("将覆盖已有模板 %s。确定继续？" % template_id, "overwrite")
		return
	_commit_save(template_id)


func _commit_save(template_id: String) -> void:
	var result := ShipTemplateManager.save_template(template_id, grid.ship)
	if not result["ok"]:
		_show_status("保存失败：" + String(result["error"]))
		return
	loaded_template_id = template_id
	dirty = false
	_refresh_template_list()
	_show_status("已保存模板：" + ShipTemplateManager.get_template_path(template_id))


func _delete_selected() -> void:
	var template_id := template_id_input.text.strip_edges()
	if not FileAccess.file_exists(ShipTemplateManager.get_template_path(template_id)):
		_show_status("模板不存在：" + template_id)
		return
	pending_template_id = template_id
	_ask_confirmation("确定永久删除模板 %s？" % template_id, "delete")


func _commit_delete(template_id: String) -> void:
	var result := ShipTemplateManager.delete_template(template_id)
	if not result["ok"]:
		_show_status("删除失败：" + String(result["error"]))
		return
	_refresh_template_list()
	if loaded_template_id == template_id:
		_reset_design()
	_show_status("已删除模板：" + template_id)


func _update_stats() -> void:
	if stats_label == null or grid == null:
		return
	dirty = true
	var ship := grid.ship
	var status := "可出航" if ship.is_design_valid() else ship.get_design_invalid_reason()
	stats_label.text = "船体格：%d · 设备：%d · 校验：%s" % [
		ship.get_hull_cells().size(), ship.modules.size(), status
	]


func _show_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
