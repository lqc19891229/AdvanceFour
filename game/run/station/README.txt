【当前实现｜2026-10｜Godot 4.6.1】
项目主入口 res://game/run/route/route_map_screen.tscn；默认固定测试航线：商店→空间站→普通战→精英战→终点。RouteMapGenerator.generate() 可生成随机图，但不是当前默认入口。
RunState 维护能量结晶（交易）、零件（维修/制造）、模块仓储、战损和路线节点状态；胜利自动进入统一战果页，失败清空 Run。
含版本号的旧行为仅用于版本追溯。

game/run/station

职责：
- 维修改装空间站节点的玩法场景。
- 进入空间站时免费将当前 Run 飞船全部 Hull 修复至满血。
- 使用零件按 StationDefinition 配方制造模块。
- 制造成功后模块进入 Run Warehouse，并受仓储容量限制。
- 可继续进入 Ship Editor 的 Run Refit 模式进行安装 / 拆卸 / 布局调整。

数据：
- data/stations/basic_station.tres
- data/definitions/run/station_definition.gd
- data/definitions/run/station_craft_item_definition.gd

规则：
- 免费维修不消耗零件或能量结晶。
- 制造只消耗零件。
- 零件不足或仓库空间不足时制造原子失败。
- 制造模块不直接安装到飞船。
