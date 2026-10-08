【当前实现说明｜2026-10】
Godot 4.6.1；项目默认从星图主场景进入 fixed_test_sector 测试航线；生成式星图由 RouteMapGenerator.generate() 实现。
双资源：能量结晶用于商店，零件用于维修及空间站制造。胜利自动统一结算、失败清空 Run。
历史版本说明仅供追溯；当前执行流程以脚本及 .tres 为准。

《前进四》tools/cache 目录说明

职责：
保存内容导入流程的中间缓存，不是游戏 Runtime 的正式数据源。

当前：
- modules.json：由 tools/import/import_excel.py 根据 game_data.xlsx 生成。

正式运行时模块资源位于 data/modules/。
