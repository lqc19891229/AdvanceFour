《前进四》game/ship/controller 目录说明

用途：
- 存放“谁在控制飞船”的控制器逻辑。
- 控制器负责把玩家、AI 或其他来源的控制意图转换为 RuntimeShip 可接受的接口调用。
- RuntimeShip 本身不读取键盘输入。

当前文件：
- player_ship_controller.gd：玩家飞船控制器，读取 WASD / 方向键并调用 RuntimeShip.set_control_input(throttle, turn)。
- player_ship_controller.tscn：PlayerShipController 场景。

当前玩家操作：
- W / ↑：前进。
- S / ↓：倒车。
- A / ←：左转。
- D / →：右转。

核心关系：
PlayerShipController = 玩家输入来源。
RuntimeShip = 飞船运动执行者。
ShipData = 飞船结构与静态属性数据。

使用方式：
1. 实例化 RuntimeShip 并 setup(ship_data)。
2. 实例化 PlayerShipController。
3. 调用 controller.setup(runtime_ship)。
4. PlayerShipController 每帧读取玩家输入并调用 RuntimeShip.set_control_input()。

职责边界：
- PlayerShipController 不加载 JSON。
- PlayerShipController 不修改 ShipData。
- PlayerShipController 不计算飞船质量、推力、速度或旋转物理。
- RuntimeShip 不知道控制来源是玩家还是未来的 AI。
- clear_target() 会先将推进和转向输入归零，再解除目标。

飞船结构原则：
- 控制器不参与模块布局合法性。
- 模块仍允许分开放置，不要求相邻、连通或填满网格。
