《前进四》core/autoload 目录说明

文件：
- data_manager.gd
  功能：全局数据访问入口，负责读取 ModuleDatabase 等运行时数据库。
  用法：其他玩法代码通过 DataManager 查询模块定义，避免到处硬编码 Resource 路径。

- run_state.gd
  功能：当前 Roguelike Run 的跨场景状态，保存 current_ship、战前快照、Credits、完成关卡和最近 BattleResult。
  规则：胜利提交战损；失败不提交；Retry 使用 battle_entry_ship。

后续可能加入：
- save_manager.gd：局外永久存档。
- scene_manager.gd：统一场景切换。
