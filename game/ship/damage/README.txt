《前进四》game/ship/damage 目录说明

用途：
- 存放飞船战斗链中通用的受击 / 生命值运行时组件。
- 当前 DamageReceiver 只负责 HP、受伤事件和 destroyed 事件。
- 当前不负责护甲公式、模块 HP、核心模块沉没判定或受击特效。

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
- ProjectileRuntime 只负责命中并发出 hit。
- RuntimeShip 只负责转发 projectile_hit。
- 战斗层 / 测试层决定把 projectile_hit 的 firepower 交给哪个 DamageReceiver。
- DamageReceiver 不知道 Projectile、WeaponRuntime 或 ShipData。

当前范围：
- 通用 HP。
- 受伤事件。
- destroyed 事件。

暂不包含：
- 防御 / 护甲减伤。
- 模块独立 HP。
- 核心模块击毁。
- 飞船整体沉没。
- 伤害类型。
- 暴击。
- 状态效果。
