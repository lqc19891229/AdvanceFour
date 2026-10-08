【当前代码说明｜2026-10】
Godot 4.6.1。启动为 route_map_screen.tscn 的固定测试星图；随机星图由 RouteMapGenerator 提供。
资源：能量结晶用于商店，零件用于维修与空间站制造。胜利直接统一结算，失败清空 Run。
文中带版本号的早期叙述仅供历史参考。
正式 Runtime 素材集中于 data/assets；不从 tools 目录加载美术。

《前进四》data/assets 目录说明

职责：
保存项目唯一一份游戏素材文件，也是 Godot Runtime 正式加载位置。

当前：
- modules/：Equipment PNG，包括 Weapon base / turret。
- Weapon turret PNG 的默认炮口方向为向右，编辑器与 Runtime 共用这一美术方向约定。
- <module_id>_icon.png：可选 UI 图标，导入器自动挂载；武器组合图标可用 tools/generate_weapon_icon.gd 从正式 base / turret 重建。
- ship/hull/human_basic/：第一版 16 个 Hull 邻接 Tile。

规则：
1. PNG、音频等游戏素材统一只保存在 data/assets。
2. tools 不再保存同一素材的 source/runtime 双份副本。
3. game 不直接保存正式素材。
4. data Resource / game Runtime 统一引用 data/assets 下的路径。
5. 如果未来出现 PSD、Aseprite、Blender 等真正的制作工程文件，再单独设计源码素材管理方案；当前不提前建立双份 PNG 体系。
