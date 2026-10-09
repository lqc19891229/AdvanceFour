《前进四》game/run/route — 星图（2026-10-09）

默认项目入口为 route_map_screen.tscn。没有激活 Run 时，route_map_screen.gd 先尝试读取 user://ships/test_ship.json 的合法设计，失败则 Battle.build_starter_design()，然后 start_run_with_test_route() 启动 fixed_test_sector。
route_map_screen.gd 根据 RunState.route_definition 绘制节点与连线，限制只能进入当前允许的下一节点。route_node_view.gd/tscn 渲染节点，route_map_generator.gd 用于非默认随机路线，route_test_map.gd 用于构造固定测试航线；top_bar.gd 显示局内资源。
BATTLE 进入共享战斗、SHOP 进入商店、REFIT 进入空间站、TAVERN 进入酒馆、END 结束 Run。可从星图进入游戏内飞船编辑器整备，不会启动开发者模板编辑器。
星图不持久化另一套 Run；具体状态统一由 core/autoload/run_state.gd 管理。
