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
tools/data_source/game_data.xlsx

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
