《前进四》飞船 JSON 模板（2026-10-09）

正式位置：res://data/ships/templates/。
现有 enemy_scout.json、enemy_gunship.json 由 data/enemies/*.tres 的 ship_template_path 引用，描述 Hull Cells 和 Equipment 模块（ShipSerializer v3）。
玩家可写设计位于 user://ships/test_ship.json；这里的项目模板不会自动覆盖玩家存档，也尚未接入开局模板选择。

制作模板：在 Godot 编辑器中打开 res://game/ship/template_editor/ship_template_editor.tscn，按 F6 运行当前场景。使用 ShipGridView 放置 Hull / Equipment；填写仅含小写字母、数字、下划线的 ID，再保存。
- 仅设计合法的 ShipData 可保存。
- 保存已有 ID 与删除需经确认；覆盖前保存同名 .json.bak 备份（本地文件，Git 忽略）。
- 新建/加载时未保存修改会提示确认。
- “另存为”需要先输入未被占用的 ID。
- 模板删除操作确认后不可通过编辑器撤销；需要从 Git/已有备份恢复。
- 工具用于 Godot 开发环境，不应在发布游戏中写入 res://。

读取：ShipTemplateManager 管理模板列表/加载/保存/删除；EnemyShipFactory 通过 ShipSerializer 加载敌方模板。游戏内 ShipEditor / RunState 独立。
