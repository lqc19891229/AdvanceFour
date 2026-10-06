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
