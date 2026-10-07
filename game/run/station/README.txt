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
