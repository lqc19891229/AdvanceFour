《前进四》独立飞船模板编辑器（2026-10-09）

ship_template_editor.tscn + ship_template_editor.gd 是 Godot 开发环境可 F6 运行的独立场景，复用 game/ship/editor/ship_grid_view.gd。
可创建、加载、保存、另存为和删除模板；覆盖/删除前需确认，新建/加载时提醒未保存内容。模板写入 res://data/ships/templates/*.json（仅编辑器环境），覆盖前生成 .json.bak。
不修改 RunState.current_ship，也不覆盖 user://ships/test_ship.json。发布游戏时不提供修改 res:// 的功能。
