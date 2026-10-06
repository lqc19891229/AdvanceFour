《前进四》HullCellRuntime / ShipModuleRuntime 说明

当前主链：

ProjectileRuntime
→ HullCellRuntime
→ ShipRuntime.apply_hull_projectile_damage()
→ ShipHullCell.current_hp
→ Equipment efficiency 更新
→ ShipModuleRuntime / WeaponRuntime 功能表现更新

HullCellRuntime：
- 对应一个 ShipHullCell。
- 拥有独立碰撞区域。
- HP 归零后碰撞失效。
- overkill 可继续沿弹道命中后方 Hull。

ShipModuleRuntime：
- 对应 ShipModuleInstance / Equipment。
- 只负责允许外露 Equipment 的基础视觉。
- 不拥有 DamageReceiver 或独立 HP。
- 亮度由 efficiency 驱动。

Equipment efficiency：
- 单格：对应 Hull Cell health ratio。
- 多格：覆盖 Hull Cell health ratio 平均值。
- 任一覆盖位置不存在时返回 0。

当前影响：
- Energy 输出按 efficiency 缩放。
- Propulsion 推力按 efficiency 缩放。
- Defense protection 按 efficiency 缩放；Defense.hp 同时作为覆盖 Hull 的附加有效耐久。
- Weapon 火力、炮塔转速与射速按 efficiency 缩放。
- Core efficiency = 0 时整船退出战斗。

数据规则：
- ShipModuleDefinition 没有共通 hp / mass。
- 只有 DefenseModuleDefinition 保留 hp 与 protection。
- Hull 的基础耐久保存在 ShipHullCell。
