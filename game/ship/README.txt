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
- ProjectileRuntime 命中支持 apply_damage() 的模块运行时后，会直接应用 firepower 伤害；RuntimeShip.projectile_hit 仅保留为命中事件转发。
- 模块 destroyed 不删除或修改 ShipData；运行时状态独立决定模块是否仍能提供功能。
- 武器模块 destroyed 后对应 WeaponRuntime 停火；动力模块 destroyed 后不再贡献有效推力；能源模块 destroyed 后不再贡献有效供能。
- 防护模块采用实体装甲 / 掩体规则，不是全船百分比减伤：protection 增加该块防护模块自己的最大 HP，弹丸只会命中弹道首先接触到的模块。
- 某一块装甲被摧毁后，只打开这一块对应的局部射击缺口；后续弹丸可以从该缺口继续攻击后方模块，其他仍存活装甲继续各自挡弹。
- RuntimeShip 使用存活模块计算有效供能 / 有效耗能；供能不足时按固定 Prototype 优先级 核心 > 能源 > 动力 > 防护 > 功能 > 武器 逐个供电，而不是整船统一断电。
- 只有获得供电的动力模块才贡献运行时有效推力；只有获得供电且未 destroyed 的武器模块才能工作。能源不足本身不会让飞船退出战斗。
- 自动炮塔会瞄准目标飞船距离自身最近的存活模块，而不是固定瞄准核心中心。
- 核心模块 destroyed 视为整艘飞船战斗失败：RuntimeShip 发出 destroyed，并通过 queue_free() 从当前战斗场景移除。
- 该战斗移除只销毁 RuntimeShip 节点，不改写 ShipData，也不删除设计中的模块结构。

- 已经发射的 Projectile 是独立世界节点，其伤害生效不依赖发射者 RuntimeShip 是否仍存活；发射者核心被摧毁并移除后，空中弹丸仍可继续造成伤害。
