【当前代码索引（2026-10）】
工程版本：Godot 4.6.1；启动：res://game/run/route/route_map_screen.tscn。
默认星图为 fixed_test_sector 功能测试航线；随机星图使用 RouteMapGenerator.generate()，目前不是默认启动流程。
能量结晶用于商店，零件用于 Hull 维修和空间站制造；胜利进入统一结算，失败重置当前 Run。
本文件后续的历史版本描述应按版本阅读，当前行为以对应脚本及配置为准。
RunState 负责局内飞船、路线、经济、仓储、掉落与节点流转，需通过受验证的流程接口更新。

《前进四》core/autoload 目录说明

文件：
- data_manager.gd
  功能：全局数据访问入口，负责读取 ModuleDatabase 等运行时数据库。
  用法：其他玩法代码通过 DataManager 查询模块定义，避免到处硬编码 Resource 路径。

- run_state.gd
  功能：当前 Roguelike Run 的跨场景状态，保存 current_ship、战前快照、能量结晶、零件、完成关卡和最近 BattleResult。
  规则：胜利自动提交战损与奖励；失败立即 reset_run()，只保留 Game Over 所需 last_result；战后维修通过 Hull Cell 缺失 HP 扣除零件。
  Run Warehouse：module_inventory 保存模块仓库数量；模块按自身 size.x × size.y 计算仓储占用。hull_stock 独立保存，不计入模块仓储。
  Loot：has_pending_loot() 判断未处理战利品；take_loot(index) 检查容量并入库，discard_loot(index) 标记放弃。成长奖励三选一已移除。
  Shop：can_purchase_shop_item(item) 检查能量结晶；purchase_shop_item(item) 原子扣款并把商品内容写入 Run Inventory。
  Route：route_definition / current_route_node_id / completed_route_nodes 保存星系路线状态；start_run_with_route()、get_available_route_node_ids()、select_route_node()、complete_current_route_node() 负责节点推进。

  维修接口：
  - get_repair_cost_for_cell(position)：查询单格维修费用。
  - repair_cell(position)：维修单个 Hull Cell。
  - get_total_repair_cost() / repair_all()：查询并执行全部维修。
  - 当前维修价格：1 缺失 Hull HP = 1 零件。

后续可能加入：
- save_manager.gd：局外永久存档。
- scene_manager.gd：统一场景切换。


v0.37.1 Shop Node 状态：
- shop_node_states 保存每个商店节点的四槽商品与购买状态。
- get_shop_slots() 首次访问时生成四个无重复商品，之后保持固定。
- purchase_shop_slot() 按槽购买并标记 SOLD；重复购买与资金不足均失败且不改变状态。
- reset_run() 会清空全部商店节点状态。


v0.38.0 Warehouse：
- BASE_WAREHOUSE_CAPACITY = 12。
- get_module_storage_cost()：模块长×宽×数量。
- get_warehouse_used() / get_warehouse_capacity() / get_warehouse_remaining()：仓储统计。
- can_store_module() / store_module()：容量检查与原子入库。
- 已安装 FunctionModuleDefinition.storage_capacity 会增加容量。
- 商店购买与模块奖励统一经过仓储检查；Hull 不经过模块仓储。
