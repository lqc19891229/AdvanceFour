《前进四》game/combat/enemies 目录说明

用途：
保存正式战斗使用的 EnemyShipDefinition 敌舰蓝图。
Battle 不再自行拼装固定敌舰；关卡波次引用这里的蓝图资源。

当前蓝图：
- scout.tres：侦察舰，轻量基础敌舰。
- gunship.tres：炮舰，双引擎双机炮。

EnemyShipDefinition 当前描述：
- enemy_id
- display_name
- module_ids
- module_positions
- module_rotations

运行时由 EnemyShipDefinition.build_design(ModuleDatabase) 构建 ShipData。
蓝图必须生成合法飞船，否则 Battle 进入 ERROR，不静默替换为其他敌舰。
