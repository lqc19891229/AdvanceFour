《前进四》game/ship/editor — 玩家编辑器（2026-10-09）

ship_editor.tscn / ship_editor.gd：玩家设计及当前 Run 整备界面；ship_grid_view.gd：可复用 Hull/Equipment 网格绘制和操作。bridge/ 为船员芯片 UI。
游戏默认 F5 进入星图，非本编辑器。可单独 F6 运行此场景进行设计。
普通设计：允许自由铺 Hull/安装模块；永久设计保存为 user://ships/test_ship.json（ShipSerializer v3）。
Run 整备：由星图设置 run_refit_mode 进入，从 RunState.current_ship 载入并同步变更；安装/拆卸受 module_inventory 和 hull_stock 约束，移动/旋转免费。保存仅更新当前 Run，不覆盖永久设计。
操作：左键放置/选中，右键拆除，R 旋转，中键平移，滚轮缩放；设备必须完整覆盖 Hull，不得重叠；出航要求合法设计与足够供能。
另一个独立开发工具 game/ship/template_editor/ship_template_editor.tscn 负责正式 JSON 模板创作，不应将二者混用。
