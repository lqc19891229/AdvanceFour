【当前代码说明｜2026-10】
Godot 4.6.1。启动为 route_map_screen.tscn 的固定测试星图；随机星图由 RouteMapGenerator 提供。
资源：能量结晶用于商店，零件用于维修与空间站制造。胜利直接统一结算，失败清空 Run。
文中带版本号的早期叙述仅供历史参考。
正式 Runtime 素材集中于 data/assets；不从 tools 目录加载美术。

human_basic Hull Runtime Tile 正式美术第一版。

共 16 张 64×64 PNG，文件名 hull_0000.png ～ hull_1111.png。
四位二进制按 LEFT/DOWN/RIGHT/UP 展示，实际 bit 权重为：
UP=1、RIGHT=2、DOWN=4、LEFT=8。

本目录中的 PNG 是项目唯一一份 Hull Tile 素材，同时也是 Runtime 正式加载文件。
不再在 tools 下维护重复副本。
