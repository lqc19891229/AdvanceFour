【当前代码说明｜2026-10】
Godot 4.6.1。启动为 route_map_screen.tscn 的固定测试星图；随机星图由 RouteMapGenerator 提供。
资源：能量结晶用于商店，零件用于维修与空间站制造。胜利直接统一结算，失败清空 Run。
文中带版本号的早期叙述仅供历史参考。

《前进四》data/definitions/appearance 目录说明

职责：
定义外观表现层使用的数据结构，不执行实际绘制。

当前：
- hull_appearance_definition.gd：定义 Hull 外观 ID 与 16 个四方向邻接 Tile。

邻接位：
- bit 0 / 1：UP
- bit 1 / 2：RIGHT
- bit 2 / 4：DOWN
- bit 3 / 8：LEFT

具体外观实例位于 data/appearances/。
正式 Runtime 素材位于 data/assets/ship/。
实际拼装逻辑位于 game/ship/appearance/。
