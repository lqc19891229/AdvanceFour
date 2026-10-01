《前进四》game/ship/runtime 目录说明

用途：
- 存放进入实际游戏世界后运行的飞船实体。
- RuntimeShip 是 ShipData 在场景中的运行时表现，不重复保存另一套飞船结构数据。

当前文件：
- ship_runtime.tscn：运行时飞船场景。
- ship_runtime.gd：运行时飞船逻辑，负责持有 ShipData、绘制模块、速度、朝向、转向、基于自身朝向的推进，以及创建和管理 WeaponRuntime，并把武器 fired 事件转换为 ProjectileRuntime。

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
- 当前包含模块绘制、速度、朝向、基础转向、基于舰首方向的推进、核心中心原点，以及自动炮塔 WeaponRuntime、ProjectileRuntime 生成和命中事件转发；暂不包含伤害与模块失效。

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
- get_weapon_count() 返回当前创建的 WeaponRuntime 数量。
- WeaponRuntime fired 后，RuntimeShip 会实例化 ProjectileRuntime。
- ProjectileRuntime 会加入 RuntimeShip 的父节点，而不是成为 RuntimeShip 子节点，因此发射后不会继续跟随飞船自身平移或旋转。
- RuntimeShip 提供 projectile_spawned 信号，用于观察弹丸生成。
- ProjectileRuntime 命中后会发出 hit(target, firepower)，RuntimeShip 再通过 projectile_hit(target, firepower) 向上转发。
- RuntimeShip 创建 Projectile 时会把 self 作为 source_owner 传入，用于 Projectile 基础自伤过滤。
- 当前 Projectile 已包含基础碰撞 / 命中事件，但不应用伤害。
