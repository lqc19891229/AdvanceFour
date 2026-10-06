《前进四》game/combat/definitions 目录说明

用途：
保存正式关卡使用的 BattleDefinition 资源。
所有关卡复用 res://game/combat/battle.tscn；本目录只描述每场战斗的配置差异。

当前文件：
- stage_001.tres：第一场正式战斗配置，三波敌舰 [1, 1, 2]。

新增关卡规则：
1. 复制或新建一个 BattleDefinition .tres。
2. 设置稳定 battle_id、显示名称、波次数量、计时、生成半径与返回场景。
3. 上层关卡 / Run 系统把资源路径写入 SceneTree meta：battle_definition_path。
4. 切换到 res://game/combat/battle.tscn。
5. 不复制 battle.tscn，也不在 battle.gd 中为具体关卡写专用分支。

当前边界：
BattleDefinition 目前只负责单场战斗流程参数。
敌舰蓝图、每波敌舰组合、Boss、奖励与战后结果将在后续关卡系统中继续数据化。
