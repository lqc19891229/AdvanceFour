《前进四》core/autoload 目录说明

文件：
- data_manager.gd
  功能：全局数据访问入口，负责读取 ModuleDatabase 等运行时数据库。
  用法：其他玩法代码通过 DataManager 查询模块定义，避免到处硬编码 Resource 路径。

后续可能加入：
- game_manager.gd：当前 Run、流程状态等。
- save_manager.gd：存档读写。
- scene_manager.gd：统一场景切换。
