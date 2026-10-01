《前进四》game/ship/runtime 目录说明

用途：
- 存放进入实际游戏世界后运行的飞船实体。
- RuntimeShip 是 ShipData 在场景中的运行时表现，不重复保存另一套飞船结构数据。

当前文件：
- ship_runtime.tscn：运行时飞船场景。
- ship_runtime.gd：运行时飞船逻辑，负责持有 ShipData、绘制模块、速度、朝向、转向与基于自身朝向的推进。

核心关系：
ShipData = 飞船结构与静态属性数据。
ShipRuntime = 使用 ShipData 在游戏场景中实际运行的 Node2D。

使用方式：
1. 从存档、预设或其他来源得到 ShipData。
2. 实例化 ship_runtime.tscn。
3. 调用 setup(ship_data)。
4. 控制器通过 set_control_input(throttle, turn) 提供推进与转向输入。

职责边界：
- RuntimeShip 不读取 JSON，不负责存档。
- RuntimeShip 不硬编码玩家按键，因此以后玩家控制器和 AI 都可以驱动同一个 RuntimeShip。
- RuntimeShip 不复制 ShipData.modules；结构与模块属性始终以 ShipData 为数据来源。
- 当前包含模块绘制、速度、朝向、基础转向和基于舰首方向的推进；暂不包含武器、伤害与模块失效。

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
- 所有模块绘制位置只在 RuntimeShip 中减去该 origin_offset；ShipData.grid_position 不做任何修改。
- 因此无论核心位于编辑网格的哪个位置，RuntimeShip.position 都表示舰桥核心中心的世界坐标。
- RuntimeShip.rotation 也围绕舰桥核心中心旋转。
- 如果传入的 ShipData 没有核心模块，Prototype 会回退到原始网格原点 Vector2.ZERO；正式可出航设计仍要求存在核心模块。
- 该中心是逻辑 / 运行时基准点，不等同于未来可能计算的物理质量中心。
