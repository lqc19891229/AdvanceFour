《前进四》game/ship/damage 目录说明

用途：
- 存放飞船战斗链中通用的受击 / 生命值运行时组件。
- 当前 DamageReceiver 只负责 HP、受伤事件和 destroyed 事件。
- 当前不负责全局护甲减伤公式、模块 HP 构造、核心模块沉没判定或受击特效。

当前文件：
- damage_receiver.gd：通用 HP 组件。

基础接口：
- setup(max_hp)：设置最大生命并重置当前生命。
- reset()：当前生命恢复为 max_hp。
- apply_damage(amount)：扣除生命值。
- get_hp()：读取当前生命。
- is_destroyed()：读取是否已进入 destroyed 状态。

信号：
- damaged(amount, current_hp)
- destroyed

当前伤害规则：
- 负数伤害按 0 处理。
- current_hp 不低于 0。
- HP 首次降到 0 时发出 destroyed。
- destroyed 后继续调用 apply_damage() 不再重复生效。

职责边界：
- ProjectileRuntime 在首次有效命中时，如果目标提供 apply_damage()，会直接调用 apply_damage(firepower)。
- RuntimeShip.projectile_hit 只保留命中事件转发，不再承担实际伤害应用。
- DamageReceiver 仍只接收数值伤害，不知道 Projectile、WeaponRuntime 或 ShipData。
- 当前 Prototype 伤害值仍直接使用 firepower。
- 防护模块不在 DamageReceiver 中做百分比 / 固定值减伤；其 protection 由 RuntimeShip 转换为该装甲模块额外最大 HP。
- 装甲的“保护”来自空间碰撞顺序：Projectile 命中前方装甲后即销毁，后方模块本次不受伤；装甲 destroyed 后碰撞体失效，后续 Projectile 才能通过该局部位置。

当前范围：
- 通用 HP。
- 受伤事件。
- destroyed 事件。

暂不包含：
- 全局防御 / 护甲百分比减伤。
- 更复杂的模块耐久规则。
- 核心爆炸 / 残骸表现。
- 伤害类型。
- 暴击。
- 状态效果。
