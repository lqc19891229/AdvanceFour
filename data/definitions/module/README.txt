【当前代码说明｜2026-10】
Godot 4.6.1。启动为 route_map_screen.tscn 的固定测试星图；随机星图由 RouteMapGenerator 提供。
资源：能量结晶用于商店，零件用于维修与空间站制造。胜利直接统一结算，失败清空 Run。
文中带版本号的早期叙述仅供历史参考。

《前进四》data/definitions/module 目录说明

职责：
定义模块数据结构，不保存具体模块实例。

包含：
- ModuleDefinition
- EnergyModuleDefinition
- PropulsionModuleDefinition
- WeaponModuleDefinition
- DefenseModuleDefinition
- FunctionModuleDefinition
- CoreModuleDefinition
- ModuleDatabase 类型

具体模块数据位于 data/modules/。
Runtime 正式模块素材位于 data/assets/modules/。
Gameplay 行为位于 game/ship/。

UI 使用 get_display_texture()：优先 icon_texture，普通模块回退 texture；武器先回退 turret_texture，再回退底座 texture。
编辑器与战斗仍分别使用底座 texture 和炮塔 turret_texture。
