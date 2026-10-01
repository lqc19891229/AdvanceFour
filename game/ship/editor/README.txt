《前进四》game/ship/editor 目录说明

场景：
- ship_editor.tscn：飞船设计器主场景。

脚本：
- ship_editor.gd：编辑器 UI、模块选择、属性显示、保存/加载等控制逻辑。
- ship_grid_view.gd：网格绘制、鼠标放置/删除/旋转模块等编辑区交互。

当前操作：
- 左键：放置模块。
- 右键：删除模块。
- R：旋转待放置模块。
- 中键拖动：平移编辑区。
- 保存设计：保存到 user://ships/test_ship.json。
- 加载设计：从 user://ships/test_ship.json 恢复。
- 敌舰 AI 测试：先检查核心、模块及供能合法性，保存当前设计后进入 ship_ai_test.tscn。
- 从交火测试按 Esc 返回后自动恢复该设计；战斗中的模块损伤不会改写设计存档。
- 属性区域可滚动，避免长说明挤出操作按钮。

规则：
- 模块不能重叠。
- 模块之间不要求相邻或连通。
- 网格不要求全部填满。
- 编辑过程中允许临时能量不足；最终设计合法性再检查能源和核心模块。
- 模块按钮 tooltip 会显示该 ModuleDefinition 的 hp；hp 来自 Excel 数据链。
