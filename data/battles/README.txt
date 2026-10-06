《前进四》data/battles 目录说明

职责：
保存具体 BattleDefinition 关卡实例。

当前：
- stage_001.tres：第一场正式战斗配置；胜利奖励 100 Credits，下一战 stage_002。
- stage_002.tres：第二场正式战斗配置；胜利奖励 150 Credits，当前为 Run 末端。

依赖：
- 数据结构：data/definitions/combat/
- 敌舰蓝图：data/enemies/
- 执行容器：game/combat/battle.tscn

原则：
新增关卡只新增/组合数据，不复制 battle.tscn，不在 battle.gd 写具体关卡分支。
