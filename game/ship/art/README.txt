《前进四》game/ship/art 目录说明

用途：
- 存放飞船模块视觉资源及统一加载逻辑。
- 贴图只负责表现，不改变 ShipData、模块占格、碰撞、存档或 Excel 数据结构。

当前约定：
- 普通模块贴图：res://game/ship/art/modules/{module_id}.png
- 武器底座贴图：res://game/ship/art/modules/{module_id}_base.png
- 武器炮塔贴图：res://game/ship/art/modules/{module_id}_turret.png
- 找不到贴图时，编辑器与 Runtime 自动回退到现有 Prototype 色块 / 炮塔线条，不阻止运行。

首批 1×1 模块目标文件：
- energy_smallreactor.png
- propulsion_smallengine.png
- weapon_cannon_base.png
- weapon_cannon_turret.png
- defense_lightarmor.png
- function_radar.png
- core_bridge.png

武器分层规则：
- ShipModuleRuntime 只显示武器底座。
- WeaponRuntime 只显示炮塔，并沿用自身自动瞄准旋转。
- 编辑器同时绘制底座和炮塔；炮塔使用 ShipModuleInstance.rotation_quarters 表示设计初始朝向。
- 武器底座不承担独立瞄准旋转。

当前边界：
- 本阶段不新增 Excel / JSON / .tres 贴图字段。
- 不修改 ShipSerializer 存档格式。
- 不提供 damaged / destroyed / unpowered 多套贴图；destroyed 先用程序灰化。
- 未来 1×2 / 2×2 模块继续沿用 ModuleArtLibrary 命名和分层规则。
