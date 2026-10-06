《前进四》game/run/route 目录说明

职责：
负责当前 Run 的星图显示与路线节点选择。

当前：
- route_map_screen.tscn / route_map_screen.gd
- 根据 RunState.route_definition 动态绘制节点按钮与连接线。
- 已完成节点显示 ✓，当前节点显示 ●，可选下一节点显示 ▶。
- 只能选择 RunState.get_available_route_node_ids() 返回的合法下一节点。

节点执行：
- BATTLE → game/combat/battle.tscn
- SHOP → game/run/shop/shop_screen.tscn
- REFIT → game/ship/editor/ship_editor.tscn（Run Refit）
- END → 结束 Run 并返回飞船编辑器

边界：
- 节点结构和连接属于 data/routes。
- 星图只负责展示与导航，不保存独立 Run 状态。
