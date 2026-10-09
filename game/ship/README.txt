《前进四》game/ship — 当前说明（2026-10-09）

职责：飞船编辑、玩家/敌方共用的战斗运行时及可复用表现，不保存正式模块数值定义。
目录：
- runtime/：ShipRuntime、HullCellRuntime、ShipModuleRuntime，共用 Hull 承伤与供能逻辑。
- appearance/：外观贴图、船体 Tile 和设备视觉。
- weapon/、projectile/、damage/：武器自动选敌、弹丸碰撞/穿透、受损组件。
- controller/：玩家输入控制器与飞船系统开发测试用 AIShipController；正式敌舰控制器在 game/enemy/enemy_controller.gd。
- editor/：玩家设计/当前 Run 整备 UI，使用 ShipGridView。
- template_editor/：开发环境 F6 独立飞船模板编辑场景。
- templates/：ShipTemplateManager，模板 JSON 管理。
- dev/：飞船系统测试场景与回归脚本。

数据来源：data/definitions/ship/（ShipData/ShipSerializer）、data/modules/、data/ships/templates/、data/assets/。
游戏默认 F5 启动星图，不是此目录下的编辑器。
