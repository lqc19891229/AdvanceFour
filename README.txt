《前进四 / ADVANCE FOUR》
Godot 4.6.1 · 模块化飞船战斗 / Roguelike 航线原型（2026-10-09）

【当前运行】
F5 默认启动 res://game/run/route/route_map_screen.tscn，不是飞船编辑器。
进入星图且尚未激活 Run 时：优先读取 user://ships/test_ship.json 的有效玩家设计，否则使用 Battle.build_starter_design()；建立固定测试航线 fixed_test_sector。随机路线生成器已有实现，但非默认入口。
战斗胜利自动进入统一结算（战利品、资源、可选维修），失败结束并清空本轮 Run。
局内能量结晶用于商店交易，零件用于维修与空间站制造。

【游戏定位】
设计 Hull 船体布局、安装 Equipment 模块，驾驶自制飞船参与实时战斗，并通过路线节点收集资源和改装。玩家与敌舰均使用 ShipData + ShipRuntime：船体格独立受伤，能源、引擎与炮塔随布局和战损改变表现。敌舰的身份/AI 配置在 data/enemies/；布局在 data/ships/templates/。

【两个编辑器】
玩家设计/局内整备：res://game/ship/editor/ship_editor.tscn；Run 整备模式读写 RunState.current_ship，安装受库存限制。
开发者独立模板工具：res://game/ship/template_editor/ship_template_editor.tscn，Godot 编辑器中 F6 单独运行；模板 JSON 放 data/ships/templates，需合法设计方可保存。覆盖/删除需确认，覆盖前保留本地 .json.bak；不影响玩家存档。
当前尚无开局模板选择，星图仍优先使用 user://ships/test_ship.json。

【文档导航】
PROJECT_STATUS.txt：当前完成项、入口与未完成范围。
PROJECT_STRUCTURE.txt：实际目录/数据流/职责。
WORKFLOW.txt：开发、导入和回归验证流程。
VERSION_HISTORY.txt：历史版本更新记录，按历史保留。
各目录 README.txt：只说明对应目录职责、文件和依赖。

【验证】
python3 tools/verify_project.py --godot /path/to/godot
CI 配置：.github/workflows/project-checks.yml。

【规划方向（尚非全部实现）】
完整 Roguelike、更多模块与文明科技、Boss、持久解锁、丰富动态航线。规划不等于当前已实现功能。
