《前进四》core/autoload 目录说明

文件：
- data_manager.gd
  功能：全局数据访问入口，负责读取 ModuleDatabase 等运行时数据库。
  用法：其他玩法代码通过 DataManager 查询模块定义，避免到处硬编码 Resource 路径。

- run_state.gd
  功能：当前 Roguelike Run 的跨场景状态，保存 current_ship、战前快照、Credits、完成关卡和最近 BattleResult。
  规则：胜利提交战损；失败不提交；Retry 使用 battle_entry_ship；战后维修通过 Hull Cell 缺失 HP 扣除 Credits。

  维修接口：
  - get_repair_cost_for_cell(position)：查询单格维修费用。
  - repair_cell(position)：维修单个 Hull Cell。
  - get_total_repair_cost() / repair_all()：查询并执行全部维修。
  - 当前维修价格：1 缺失 Hull HP = 1 Credit。

后续可能加入：
- save_manager.gd：局外永久存档。
- scene_manager.gd：统一场景切换。
