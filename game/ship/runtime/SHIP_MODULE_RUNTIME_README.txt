《前进四》ShipModuleRuntime 说明

定位：
- ShipModuleRuntime 是 ShipData 中单个 ShipModuleInstance 进入战斗后的运行时受击对象。
- 它不复制模块静态数据，只引用已有 ShipModuleInstance。
- 每个已安装模块都拥有自己的碰撞区域与 DamageReceiver。

为什么使用“每模块独立碰撞体”：
- 飞船模块允许分开放置，不要求相邻或连通。
- 不能假设飞船是连续舰体，也不能用整块包围盒代表真实可命中区域。
- 每个模块独立 Area2D 可以直接把 Projectile 命中对象解析为对应 ShipModuleInstance。
- 空格天然不会产生碰撞体，因此弹丸可以从模块之间的空隙穿过。

当前运行链：
ProjectileRuntime
  ↓ swept collision
ShipModuleRuntime
  ↓ apply_projectile_damage(remaining_damage)
DamageReceiver
  ↓
module_damaged / module_destroyed

当前 Prototype HP：
- 所有模块暂时统一使用 RuntimeShip.prototype_module_hp，当前默认值为 20。
- DefenseModuleDefinition.protection 不再增加 max HP，而是该防护模块每次被 Projectile 命中时使用的百分比减伤值。
- 当前公式：protection_percent = clamp(protection, 0, 100)；damage_after_protection = incoming_damage * (1 - protection_percent / 100)。
- protection 不会被消耗；只要该 Defense 模块仍存活，每次命中都会重新应用同一个百分比减伤值。protection = 5 即减伤 5%。
- prototype_module_hp 尚未进入 ModuleDefinition / Excel 数据真源；DefenseModuleDefinition.protection 已来自现有静态数据链。

当前范围：
- 每模块独立碰撞体。
- 每模块独立 HP。
- Projectile 命中时可直接知道具体 ShipModuleInstance。
- 模块 HP 归零后禁用该模块碰撞体，并发出 destroyed。
- 防护模块的保护是空间性的：只保护实际位于其后方、且弹道会先穿过该装甲位置的模块。
- 某块装甲 destroyed 后，只开放该块碰撞区域对应的局部缺口；其他装甲继续保持独立碰撞与独立 HP。
- ShipModuleRuntime.apply_projectile_damage(amount) 先对 Defense 模块应用百分比 protection：damage_after_protection = incoming_damage * (1 - clamp(protection, 0, 100) / 100)。
- 如果 damage_after_protection <= 0，则 HP 不变，Projectile 在该模块处结束。
- 之后模块最多吸收自己当前 HP；如果本次伤害将模块摧毁，则返回 damage_after_protection - hp_before。
- ProjectileRuntime 收到 remaining_damage > 0 后会继续沿同一弹道向内查询，因此高伤害弹丸仍可连续击穿多个低血量模块。
- 非 Defense 模块 protection = 0，直接按 incoming_damage 扣 HP。
- RuntimeShip 会转发 module_damaged / module_destroyed。

暂不包含：
- 模块摧毁后从 ShipData 删除。
- 动力模块失效后降低推力。
- 武器模块失效后停止射击。
- 能量模块失效后的供能变化。
- 核心模块击毁后整船沉没。
- 模块爆炸、残骸或视觉破坏效果。
