《前进四》game/ship/runtime 目录说明

用途：
- 存放进入实际游戏世界后运行的飞船实体。
- RuntimeShip 是 ShipData 在场景中的运行时表现，不重复保存另一套飞船结构数据。

当前文件：
- ship_runtime.tscn：运行时飞船场景。
- ship_runtime.gd：运行时飞船逻辑，负责持有 ShipData、绘制模块、速度、朝向、转向、推进、创建 WeaponRuntime / ProjectileRuntime，并为每个模块创建 ShipModuleRuntime。
- ship_module_runtime.gd：单个 ShipModuleInstance 的运行时受击对象，包含独立碰撞体和 DamageReceiver。
- SHIP_MODULE_RUNTIME_README.txt：模块运行时受击结构说明。

核心关系：
ShipData = 飞船结构与静态属性数据。
ShipRuntime = 使用 ShipData 在游戏场景中实际运行的 Node2D。

使用方式：
1. 从存档、预设或其他来源得到 ShipData。
2. 实例化 ship_runtime.tscn。
3. 调用 setup(ship_data)。
4. 控制器通过 set_control_input(throttle, turn) 提供推进与转向输入；玩家控制可使用 game/ship/controller/player_ship_controller.tscn。

职责边界：
- RuntimeShip 不读取 JSON，不负责存档。
- RuntimeShip 不硬编码玩家按键；当前 PlayerShipController 已通过统一接口驱动 RuntimeShip，后续 AI 也可复用同一接口。
- RuntimeShip 不复制 ShipData.modules；结构与模块属性始终以 ShipData 为数据来源。
- 当前包含模块绘制、移动、自动炮塔、Projectile，以及每模块独立碰撞 / HP / damaged / destroyed 事件。
- 当前武器模块 destroyed 会停用对应 WeaponRuntime；动力模块 destroyed 会从运行时有效推力中移除；能源模块 destroyed 会降低运行时有效供能；核心模块 destroyed 会让整个 RuntimeShip 从战斗场景移除。

飞船结构原则：
- 模块允许分开放置。
- 模块不要求相邻或连通。
- 网格不要求全部填满。
- RuntimeShip 按 ShipData 中保存的实际网格位置直接显示，不自动压缩或补齐空格。


移动规则：
- RuntimeShip 的 0° 舰首方向定义为屏幕上方 Vector2.UP。
- throttle > 0 时沿舰首方向推进。
- throttle < 0 时沿舰尾方向倒车，当前倒车推力为前进推力的 50%。
- turn < 0 左转，turn > 0 右转。
- 当前转向速度为基础运行参数，尚未由具体转向模块或质量分布计算。


运行时原点 / 旋转中心：
- RuntimeShip 的局部坐标原点固定使用核心模块（舰桥核心）的几何中心。
- setup(ship_data) 时根据核心模块 grid_position 与旋转后的尺寸计算 local_origin_offset。
- 所有模块绘制位置只在 RuntimeShip 中减去 local_origin_offset；ShipData.grid_position 不做任何修改。
- 因此 RuntimeShip.position 表示舰桥核心中心的世界坐标，RuntimeShip.rotation 也围绕舰桥核心中心旋转。
- has_core_origin() 用于确认当前 ShipData 是否成功找到核心模块。
- 模块即使彼此分离、存在空格，也不会改变这个原点规则。
- 如果传入的 ShipData 没有核心模块，Prototype 会回退到 Vector2.ZERO；正式可出航设计仍要求存在核心模块。
- 该中心是逻辑 / 运行时基准点，不等同于未来可能计算的物理质量中心。


武器运行时：
- setup(ship_data) 时会扫描 ShipData.modules，为每个 WeaponModuleDefinition 对应的模块创建一个 WeaponRuntime。
- WeaponRuntime 的局部位置取该模块几何中心，并使用与舰桥核心相同的 local_origin_offset 坐标换算。
- RuntimeShip.weapon_target_group 指定该飞船武器要搜索的目标组，默认 enemy_targets。
- WeaponRuntime 会独立搜索范围内最近目标、旋转炮塔并自动开火。
- request_fire() 继续保留为调试接口，可让当前所有 WeaponRuntime 各执行一次 fire_once()。
- ShipRuntime 通过 weapon_fired 信号向上转发单个武器的发射事件。
- get_weapon_count() 返回当前创建的 WeaponRuntime 总数量。
- get_operational_weapon_count() 只统计结构上仍存活、is_operational() == true 的武器，不考虑当前是否有电。
- get_active_weapon_count() 统计当前真正可工作的武器，即 is_active() == operational && powered。
- WeaponRuntime fired 后，RuntimeShip 会实例化 ProjectileRuntime。
- ProjectileRuntime 会加入 RuntimeShip 的父节点，而不是成为 RuntimeShip 子节点，因此发射后不会继续跟随飞船自身平移或旋转。
- RuntimeShip 提供 projectile_spawned 信号，用于观察弹丸生成。
- ProjectileRuntime 使用本帧 swept ray 选择弹道上最近碰撞；命中 ShipModuleRuntime 时优先调用 apply_projectile_damage()，其他支持 apply_damage() 的对象仍按普通命中处理。
- RuntimeShip 仍通过 projectile_hit(target, firepower) 向上转发命中事件，但该转发只用于观察 / 调试，不再负责实际扣血。
- RuntimeShip 创建 Projectile 时会把 self 作为 source_owner 传入，用于 Projectile 基础自伤过滤。
- 因为伤害由 ProjectileRuntime 自身处理，发射者 RuntimeShip 即使已因核心摧毁而 queue_free()，已经发射出去的 Projectile 仍可正常命中并造成伤害。

