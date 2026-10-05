《前进四》HullCellRuntime / ShipModuleRuntime 说明

当前职责已经从“模块自己承伤”调整为：

ProjectileRuntime
  ↓ swept collision
HullCellRuntime
  ↓
ShipHullCell.current_hp
  ↓
RuntimeShip 重新计算 Equipment efficiency
  ↓
ShipModuleRuntime / WeaponRuntime 更新功能表现

HullCellRuntime：
- 对应 ShipData 中一个 ShipHullCell。
- 每个 Hull Cell 有独立碰撞体与独立 HP。
- Projectile 命中时通过 RuntimeShip.apply_hull_projectile_damage() 扣该格 HP。
- HP 归零后该 Hull Cell 的碰撞体失效。
- overkill 伤害会继续沿弹道穿透后方 Hull Cell。

ShipModuleRuntime：
- 对应一个 ShipModuleInstance / Equipment。
- 只负责 Equipment 基础视觉，不再拥有 DamageReceiver 或独立 HP。
- Equipment 的损伤状态来自 RuntimeShip.get_module_efficiency()。
- efficiency 越低，设备视觉越暗；efficiency = 0 表示设备失效。

Equipment efficiency：
- 单格设备：直接使用该 Hull Cell 的 current_hp / max_hp。
- 多格设备：取覆盖 Hull Cell health ratio 的平均值。
- Hull Cell 不存在时 efficiency = 0。

当前功能影响：
- Energy 输出按 efficiency 缩放。
- Propulsion 推力按 efficiency 缩放。
- Defense protection 按 efficiency 缩放。
- Weapon 火力、炮塔转速和射速按 efficiency 缩放。
- Core efficiency = 0 时整船退出战斗。

设计目的：
- Hull Layout 负责“船体结构、局部 HP、可命中区域”。
- Equipment 负责“Power、Damage、Thrust、Defense、Function”。
- 防护与功能构筑不再要求每个 Equipment 自己维护一套 HP。
- 后续可以在 Hull 层增加轻型 / 重型 / 装甲 / 特殊船体，而不改 Equipment 定义。

兼容说明：
- ModuleDefinition.hp 暂时保留在 Excel / generated 资源中，但当前运行时不读取。
