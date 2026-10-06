《前进四》game/combat/definitions 目录说明

用途：
保存正式关卡使用的 BattleDefinition 资源。
所有关卡复用 res://game/combat/battle.tscn；本目录只描述每场战斗的配置差异。

当前文件：
- stage_001.tres：第一场正式战斗配置。
  - Wave 1：侦察舰 ×2
  - Wave 2：侦察舰 ×1 + 炮舰 ×1
  - Wave 3：炮舰 ×2

关卡数据结构：
BattleDefinition
→ waves: BattleWaveDefinition[]
→ enemies: EnemyShipDefinition[]
→ counts

新增关卡规则：
1. 新建一个 BattleDefinition .tres。
2. 为每个波次建立 BattleWaveDefinition，并引用 game/combat/enemies 下的敌舰蓝图。
3. 设置稳定 battle_id、显示名称、计时、生成半径与返回场景。
4. 上层关卡 / Run 系统把资源路径写入 SceneTree meta：battle_definition_path。
5. 切换到 res://game/combat/battle.tscn。
6. 不复制 battle.tscn，也不在 battle.gd 中为具体关卡写专用分支。
7. 显式 battle_definition_path 加载失败必须进入 ERROR；不会回退到 stage_001。

当前边界：
普通敌舰蓝图与波次敌舰组合已数据化。
Boss 行为、奖励与战后结果将在后续系统中继续扩展。
