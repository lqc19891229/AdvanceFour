《前进四》game/run 目录说明

职责：
负责一轮 Run 中跨战斗的战果展示、维修/整备入口与开发回归。

主要内容：
- battle_result/：战斗胜利后的结果页，显示 Credits、受损 Hull 列表、覆盖模块、效率变化与维修费用。
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


v0.33.0：
- 战果页只列出受损 Hull Cell，并显示损伤等级、坐标、HP、覆盖 Equipment 与单格维修费用。
- 选中 Hull 后显示对应 Equipment 当前效率，以及修复该格后的预计效率。
- 支持“维修此格”和“全部维修”两种方式。
- 单格维修只修改选中 ShipHullCell；其他 Hull 战损保持不变。
- 当前费用为 1 缺失 Hull HP = 1 Credit；Credits 不足时操作原子失败。
- Equipment 继续没有独立 HP，维修 Hull 即恢复其覆盖模块效率。
