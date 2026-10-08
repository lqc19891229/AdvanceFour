【当前代码索引（2026-10）】
工程版本：Godot 4.6.1；启动：res://game/run/route/route_map_screen.tscn。
默认星图为 fixed_test_sector 功能测试航线；随机星图使用 RouteMapGenerator.generate()，目前不是默认启动流程。
能量结晶用于商店，零件用于 Hull 维修和空间站制造；胜利进入统一结算，失败重置当前 Run。
本文件后续的历史版本描述应按版本阅读，当前行为以对应脚本及配置为准。

《前进四》data 目录说明

职责：
data 保存游戏运行时需要加载和理解的“正式内容”，回答“游戏里有什么数据、这些数据是什么”。

子目录：
- definitions/：运行时数据结构定义。
  - module/：ModuleDefinition 各类型与 ModuleDatabase 类型。
  - ship/：ShipData、ShipHullCell、ShipModuleInstance、ShipSerializer。
  - combat/：BattleDefinition、BattleWaveDefinition、EnemyShipDefinition。
- assets/：Godot Runtime 正式加载素材。
- modules/：具体模块 .tres 与 module_database.tres。
- enemies/：具体敌舰蓝图资源。
- battles/：按 battle_id 组织的战斗配置包；每个目录包含 battle.tres 与 loot.tres。

原则：
1. data 按“内容类型”分类，不按“生成方式”分类。
2. 不再使用 data/generated。
3. 自动生成的模块资源直接写入 data/modules 对应类型目录。
4. 自动生成属性由 README / 导入工作流说明，不通过 generated 目录表达。
5. game 只引用 data 下的正式运行时数据与素材。
6. tools 保存策划源数据与生产/验证工具，不保存美术素材副本，也不作为 Runtime 数据源。
7. PNG、音频等游戏素材只在 data/assets 保留唯一一份正式文件。

8. Battle 与 Loot 数据按同一 battle_id 目录归档；资源职责仍保持分离。