模块运行时：
- setup(ship_data) 时，RuntimeShip 会为每个 ShipModuleInstance 创建一个 ShipModuleRuntime。
- ShipModuleRuntime 的位置使用与模块绘制完全相同的核心原点坐标换算。
- 碰撞矩形大小等于模块旋转后的网格尺寸 × cell_size。
- 每个模块都有独立 DamageReceiver 和独立 HP。
- RuntimeShip.get_module_max_hp(module) 当前以 prototype_module_hp 为基础；DefenseModuleDefinition 额外把 protection 作为该块装甲自身的耐久加成，因此 armor max_hp = prototype_module_hp + protection。
- 模块之间允许空格；空格不会生成碰撞体。
- 模块 destroyed 后碰撞体会 deferred 禁用，RuntimeShip 将该模块绘制为深灰色。
- 防护模块采用“实体掩体”语义：Projectile 先撞到弹道上的前方装甲，装甲先吸收伤害。
- 如果本次 incoming_damage > 装甲当前 HP，装甲只吸收其剩余 HP，destroyed 后把 leftover = incoming_damage - hp_before 返回给 Projectile。
- Projectile 会携带 leftover 在同一弹道继续向内查询，因此高伤害弹丸可以在击穿低血量装甲后继续伤害后方模块。
- 如果装甲未被摧毁或刚好把伤害完全吃完，则 Projectile 在装甲处结束。
- 某一块装甲 destroyed 后，它自己的碰撞体失效；其他装甲仍保持独立保护。
- RuntimeShip 通过 module_damaged / module_destroyed 向上转发模块受击状态。
- 当前 prototype_module_hp = 20，尚未进入 Excel / ModuleDefinition。
- destroyed 不删除 ShipData.modules；运行时通过模块存活状态计算有效推力，并通过 UID 映射停用对应 WeaponRuntime。
- get_effective_energy_output() 只统计未 destroyed 的 EnergyModuleDefinition.energy_output。
- get_effective_energy_cost() 只统计未 destroyed 模块的 energy_cost。
- is_energy_sufficient() 表示当前有效供能是否足以覆盖全部存活模块耗能；供能不足并不再代表整船全部断电。
- module_powered_by_uid 保存每个存活模块当前是否获得供电。
- 当前 Prototype 固定供电优先级：核心 > 能源 > 动力 > 防护 > 功能 > 武器；同类型按 module.uid 升序稳定分配。
- RuntimeShip 会按优先级逐个尝试支付 module.definition.energy_cost；剩余能源不足以支付某个模块时，该模块 powered=false，但后续更低优先级、耗能更小的模块仍可能获得供电。
- get_powered_energy_cost() 返回当前实际已分配给 powered 模块的耗能；get_powered_module_count() 返回当前已供电模块数量。
- WeaponRuntime powered 状态来自其对应模块的 is_module_powered()，因此能源不足时只关闭未获供电的武器，而不是全部武器统一断电。
- get_effective_thrust() 只统计“未 destroyed 且已供电”的动力模块；get_effective_acceleration_score() = effective_thrust / 总质量。
- get_aim_point(from_world_position) 会从未 destroyed 的 ShipModuleRuntime 中选择距离炮塔最近的模块中心作为瞄准点。
- has_operational_modules() 用于让 WeaponRuntime 判断目标飞船是否还有可攻击模块。
- 核心模块 destroyed 时，RuntimeShip 会先发出 module_destroyed，再进入 removed_from_battle 状态。
- removed_from_battle 后会清零控制输入和速度、停用全部 WeaponRuntime、发出 destroyed 信号，并 queue_free() 从战斗场景移除。
- is_removed_from_battle() 可读取该状态；进入该状态后 has_operational_modules() 固定返回 false。
