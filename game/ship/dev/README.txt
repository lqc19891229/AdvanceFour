《前进四》game/ship/dev 目录说明

用途：
- 存放仅服务于飞船系统的独立开发测试场景，不属于正式游戏流程。
- 飞船相关测试优先放在本目录，而不是放到 res:// 根级 dev/。

当前测试：
- ship_movement_test.tscn：读取 user://ships/test_ship.json，并实例化 RuntimeShip 做移动、朝向和武器运行时最小验证。
- ship_movement_test.gd：负责加载 ShipData、创建玩家 RuntimeShip、创建第二艘 RuntimeShip 作为模块受击目标、绑定 PlayerShipController，以及显示测试信息。
- weapon_target_dummy.gd：保留的通用 DamageReceiver 测试目标；当前 ship_movement_test 的主要目标已改为第二艘 RuntimeShip。

职责说明：
- 飞船绘制、速度、朝向、转向、自身朝向推进与核心中心旋转原点逻辑位于 game/ship/runtime/ship_runtime.gd。
- 玩家键盘输入逻辑位于 game/ship/controller/player_ship_controller.gd。
- 武器运行时逻辑位于 game/ship/weapon/weapon_runtime.gd，由 RuntimeShip 根据 ShipData 自动创建。
- 弹丸运行时逻辑位于 game/ship/projectile/projectile_runtime.gd；RuntimeShip 在武器 fired 后生成 ProjectileRuntime。
- 通用 HP / 受伤逻辑位于 game/ship/damage/damage_receiver.gd。
- dev 测试不再维护另一套飞船运动或玩家输入实现。

使用：
1. 在飞船编辑器中点击“保存设计”。
2. 单独运行 res://game/ship/dev/ship_movement_test.tscn。
3. 测试场景会实例化 PlayerShipController 并绑定 RuntimeShip。
4. 使用 W / ↑ 前进，S / ↓ 倒车，A / ← 左转，D / → 右转。
5. 场景会在玩家右上方创建第二艘 RuntimeShip，并将其加入 enemy_targets。
6. 玩家炮塔会自动选择目标飞船距离自身最近的存活模块中心进行瞄准并发射 Projectile。
7. 目标飞船每个模块都拥有独立 ShipModuleRuntime 碰撞体与独立 HP。
8. Projectile 命中哪个模块，就对哪个 ShipModuleRuntime 调用 apply_damage(firepower)。
9. 武器模块 HP 归零后，对应 WeaponRuntime 停止工作；动力模块 HP 归零后，目标飞船 effective_thrust 下降。
10. 核心模块 HP 归零后，目标 RuntimeShip 发出 destroyed 并 queue_free()，视作从战斗场景被移除。
11. 已摧毁模块不再作为瞄准点，炮塔会继续转向其他存活模块；核心 destroyed 后整船直接退出目标集合。
12. HUD 会显示目标可用武器数量、有效推力、整船移除事件、模块受伤 / 摧毁事件、最近模块 HP 和伤害值。

飞船结构原则：
- 模块可以分开放置。
- 模块不要求相邻或连通。
- 格子不要求全部填满。
- 仍然禁止模块占用格重叠。
