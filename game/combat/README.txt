《前进四》game/combat 目录说明

职责：
负责正式战斗的“执行逻辑”：玩家/敌舰 Runtime 生成、波次调度、胜负判定、HUD、BattleResult 生成与退出。正式 Run 的跨场景状态由 core/autoload/run_state.gd 管理。

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


v0.32 Run 规则：
- 正式 Run 战斗从 RunState 的 battle_entry_ship 快照生成玩家飞船。
- 胜利先生成 pending BattleResult；玩家点击“结算并继续”后才提交战损与 Credits，避免 Retry 重复领取奖励。
- Retry 不提交 pending result，重新使用本场战前快照。
- Defeat 仅记录失败结果，不写回 current_ship。
- 独立 F6 / 开发测试在没有 active Run 时继续使用保存设计 / debug fallback。


v0.45.0：胜利提交后统一进入 game/run/battle_result/battle_result_screen.tscn。战利品处理和可选维修在同一页完成，不再先进入独立 Loot Screen；BattleResult 不再生成成长奖励候选。


v0.45.1：
- 删除 ResultOverlay 及 Retry / Continue / Return 结果按钮，不再显示战斗内胜利/失败确认弹窗。
- 正式场景胜利后在物理回调结束后自动提交一次结果并进入统一结算页；F6 战斗同样进入结算。
- 失败立即结束并清空 Run 的资源、仓库、路线与飞船，只保留结果摘要，再进入 game/run/game_over。
- 移除 R 重开。Game Over 只允许返回整备，恢复永久设计，不能继续失败的 Run。
- 配置/存档错误在 HUD 显示原因，仍可通过 Esc 返回。
