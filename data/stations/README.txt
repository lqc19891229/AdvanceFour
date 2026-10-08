【当前代码说明｜2026-10】
Godot 4.6.1；项目默认启动 fixed_test_sector 测试星图，动态星图由 RouteMapGenerator.generate() 实现。
能量结晶用于商店，零件用于维修和空间站制造；战斗胜利直接统一结算，失败重置 Run。
历史版本内容不等于当前规则。

data/stations

职责：
- 保存维修改装空间站配置。
- StationDefinition 定义空间站名称与可制造模块列表。
- StationCraftItemDefinition 定义 module_id、数量和零件成本。

当前 basic_station：
- 轻型装甲：18 零件
- 机炮：28 零件
- 小型引擎：22 零件
- 小型反应堆：24 零件
- 雷达：20 零件
- 标准货舱：32 零件

空间站免费维修由 Gameplay / RunState 执行，不属于制造配方。
