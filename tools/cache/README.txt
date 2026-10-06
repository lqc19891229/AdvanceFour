《前进四》tools/cache 目录说明

职责：
保存内容导入流程的中间缓存，不是游戏 Runtime 的正式数据源。

当前：
- modules.json：由 tools/import/import_excel.py 根据 game_data.xlsx 生成。

正式运行时模块资源位于 data/modules/。
