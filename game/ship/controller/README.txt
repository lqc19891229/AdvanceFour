【当前实现说明｜2026-10】
Godot 4.6.1；主场景为 game/run/route/route_map_screen.tscn，目前默认进入 fixed_test_sector 测试航线。
正式运行资源为能量结晶（商店）与零件（维修及空间站制造）。战斗胜利进入统一结算，失败清空本轮 Run。
以下早期版本说明仅作历史留档。

《前进四》game/ship/controller 目录说明

用途：
- 存放“谁在控制飞船”的控制器逻辑。
- 控制器负责把玩家、AI 或其他来源的控制意图转换为 RuntimeShip 可接受的接口调用。
- RuntimeShip 本身不读取键盘输入。

当前文件：
- player_ship_controller.gd：玩家飞船控制器，读取 WASD / 方向键并调用 RuntimeShip.set_control_input(throttle, turn)。
- player_ship_controller.tscn：PlayerShipController 场景。
- ai_ship_controller.gd / .tscn：敌舰控制器，搜索 target_group 中最近有效 ShipRuntime，以同一 set_control_input 接口追踪并保持距离。

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
4. PlayerShipController 在 _physics_process() 中按物理帧读取玩家输入并调用 RuntimeShip.set_control_input()。

职责边界：
- PlayerShipController 不加载 JSON。
- PlayerShipController 不修改 ShipData。
- PlayerShipController 不计算飞船质量、推力、速度、旋转物理、武器瞄准或武器伤害。
- 武器自动选敌、自动瞄准和自动开火由 WeaponRuntime 独立负责。
- RuntimeShip 不知道控制来源是玩家还是 AI。
- PlayerShipController 与 RuntimeShip 都使用物理帧更新控制/运动，避免控制采样与运动执行处于不同帧循环。
- setup(new_runtime_ship) 重新绑定到不同飞船前，会先将旧 RuntimeShip 的推进和转向输入归零，避免旧飞船保留最后一次控制输入。
- clear_target() 会先将推进和转向输入归零，再解除目标。

飞船结构原则：
- 控制器不参与模块布局合法性。
- 模块仍允许分开放置，不要求相邻、连通或填满网格。

AI 使用：
1. 实例化 RuntimeShip 并 setup(ship_data)，再将 AIShipController 作为其子节点添加并 setup(runtime_ship)。
2. 将玩家 RuntimeShip 加入 player_targets；敌舰 weapon_target_group 也设为 player_targets。
3. AI 默认 target_group = player_targets，acquisition_range = 1600；目标失效、离组或超出范围后重新搜索最近存活目标。
4. 与目标舰桥中心距离大于 280 时前进，小于 180 时倒车，中间停止推进；偏角大于 60° 时先转向。
5. AI 在物理帧优先级 -10 提供控制，RuntimeShip 按有效推力执行移动；AI 不自行移动节点、不修改模块数据，也不负责炮塔开火。
6. 没有目标时推进和转向归零；重新绑定、clear_target() 和退出场景也清理控制。
7. 距离、角度是当前 Prototype 参数；尚无障碍规避、编队或正式阵营规则。
