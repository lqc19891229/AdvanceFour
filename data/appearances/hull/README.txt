【当前代码说明｜2026-10】
Godot 4.6.1。启动为 route_map_screen.tscn 的固定测试星图；随机星图由 RouteMapGenerator 提供。
资源：能量结晶用于商店，零件用于维修与空间站制造。胜利直接统一结算，失败清空 Run。
文中带版本号的早期叙述仅供历史参考。

Hull Appearance 具体配置实例。

当前：
- human_basic.tres：第一版默认 Hull Tile 外观，包含 16 个四方向邻接贴图。

第一版不写入 ShipData / ShipSerializer，ShipAppearanceRenderer 默认加载 human_basic。
后续需要多外观风格时，再把 appearance_id 正式纳入飞船配置。
