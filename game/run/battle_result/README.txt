game/run/battle_result

职责：战斗胜利后的统一结算页，处理战利品、仓储容量、资源收益与可选维修。
文件：battle_result_screen.gd/.tscn；ship_damage_snapshot.gd。
状态：只读取 RunState.last_result/current_ship；take_loot/discard_loot 与 repair_cell/repair_all 负责状态变更。
交互：左侧逐件带走/放弃；右侧真实飞船布局。选格查看 HP、模块效率与维修费用，维修后立即刷新。
快照：复用正式 Hull Tile 与模块底座/炮塔；黄/红/暗红显示轻伤/重伤/摧毁。滚轮缩放、中键拖动、双击居中。
规则：未处理战利品阻止商店/整备/下一战/返回星图/结束 Run。维修可跳过。成长奖励三选一已移除。
布局：宽屏分栏、窄屏纵排；整页和战利品列表均可滚动。
验证：game/run/dev/run_regression_test.gd，统一入口 tools/verify_project.py。
