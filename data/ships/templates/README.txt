飞船模板目录

在 Godot 编辑器中打开 res://game/ship/template_editor/ship_template_editor.tscn 并运行当前场景 (F6)。
使用左侧船体与设备工具完成布局，在顶部输入模板 ID 后点击“保存”。

模板以 ShipSerializer 的 JSON 格式存入此目录，并与玩家存档 user://ships/test_ship.json 独立。
ID 只能包含小写英文、数字、下划线。
保存要求设计合法；加载后在画布修改再保存会覆盖同 ID 模板。
另存为必须先输入未使用的模板 ID。删除操作立即生效，请使用 Git 跟踪模板变更。

此工具只用于 Godot 编辑器开发环境，发布版不应提供模板文件写入。
现有游戏内 ShipEditor 和 RunState 保持不变。
