《前进四》game/ship 目录说明

职责：
保存飞船系统的运行逻辑、场景与编辑器，不再保存纯数据定义和正式素材。

子目录：
- appearance/：Runtime 外观策略、ShipAppearanceRenderer、ModuleArtLibrary。
- editor/：Hull Layout + Equipment 编辑器。
- runtime/：ShipData 在战斗世界中的运行实体。
- controller/：Player / AI 控制输入。
- weapon/：炮塔、自动选敌、瞄准与开火逻辑。
- projectile/：弹丸运行时、swept ray、命中与穿透。
- damage/：伤害运行逻辑。
- dev/：飞船系统开发 / 回归测试。

数据依赖：
- ShipData / Hull Cell / ModuleInstance / Serializer：res://data/definitions/ship/
- Equipment Definition / ModuleDatabase：res://data/definitions/module/
- 模块具体数据：res://data/modules/
- 模块正式贴图：res://data/assets/modules/

原则：
game/ship 负责“飞船如何运行”，data 负责“飞船和模块数据是什么”。
