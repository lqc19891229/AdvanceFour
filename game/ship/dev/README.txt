《前进四》game/ship/dev 目录说明

用途：
- 存放仅服务于飞船系统的独立开发测试场景，不属于正式游戏流程。
- 飞船相关测试优先放在本目录，而不是放到 res:// 根级 dev/。

当前测试：
- ship_ai_test.gd / .tscn：敌舰 AI 双向交火测试；读取已保存设计，未找到存档时使用数据库中的示例模块构造测试船；存在但损坏 / 非法的存档会明确提示修正，不静默替换。
- ship_regression_test.gd：Godot 无界面回归入口，验证 AI 移动、选敌与失效目标、数据驱动 HP、动力摧毁、显式最高速度、松油减速、双向实际命中、核心移除、HUD 及编辑器往返。
- ship_movement_test.tscn：读取 user://ships/test_ship.json，并实例化 RuntimeShip 做移动、朝向和武器运行时最小验证。
- ship_movement_test.gd：负责加载 ShipData、创建玩家 RuntimeShip、创建第二艘 RuntimeShip 作为模块受击目标、绑定 PlayerShipController，以及显示测试信息。
- weapon_target_dummy.gd：保留的通用 DamageReceiver 测试目标；当前 ship_movement_test 的主要目标已改为第二艘 RuntimeShip。

职责说明：
- 飞船绘制、速度、朝向、转向、自身朝向推进与核心中心旋转原点逻辑位于 game/ship/runtime/ship_runtime.gd；最高速度 / 加速度 / 减速度统一由有效推重比与 RuntimeShip 的 scale 参数计算。
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
8. Projectile 每个物理帧沿本帧路径做 swept ray，按弹道最近顺序命中 ShipModuleRuntime；命中模块时调用 apply_projectile_damage(remaining_damage)。
9. 防护模块作为实体装甲：protection 是每次命中该 Defense 模块时生效的百分比减伤值，protection = 5 即减伤 5%，不增加 max HP，也不会被消耗。
10. Defense 命中先计算 damage_after_protection = incoming_damage * (1 - clamp(protection, 0, 100) / 100)，再对模块 HP 造成伤害；非 Defense 模块 protection = 0。
11. 任意 ShipModuleRuntime 如果被本次伤害摧毁且 damage_after_protection > hp_before，则 leftover = damage_after_protection - hp_before；同一发 Projectile 会继续携带 leftover 沿同一弹道向后命中下一模块。
12. 武器模块 HP 归零后，对应 WeaponRuntime 停止工作；动力模块 HP 归零后，目标飞船 effective_thrust 下降。
13. 能源模块 HP 归零后，effective_energy_output 下降；若供能不足，则按 核心 > 能源 > 动力 > 防护 > 功能 > 武器 的 Prototype 优先级逐个为存活模块供电。
14. 未获供电的动力模块不贡献 effective_thrust；未获供电的武器停止搜索、瞄准和开火。
15. 核心模块 HP 归零后，目标 RuntimeShip 发出 destroyed 并 queue_free()，视作从战斗场景被移除；造成核心摧毁的 Projectile 会立即结束，不再继续命中该船其他模块。
16. 已摧毁模块不再作为瞄准点，炮塔会继续转向其他存活模块；核心 destroyed 后整船直接退出目标集合。
17. HUD 会分别显示目标可用武器（active）、存活武器（operational）与总武器数量，并显示有效推力、有效供能 / 总需求、实际已供电耗能、已供电模块数量、能源状态、整船移除事件、模块受伤 / 摧毁事件、最近模块 HP、protection 百分比减伤和伤害值。
18. 已经发射的 Projectile 即使其 source_owner 后续因核心摧毁被移除，仍会按发射时记录的射程继续飞行并在命中时造成伤害；每次 swept ray 会预先排除当前有效 source_owner 节点树中的所有 CollisionObject2D，避免自身模块逐个占用 max_impacts_per_step；每个物理帧的路径长度使用 min(speed * max(delta, 0), distance_remaining)，最后一帧的射线及穿透查询不会超出发射时 attack_range。

飞船结构原则：
- 模块可以分开放置。
- 模块不要求相邻或连通。
- 格子不要求全部填满。
- 仍然禁止模块占用格重叠。

AI 交火测试：
- 在编辑器点击“敌舰 AI 测试”，或单独 F6 运行 ship_ai_test.tscn。
- WASD / 方向键控制玩家，敌舰自动追踪；双方自动炮塔攻击另一组目标。
- R 重开测试，Esc 返回编辑器；玩家核心摧毁后相机留在场景中供查看结果。
- 敌舰目前复用玩家布局，运行时 HP 和供电状态彼此独立；没有奖励、波次或战后维修。

自动检查：
- 在项目根目录执行 python3 tools/verify_project.py --godot /path/to/godot。
- 使用 Godot 4.6.1，自动检查在临时用户目录运行；脚本错误即使引擎退出码为 0 也判为失败。
- GitHub Actions 在 PR 和 main 推送时运行同一检查。
- 射程回归覆盖边界内命中 / 边界外无伤害、穿透最后一帧、单步命中上限、速度变化、开火参数快照、发射者移动 / 旋转 / 销毁、超过旧 2 秒寿命、大坐标和零射程 / 零速度退场。
