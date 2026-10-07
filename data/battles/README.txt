《前进四》data/battles 目录说明

职责：
按“战斗配置包”保存具体 BattleDefinition 与对应 LootTable。

目录约定：
data/battles/<battle_id>/
├─ battle.tres
└─ loot.tres

当前：
- stage_001/battle.tres：第一场正式战斗配置；引用同目录 loot.tres。
- stage_001/loot.tres：第一战模块掉落表。
- stage_002/battle.tres：第二场正式战斗配置；引用同目录 loot.tres。
- stage_002/loot.tres：第二战模块掉落表。
- elite_001/battle.tres：第一场精英战配置；3 波共 12 艘敌舰，220 Credits。
- elite_001/loot.tres：精英战掉落表；抽取 4 件且不重复，高价值模块权重更高。

依赖：
- 数据结构：data/definitions/combat/
- 敌舰蓝图：data/enemies/
- 执行容器：game/combat/battle.tscn

原则：
1. BattleDefinition 决定“打什么”。
2. LootTableDefinition 决定“掉什么”。
3. battle.tres 与 loot.tres 保持独立 Resource，但放在同一个 battle_id 目录中。
4. 普通战 / 精英战 / Boss 不需要复制 Battle Runtime；通过各自 battle.tres + loot.tres 的数据差异表达。
5. 新增关卡时新增目录与数据，不在 battle.gd 写具体关卡分支。


v0.45.0：stage_001 移除成长奖励三选一配置；战后模块收益只由 loot.tres 或固定掉落清单决定。
