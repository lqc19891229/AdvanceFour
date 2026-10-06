《前进四》data/enemies 目录说明

职责：
保存具体 EnemyShipDefinition 敌舰蓝图实例。

当前：
- scout.tres
- gunship.tres

依赖：
- EnemyShipDefinition：data/definitions/combat/
- ModuleDatabase / ModuleDefinition：data/definitions/module/ + data/modules/
- 实际战斗执行：game/combat/

原则：
这里描述“敌舰由什么模块组成”；AI、武器、移动等运行行为仍属于 game。
