【当前代码说明｜2026-10】
Godot 4.6.1；项目默认启动 fixed_test_sector 测试星图，动态星图由 RouteMapGenerator.generate() 实现。
能量结晶用于商店，零件用于维修和空间站制造；战斗胜利直接统一结算，失败重置 Run。
历史版本内容不等于当前规则。

《前进四》data/routes 目录说明

职责：
保存正式 RunRouteDefinition 路线实例。

当前：
- prototype_route.tres：v0.37 第一版星系航线。

当前结构：
第一战
↙      ↘
补给商店  整备站
↘      ↙
第二战
   ↓
航线终点

规则：
- 路线只描述节点、连接、目标资源和星图位置。
- 战斗内容仍属于 data/battles。
- 商店内容仍属于 data/shops。
- 路线执行状态由 RunState 管理。
