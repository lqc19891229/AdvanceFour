《前进四》game — 玩法代码和场景（2026-10-09）

- combat/：共享战斗容器、波次、战果生成和测试。
- enemy/：敌方 EnemyController、EnemyShipFactory；敌舰自身也使用 game/ship/runtime/ShipRuntime。
- ship/：玩家编辑器、独立模板编辑器、通用飞船运行时、外观、炮塔、弹丸、控制器和飞船回归。
- run/：星图、商店、空间站、酒馆、仓库、战果、Game Over、运行时 UI 和回归。
- progression/：舰船数值修正。

当前默认项目入口为 game/run/route/route_map_screen.tscn。正式数据及素材在 data/，跨场景 RunState 在 core/，源表/导入/验证在 tools/。
