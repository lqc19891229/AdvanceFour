《前进四》game/ship/damage 目录说明

职责：
保存可复用的通用伤害组件。当前飞船主战斗耐久已经迁移到 Hull Cell，因此 DamageReceiver 不属于飞船主受击链。

当前文件：
- damage_receiver.gd：独立通用 HP 组件，提供 setup / reset / apply_damage / get_hp / is_destroyed 以及 damaged / destroyed 信号。

当前飞船主受击链：
ProjectileRuntime
→ HullCellRuntime
→ ShipRuntime.apply_hull_projectile_damage()
→ ShipHullCell.current_hp
→ Equipment efficiency / Core 沉没判定

注意：
- ShipModuleRuntime 不承伤、不维护独立 HP。
- 除 Defense 外 Equipment 没有 hp。
- Defense.hp 作为覆盖 Hull Cell 的附加有效耐久。
- Defense.protection 由 ShipRuntime 汇总当前有效且已供电的 Defense，作为整船百分比减伤。
- Projectile 的 overkill 依据 Hull 区域剩余有效 HP 继续向后穿透。

DamageReceiver 仍可用于独立测试目标或以后其他拥有独立 HP 的对象，但不要把旧“Equipment 自己承伤”规则写回飞船 Runtime。
