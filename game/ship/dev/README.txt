《前进四》game/ship/dev 目录说明

用途：
- 存放仅服务于飞船系统的独立开发测试场景，不属于正式游戏流程。
- 飞船相关测试优先放在本目录，而不是放到 res:// 根级 dev/。

当前测试：
- ship_movement_test.tscn：读取 user://ships/test_ship.json，并实例化 RuntimeShip 做最小移动验证。
- ship_movement_test.gd：只负责读取测试输入、加载 ShipData、创建 RuntimeShip 和显示测试信息。

职责说明：
- 飞船绘制、速度、朝向、转向与自身朝向推进逻辑位于 game/ship/runtime/ship_runtime.gd。
- dev 测试不再维护另一套飞船运动实现。

使用：
1. 在飞船编辑器中点击“保存设计”。
2. 单独运行 res://game/ship/dev/ship_movement_test.tscn。
3. 使用 W / ↑ 前进，S / ↓ 倒车，A / ← 左转，D / → 右转。

飞船结构原则：
- 模块可以分开放置。
- 模块不要求相邻或连通。
- 格子不要求全部填满。
- 仍然禁止模块占用格重叠。
