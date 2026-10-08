【当前实现说明｜2026-10】
Godot 4.6.1；项目默认从星图主场景进入 fixed_test_sector 测试航线；生成式星图由 RouteMapGenerator.generate() 实现。
双资源：能量结晶用于商店，零件用于维修及空间站制造。胜利自动统一结算、失败清空 Run。
历史版本说明仅供追溯；当前执行流程以脚本及 .tres 为准。

《前进四》game/ship/runtime 目录说明

用途：
- 存放 ShipData 进入战斗世界后的运行表现。
- 当前飞船结构已拆为 Hull Layout + Equipment。

当前文件：
- ship_runtime.tscn / ship_runtime.gd：整艘飞船运行逻辑。
- hull_cell_runtime.gd：单个 ShipHullCell 的运行时碰撞与受击对象。
- ship_module_runtime.gd：Equipment 的运行时视觉对象；不再持有独立 HP。
- SHIP_MODULE_RUNTIME_README.txt：Hull / Equipment 受击职责说明。

核心关系：
ShipData
├─ hull_cells -> HullCellRuntime
└─ modules    -> ShipModuleRuntime / WeaponRuntime

Hull 运行时：
- RuntimeShip 为每个 ShipHullCell 创建一个 HullCellRuntime。
- 每个 Hull Cell 使用独立 Area2D / CollisionShape2D。
- Projectile swept ray 命中 HullCellRuntime 后调用 RuntimeShip.apply_hull_projectile_damage()。
- 区域有效最大 HP = ShipHullCell.max_hp + 覆盖 Defense.hp；damage_after_protection 按区域有效 HP 换算到 Hull Cell.current_hp。
- 若伤害超过该区域剩余有效 HP，leftover 继续由 Projectile 沿原弹道穿透。
- Hull Cell HP = 0 后对应碰撞体失效，空出的射线可继续命中后方 Hull。
- get_aim_point() 从仍存活的 Hull Cell 中选择距离攻击者最近的位置。

Equipment 运行时：
- ShipModuleRuntime 只负责 Equipment 基础贴图和受损亮度表现。
- 除 Defense 外 Equipment 没有 hp；Defense.hp 作为所在 Hull 区域的附加耐久，不维护独立 DamageReceiver。
- RuntimeShip.get_module_efficiency(module) 读取该 Equipment 覆盖的全部 Hull Cell。
- efficiency = 覆盖 Hull health ratio 的平均值，范围 0~1。
- efficiency = 0 表示承载该 Equipment 的 Hull 全部损毁，Equipment 失效。
- 多格 Equipment 会随着不同 Hull Cell 受损逐步降低效率。

当前效率影响：
- Energy：energy_output × efficiency。
- Propulsion：thrust × efficiency。
- Defense：protection × efficiency；当前作为整船主动防御系统计算。
- Weapon：
  - firepower × efficiency；
  - turret turn speed × efficiency；
  - fire interval / efficiency，因此效率下降会降低射速。
- Equipment 的 energy_cost 在其仍 operational 时保持定义值；完全失效后不再计入有效耗能。

供电：
- 有效能源输出先考虑 Energy Equipment 的 Hull efficiency。
- 供能不足时继续使用 Prototype 优先级：
  核心 > 能源 > 动力 > 防护 > 功能 > 武器。
- 未供电动力不贡献推力；未供电武器停止工作。

核心 / 沉没：
- Core 仍属于 Equipment。
- Core 本身没有独立 HP。
- Core 覆盖 Hull Cell 全部损毁，使 Core efficiency = 0。
- 此时 RuntimeShip 发出 destroyed 并退出当前战斗。

移动：
- Equipment 不再拥有 mass。
- 当前移动完全不读取 Hull mass。
- 最高速度 = effective_thrust × speed_scale。
- 加速度 = effective_thrust × acceleration_scale。
- 松油减速度 = effective_thrust × deceleration_scale。
- 当前 speed_scale = 2.5、acceleration_scale = 1.0、deceleration_scale = 1.5。
- reverse_thrust_ratio = 0.5。
- Hull 战损通过降低 Propulsion efficiency 间接降低 effective_thrust，因此同步降低最高速度和加减速能力。

运行时原点：
- 仍以 Core Equipment 几何中心作为 RuntimeShip 局部原点。
- Hull Layout 与 Equipment 的 grid_position 均不因运行时原点而改写。

视觉：
- RuntimeShip 不再直接绘制 Hull 方格；战斗外观交给 ShipAppearanceRenderer。
- ShipAppearanceRenderer 读取同一份 ShipData.hull_cells，以四方向邻接生成连续舰体 shell，并随 Hull health ratio 显示局部破损。
- ShipModuleRuntime 只显示 Core / Weapon / Propulsion；Energy / Defense / Function 在战斗中被 shell 包覆。
- Weapon base 属于 ShipModuleRuntime，turret 属于 WeaponRuntime，并使用更高 z_index。
- 编辑器不使用该 Appearance Layer，仍显示完整 Hull + Equipment。

数据规则：
- ShipModuleDefinition 已移除 mass 与共通 hp。
- 只有 DefenseModuleDefinition 保留 hp。
- Defense.protection 继续作为减伤参数，与区域附加 hp 同时作用。
