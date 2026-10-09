《前进四》game/run — 当前流程（2026-10-09）

默认场景 game/run/route/route_map_screen.tscn，初次进入时自动建立 fixed_test_sector 固定测试路线：优先加载合法 user://ships/test_ship.json，否则采用 Battle.build_starter_design()。
RunState 位于 core/autoload/run_state.gd，保存 current_ship、路线、战斗快照、能量结晶、零件、仓库与战果。
battle_result/：胜利后统一结算、战利品带走/放弃和可选维修；game_over/：失败退出当前 Run。
route/：路线视图；shop/：能量结晶交易；station/：空间站维修和零件制造；tavern/：酒馆；warehouse/：仓库；ui/：通用窗口组件；dev/：回归。
胜利自动提交战果并进入结算页；失败清空本轮 Run。固定路线是当前默认测试模式，RouteMapGenerator.generate() 存在但非默认。
正式数据定义在 data/definitions/run、data/battles、data/routes 等目录。
