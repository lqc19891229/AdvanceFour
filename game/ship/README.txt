《前进四》game/ship 目录说明

用途：所有“飞船”相关的核心代码。

子目录：
- definitions/：模块定义 Resource 类，描述“某种模块是什么”。
- data/：ShipData、ModuleInstance、ModuleDatabase 等运行数据结构。
- editor/：玩家拼装飞船使用的编辑器场景与逻辑。
- runtime/：飞船进入实际游戏世界后的运行实体与基础行为。
- controller/：玩家、AI 等控制来源向 RuntimeShip 提供控制输入。
- dev/：仅服务于飞船系统的独立开发测试场景。

核心关系：
ModuleDefinition = 模块模板/静态定义
ModuleInstance   = 某艘船上安装的具体模块实例
ShipData         = 一艘飞船的结构数据
ShipRuntime      = ShipData 在游戏场景中的运行实体
PlayerShipController = 玩家输入到 RuntimeShip 控制接口的适配层


运行时规则：
- RuntimeShip 的局部原点与旋转中心使用核心模块的几何中心。
- 该规则只影响运行时显示与旋转，不修改 ShipData 中的模块网格坐标。


控制职责：
- RuntimeShip 负责执行移动，不读取玩家键盘。
- PlayerShipController 负责读取玩家输入并调用 RuntimeShip.set_control_input()。
- 后续 AIController 可以复用同一 RuntimeShip 控制接口。
