《前进四》game/combat — 当前说明（2026-10-09）

battle.tscn / battle.gd 是共享战斗容器；battle_backdrop.gd 是战斗背景，dev/ 保存回归。
数据：data/battles/<battle_id>/battle.tres 定义战斗；BattleWaveDefinition 引用 data/enemies/*.tres；后者经 EnemyShipFactory 从 data/ships/templates/*.json 加载 ShipData。玩家/敌舰使用同一 ShipRuntime，但敌人由 EnemyController 驱动。
玩家进入正式 Run 战斗时使用 RunState 的战前快照，胜利自动提交一次结果、进入 game/run/battle_result 统一结算；失败结束并清空本轮 Run，转 game/run/game_over。没有战斗内 Retry 或等待玩家点击胜利确认的旧流程。
独立 F6 战斗可采用有效本地设计或允许的 debug 默认设计。显式 BattleDefinition 配置无效时显示错误，而不是静默替换关卡。
新增关卡优先新增 data/battles/<id>/battle.tres，不复制战斗场景；新增敌舰优先新增 .tres 身份配置和 JSON 模板。
