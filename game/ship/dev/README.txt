《前进四》game/ship/dev 目录说明

职责：
保存飞船系统独立开发与自动回归，不属于正式游戏流程。

主要文件：
- ship_regression_test.gd：无界面回归，覆盖 Hull HP、Equipment efficiency、供电、移动、武器、Projectile、核心沉没、编辑器与存档。
- ship_ai_test.gd / .tscn：玩家与 AI 飞船交火测试。
- ship_movement_test.gd / .tscn：移动、控制、武器与命中最小测试。
- weapon_target_dummy.gd：通用 DamageReceiver 测试目标。

当前飞船架构：
- 数据结构：data/definitions/ship/ 与 data/definitions/module/。
- 模块实例数据：data/modules/。
- Runtime：game/ship/runtime/。
- 控制：game/ship/controller/。
- 武器：game/ship/weapon/。
- 弹丸：game/ship/projectile/。

受击规则：
- Projectile 命中 HullCellRuntime，而不是 ShipModuleRuntime。
- ShipHullCell 保存实际基础 HP。
- Defense.hp 增加其覆盖 Hull 区域的有效最大 HP。
- 当前有效且已供电的 Defense.protection 汇总为整船百分比减伤。
- Equipment efficiency 由覆盖 Hull Cell health ratio 平均值决定。
- Core 覆盖 Hull 全毁时整船退出战斗。

自动验证：
python3 tools/verify_project.py --godot /path/to/godot
GitHub Actions 对 main / PR 使用同一验证入口。
