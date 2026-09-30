《前进四》game/ship 目录说明

用途：所有“飞船”相关的核心代码。

子目录：
- definitions/：模块定义 Resource 类，描述“某种模块是什么”。
- data/：ShipData、ModuleInstance、ModuleDatabase 等运行数据结构。
- editor/：玩家拼装飞船使用的编辑器场景与逻辑。

核心关系：
ModuleDefinition = 模块模板/静态定义
ModuleInstance   = 某艘船上安装的具体模块实例
ShipData         = 一艘飞船的结构数据
