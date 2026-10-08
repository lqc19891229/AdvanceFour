【当前代码索引（2026-10）】
工程版本：Godot 4.6.1；启动：res://game/run/route/route_map_screen.tscn。
默认星图为 fixed_test_sector 功能测试航线；随机星图使用 RouteMapGenerator.generate()，目前不是默认启动流程。
能量结晶用于商店，零件用于 Hull 维修和空间站制造；胜利进入统一结算，失败重置当前 Run。
本文件后续的历史版本描述应按版本阅读，当前行为以对应脚本及配置为准。
模块数据源：tools/data_source/module_data.xlsx → tools/cache/modules.json → Godot Data Importer → data/modules。

《前进四》addons 目录说明

用途：Godot 编辑器插件。

当前插件：
- advance_four_data_importer/：Excel -> JSON -> .tres 模块数据导入工具。
