《前进四》data/enemies — 当前说明（2026-10-09）

这里保存敌舰身份和 AI 行为配置（EnemyShipDefinition 的 .tres），不是直接保存船体格或设备布局。
- scout.tres：侦察舰；ship_template_path 指向 res://data/ships/templates/enemy_scout.json。
- gunship.tres：炮舰；ship_template_path 指向 res://data/ships/templates/enemy_gunship.json。
- approach_distance / retreat_distance 控制接近与后退距离。
- 飞船 Hull/Equipment、设备安装坐标、rotation 在 JSON 模板 modules 数组中定义；当前模板武器 rotation 为 0（不是旧 README 的 3）。

生成流程：BattleWaveDefinition → EnemyShipDefinition → EnemyShipFactory → ShipSerializer → ShipData → ShipRuntime；移动意图由 game/enemy/enemy_controller.gd 提供，炮塔/供能/碰撞与玩家复用同一套运行时。
新增敌舰时应同时创建合法 JSON 模板并设置 .tres 的 ship_template_path；不能仅填写显示名称。不要将旧整体 HP、固定炮口及 EnemyRuntime 规则当成当前实现。
