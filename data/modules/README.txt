【当前代码说明｜2026-10】
Godot 4.6.1；入口为 route_map_screen.tscn，默认固定测试航线，随机地图 RouteMapGenerator.generate() 尚非默认。
现行货币：能量结晶用于商店；零件用于 Hull 维修、空间站制造。胜利自动统一结算，失败清空 Run。
以下历史版本记录仅供追溯。

《前进四》data/modules 目录说明

职责：
保存游戏 Runtime 使用的具体模块 Resource 与 ModuleDatabase。

结构：
- energy/
- propulsion/
- weapon/
- defense/
- function/
- core/
- module_database.tres

来源：
tools/data_source/module_data.xlsx

生成流程：
tools/import/import_excel.py
→ tools/cache/modules.json
→ addons/advance_four_data_importer
→ 本目录对应类型的 .tres
→ module_database.tres

规则：
1. 本目录按“模块类型”组织，不使用 generated 子目录。
2. 模块 .tres 与 module_database.tres 当前由导入流程生成，原则上不手工修改。
3. 模块类型定义位于 data/definitions/module/。
4. 模块 Runtime 正式素材位于 data/assets/modules/。
