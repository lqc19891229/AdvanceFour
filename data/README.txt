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
- battles/：具体关卡战斗配置。

原则：
1. data 按“内容类型”分类，不按“生成方式”分类。
2. 不再使用 data/generated。
3. 自动生成的模块资源直接写入 data/modules 对应类型目录。
4. 自动生成属性由 README / 导入工作流说明，不通过 generated 目录表达。
5. game 只引用 data 下的正式运行时数据与素材。
6. tools 保存策划源数据与生产/验证工具，不保存美术素材副本，也不作为 Runtime 数据源。
7. PNG、音频等游戏素材只在 data/assets 保留唯一一份正式文件。
