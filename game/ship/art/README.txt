《前进四》game/ship/art 目录说明

用途：
- 存放飞船模块视觉资源及统一访问逻辑。
- 贴图由模块数据直接引用，不再通过 module_id 或固定文件名推导路径。
- 贴图只负责表现，不改变 ShipData、模块占格、碰撞或存档格式。

当前数据规则：
- 所有模块的 Excel 行必须填写 texture_path，使用 Godot res:// 路径。
- Weapon Sheet 额外填写 turret_texture_path。
- 导入后 texture_path 写入 ShipModuleDefinition.texture。
- 导入后 turret_texture_path 写入 WeaponModuleDefinition.turret_texture。
- .tres 直接持有 Texture2D 资源引用；PNG 可以改名或移动，只需同步修改 Excel 路径。
- 找不到贴图时数据导入失败。

武器分层规则：
- ShipModuleDefinition.texture：武器底座。
- WeaponModuleDefinition.turret_texture：武器炮塔。
- ShipModuleRuntime 显示底座。
- WeaponRuntime 显示炮塔并独立旋转瞄准。
- 编辑器同时绘制底座和炮塔。

说明：
- ModuleArtLibrary 只负责从 definition 取 Texture2D 与计算缩放，不再固定任何 PNG 路径。
