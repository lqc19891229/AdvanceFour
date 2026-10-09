《前进四》模板管理器（2026-10-09）

ship_template_manager.gd 提供模板 ID 校验、列表、加载、保存、删除。资源目录为 res://data/ships/templates/，格式为 ShipSerializer v3 JSON。
写入/删除仅允许 Godot 编辑器环境，且设计保存需通过 is_design_valid()；覆盖旧模板会备份为 .json.bak。
UI 确认与未保存修改提醒由 game/ship/template_editor/ship_template_editor.gd 负责。
