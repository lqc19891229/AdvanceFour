《前进四》game/ship/runtime 目录说明

用途：
- 存放进入实际游戏世界后运行的飞船实体。
- RuntimeShip 是 ShipData 在场景中的运行时表现，不重复保存另一套飞船结构数据。

当前文件：
- ship_runtime.tscn：运行时飞船场景。
- ship_runtime.gd：运行时飞船逻辑，负责持有 ShipData、绘制模块、速度与基础移动。

核心关系：
ShipData = 飞船结构与静态属性数据。
ShipRuntime = 使用 ShipData 在游戏场景中实际运行的 Node2D。

使用方式：
1. 从存档、预设或其他来源得到 ShipData。
2. 实例化 ship_runtime.tscn。
3. 调用 setup(ship_data)。
4. 控制器通过 set_move_input(direction) 提供移动意图。

职责边界：
- RuntimeShip 不读取 JSON，不负责存档。
- RuntimeShip 不硬编码玩家按键，因此以后玩家控制器和 AI 都可以驱动同一个 RuntimeShip。
- RuntimeShip 不复制 ShipData.modules；结构与模块属性始终以 ShipData 为数据来源。
- 当前第一版只包含模块绘制和基础平移，暂不包含旋转、武器、伤害与模块失效。

飞船结构原则：
- 模块允许分开放置。
- 模块不要求相邻或连通。
- 网格不要求全部填满。
- RuntimeShip 按 ShipData 中保存的实际网格位置直接显示，不自动压缩或补齐空格。
