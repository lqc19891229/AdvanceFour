【当前实现｜2026-10｜Godot 4.6.1】
项目主入口 res://game/run/route/route_map_screen.tscn；默认固定测试航线：商店→空间站→普通战→精英战→终点。RouteMapGenerator.generate() 可生成随机图，但不是当前默认入口。
RunState 维护能量结晶（交易）、零件（维修/制造）、模块仓储、战损和路线节点状态；胜利自动进入统一战果页，失败清空 Run。
含版本号的旧行为仅用于版本追溯。

game/run/game_over

职责：战斗失败后显示 GAME OVER，宣告本次航行结束。
文件：game_over_screen.gd/.tscn。
入口：Battle 在物理回调结束后自动跳转；跳转前 RunState.record_defeat() 已清空 Run，只留下 last_result 摘要。
界面：关卡、击毁数、波次、战斗时长；唯一按钮“返回整备”，恢复永久飞船设计。
规则：不发奖励，不允许维修、继续路线或重新挑战；R 不提供重开。
验证：game/combat/dev/combat_regression_test.gd 和 game/run/dev/run_regression_test.gd。
