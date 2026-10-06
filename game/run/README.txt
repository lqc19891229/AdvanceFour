《前进四》game/run 目录说明

职责：
负责一轮 Run 中跨战斗的战果展示、维修/整备入口与开发回归。

主要内容：
- battle_result/：战斗胜利后的结果页，显示 Credits、Hull 战损与维修费用。
- dev/run_regression_test.gd：验证战损持久化、Retry 战前恢复、跨关卡继承、奖励与维修。

状态来源：
- core/autoload/run_state.gd

当前流程：
Ship Editor
→ start_run
→ Battle
→ Victory
→ BattleResult
→ Result Screen
→ Repair / Refit / Next Battle

边界：
- game/run 不定义具体关卡内容。
- BattleDefinition 与 BattleResult 数据结构属于 data。
- 当前 Run 状态属于 core/autoload/RunState。
- 永久设计模板仍由 ShipSerializer 写入 user://ships/test_ship.json。


v0.32.1：
- 有 next_battle_path 时显示“下一战”。
- 当前最终战没有 next_battle_path 时显示“结束 Run 并返回设计器”。
- 结束 Run 会清空 RunState，并恢复永久设计模板进入 Ship Editor。
- 同一个 battle_id 的 Victory 不能重复 commit，防止重复领取 Credits。
