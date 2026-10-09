《前进四》正式敌舰生成与 AI（2026-10-09）

enemy_ship_factory.gd：从 EnemyShipDefinition.ship_template_path 指向的 res://data/ships/templates/*.json 经 ShipSerializer 加载 ShipData。
enemy_controller.gd：控制敌舰 ShipRuntime 的转向、前进和后退；接近/撤退距离来自 data/enemies/*.tres。
敌舰与玩家共享 game/ship/runtime/ship_runtime.gd、模块供能、局部 Hull 伤害与 WeaponRuntime。旧 EnemyRuntime 已删除，不能再引用。
