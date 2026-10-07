game/run/loot

职责：
- 战斗胜利后处理模块战利品。
- 固定模块奖励不会在 commit_victory() 时直接进入仓库。
- 玩家逐件选择“带走”或“放弃”，全部处理后进入 Battle Result Screen。

规则：
- 带走前调用 RunState.can_take_loot() / can_store_module() 检查仓储容量。
- 带走成功后立即写入 module_inventory。
- 放弃只标记该战利品已处理，不改变仓库。
- 容量不足不会自动删除已有模块。
- 全部战利品处理完成前，不允许继续路线。
