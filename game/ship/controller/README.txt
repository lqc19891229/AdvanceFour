《前进四》game/ship/controller — 当前说明（2026-10-09）

- player_ship_controller.gd / .tscn：玩家 WASD/方向键 → ShipRuntime.set_control_input()。
- ai_ship_controller.gd / .tscn：通用飞船 AI/开发测试用控制器，按目标组追踪。
- 正式关卡敌舰使用 game/enemy/enemy_controller.gd（EnemyController），由 Battle 在敌舰 ShipRuntime 下实例化，结合 EnemyShipDefinition 的 approach_distance、retreat_distance 控制推进和转向。
- 玩家和敌舰的移动、供能和武器表现都由相同 ShipRuntime/WeaponRuntime 执行，控制器只提供方向与油门输入。
- 如需改正式敌舰的 AI 搜索/接近规则，请修改 game/enemy/ 而非误改本目录的 AIShipController。
