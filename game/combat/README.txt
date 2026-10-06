《前进四》game/combat 目录说明

职责：
负责正式战斗的“执行逻辑”：玩家/敌舰 Runtime 生成、波次调度、胜负判定、HUD、结算与退出。

主要文件：
- battle.gd / battle.tscn：所有关卡复用的正式战斗容器。
- battle_backdrop.gd：战斗世界背景。
- dev/：战斗开发与回归测试。

数据依赖：
- BattleDefinition / BattleWaveDefinition / EnemyShipDefinition：
  res://data/definitions/combat/
- 敌舰蓝图：
  res://data/enemies/
- 战斗关卡配置：
  res://data/battles/
- 飞船与模块数据定义：
  res://data/definitions/
- 模块具体数据：
  res://data/modules/

原则：
1. game/combat 不保存具体关卡内容。
2. Battle 只执行 BattleDefinition，不在 battle.gd 中写第几关专用分支。
3. 新关卡新增 data/battles/*.tres，不复制 battle.tscn。
4. 新敌舰蓝图新增 data/enemies/*.tres。
5. Boss 行为若需要新 Gameplay 能力才进入 game；Boss 的具体配置继续放 data。
