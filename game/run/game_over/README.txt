game/run/game_over

职责：战斗失败后显示 GAME OVER，宣告本次航行结束。
文件：game_over_screen.gd/.tscn。
入口：Battle 在物理回调结束后自动跳转；跳转前 RunState.record_defeat() 已清空 Run，只留下 last_result 摘要。
界面：关卡、击毁数、波次、战斗时长；唯一按钮“返回整备”，恢复永久飞船设计。
规则：不发奖励，不允许维修、继续路线或重新挑战；R 不提供重开。
验证：game/combat/dev/combat_regression_test.gd 和 game/run/dev/run_regression_test.gd。
