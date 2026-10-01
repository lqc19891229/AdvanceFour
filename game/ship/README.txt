《前进四》game/ship 目录说明

用途：所有“飞船”相关的核心代码。

子目录：
- definitions/：模块定义 Resource 类，描述“某种模块是什么”。
- data/：ShipData、ModuleInstance、ModuleDatabase 等运行数据结构。
- editor/：玩家拼装飞船使用的编辑器场景与逻辑。
- runtime/：飞船进入实际游戏世界后的运行实体与基础行为。
- controller/：玩家、AI 等控制来源向 RuntimeShip 提供控制输入。
- weapon/：飞船武器模块对应的运行时节点与发射事件。
- projectile/：武器发射后进入世界空间独立飞行的弹丸运行时。
- damage/：通用 HP、受伤与 destroyed 运行时组件。
- dev/：仅服务于飞船系统的独立开发测试场景。

核心关系：
ModuleDefinition = 模块模板/静态定义
ModuleInstance   = 某艘船上安装的具体模块实例
ShipData         = 一艘飞船的结构数据
ShipRuntime      = ShipData 在游戏场景中的运行实体
PlayerShipController = 玩家输入到 RuntimeShip 控制接口的适配层
WeaponRuntime     = 单个武器模块进入游戏世界后的运行时执行对象
ProjectileRuntime = 武器发射后独立存在、飞行并按生命周期销毁的弹丸对象
DamageReceiver    = 接收数值伤害、维护 HP 并发出 damaged / destroyed 的运行时组件
ShipModuleRuntime = 单个 ShipModuleInstance 的运行时碰撞与 HP 对象


运行时规则：
- RuntimeShip 的局部原点与旋转中心使用核心模块的几何中心。
- 该规则只影响运行时显示与旋转，不修改 ShipData 中的模块网格坐标。


控制职责：
- RuntimeShip 负责执行移动，不读取玩家键盘。
- PlayerShipController 负责读取玩家输入并调用 RuntimeShip.set_control_input()。
- 后续 AIController 可以复用同一 RuntimeShip 控制接口。


武器运行时规则：
- RuntimeShip 根据 ShipData 中的 WeaponModuleDefinition 自动创建 WeaponRuntime。
- WeaponRuntime 使用模块自身 grid_position / rotation_quarters 与 RuntimeShip 核心原点建立炮塔初始位置和初始朝向。
- 炮塔进入战斗后可独立旋转，自动搜索攻击范围内最近敌人、瞄准并按冷却自动触发发射事件。
- rotation_quarters 不再锁死最终发射方向，只定义炮塔初始朝向。
- RuntimeShip 收到 WeaponRuntime fired 后创建 ProjectileRuntime，并将其作为飞船同级节点加入世界，使弹丸不继续继承飞船后续移动或旋转。
- ProjectileRuntime 负责直线飞行、生命周期、基础碰撞和 hit 事件；命中后销毁。
- DamageReceiver 独立负责 HP 与 destroyed 状态；Projectile 不直接持有目标 HP。
- RuntimeShip 会为每个模块创建独立 ShipModuleRuntime，因此 Projectile 命中对象可以直接对应到具体 ShipModuleInstance。
- 当前开发测试把 projectile_hit 的 firepower 直接作为该模块伤害。
- 模块 destroyed 当前只改变运行时碰撞 / 显示状态，不删除或修改 ShipData。
