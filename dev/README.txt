《前进四》dev 目录说明

用途：
- 存放独立开发测试场景，不属于正式游戏流程。

当前测试：
- ship_movement_test.tscn：读取 user://ships/test_ship.json，并用 ShipData 的质量、推力和推重比做最小移动验证。
- ship_movement_test.gd：测试场景控制与简单模块绘制。

使用：
1. 在飞船编辑器中点击“保存设计”。
2. 单独运行 res://dev/ship_movement_test.tscn。
3. 使用 WASD 或方向键移动。

飞船结构原则：
- 模块可以分开放置。
- 模块不要求相邻或连通。
- 格子不要求全部填满。
- 仍然禁止模块占用格重叠。
