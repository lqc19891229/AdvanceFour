《前进四》game/ship/dev 目录说明

用途：
- 存放仅服务于飞船系统的独立开发测试场景，不属于正式游戏流程。
- 飞船相关测试优先放在本目录，而不是放到 res:// 根级 dev/。

当前测试：
- ship_movement_test.tscn：读取 user://ships/test_ship.json，并实例化 RuntimeShip 做移动、朝向和武器运行时最小验证。
- ship_movement_test.gd：负责加载 ShipData、创建 RuntimeShip、创建并绑定 PlayerShipController、放置自动瞄准测试目标，以及显示测试信息。
- weapon_target_dummy.gd：武器自动瞄准 / Projectile 命中 / DamageReceiver 测试目标，自动加入 enemy_targets 组，提供 Area2D 圆形碰撞体和测试 HP。

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
5. 场景会在飞船附近创建白色十字圆测试目标；炮塔应自动转向目标并按冷却自动触发 fired。
6. fired 后应从炮塔世界位置生成白色 Projectile；Projectile 命中白色十字圆后应立即销毁并产生 hit 事件。
7. 测试层收到 projectile_hit 后，把 firepower 直接作为伤害调用目标 apply_damage()。
8. 测试目标默认 HP = 20；HP 归零后发出 destroyed 并 queue_free()。
9. 如果没有命中目标，Projectile 会在生命周期结束后自动销毁。
10. HUD 会显示弹丸命中、伤害事件、目标 HP、目标摧毁事件和最近伤害数值。

飞船结构原则：
- 模块可以分开放置。
- 模块不要求相邻或连通。
- 格子不要求全部填满。
- 仍然禁止模块占用格重叠。
