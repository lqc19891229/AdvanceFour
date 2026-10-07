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
